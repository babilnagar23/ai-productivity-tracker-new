import logging

from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.db import IntegrityError, transaction
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.conf import settings
from django.utils.decorators import method_decorator
from django_ratelimit.decorators import ratelimit
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenRefreshView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

from .models import EmailOTP
from .serializers import (
    CustomConfigSerializer,
    LoginSerializer,
    RegisterSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
    SendOTPSerializer,
    VerifyOTPSerializer,
    OTPRegisterSerializer,
    public_user,
    token_payload,
)
from .email_utils import send_password_reset_email, send_otp_email
from .models import default_config

User = get_user_model()
logger = logging.getLogger('users.otp')

def error_response(serializer, fallback):
    if isinstance(serializer.errors, dict):
        first = next(iter(serializer.errors.values()), None)
        if isinstance(first, list) and first:
            return str(first[0])
        if first:
            return str(first)
    return fallback

def set_jwt_cookie(response, refresh_token):
    max_age = getattr(settings, 'SIMPLE_JWT', {}).get('REFRESH_TOKEN_LIFETIME', 30 * 24 * 60 * 60)
    if not isinstance(max_age, int):
        max_age = int(max_age.total_seconds())
        
    response.set_cookie(
        key='refresh_token',
        value=refresh_token,
        max_age=max_age,
        expires=max_age,
        secure=not getattr(settings, 'DEBUG', False),
        httponly=True,
        samesite='Lax',
        path='/api/auth/'
    )

class CheckEmailView(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        email = request.data.get('email', '').lower().strip()
        if not email:
            return Response({'success': False, 'code': 'INVALID_EMAIL', 'message': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        exists = User.objects.filter(email__iexact=email).exists()
        return Response({'success': True, 'message': 'Email checked', 'data': {'available': not exists}})

class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'code': 'VALIDATION_ERROR', 'message': error_response(serializer, 'Registration failed')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = serializer.save()
        tokens = token_payload(user)
        response = Response(
            {'success': True, 'message': 'Registration successful', 'data': {'token': tokens['access'], 'user': public_user(user)}},
            status=status.HTTP_201_CREATED,
        )
        set_jwt_cookie(response, tokens['refresh'])
        return response

@method_decorator(ratelimit(key='ip', rate='5/15m', block=True), name='dispatch')
class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            logger.warning('[AUTH] Login failed — invalid credentials for %s', request.data.get('email', 'unknown'))
            return Response(
                {'success': False, 'code': 'INVALID_CREDENTIALS', 'message': error_response(serializer, 'Wrong email or password')},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        user = serializer.validated_data['user']
        logger.info('[AUTH] Login success for %s', user.email)
        
        tokens = token_payload(user)
        response = Response({'success': True, 'message': 'Login successful', 'data': {'token': tokens['access'], 'user': public_user(user)}})
        set_jwt_cookie(response, tokens['refresh'])
        return response

class LogoutView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        try:
            refresh_token = request.COOKIES.get('refresh_token')
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            response = Response({'success': True, 'message': 'Logged out successfully', 'data': {}}, status=status.HTTP_200_OK)
            response.delete_cookie('refresh_token', path='/api/auth/')
            return response
        except Exception as e:
            logger.error('[AUTH] Logout failed: %s', str(e))
            response = Response({'success': True, 'message': 'Logged out locally', 'data': {}}, status=status.HTTP_200_OK)
            response.delete_cookie('refresh_token', path='/api/auth/')
            return response

class CookieTokenRefreshView(TokenRefreshView):
    def post(self, request, *args, **kwargs):
        refresh_token = request.COOKIES.get('refresh_token')
        if not refresh_token:
            return Response({'success': False, 'code': 'NO_REFRESH_TOKEN', 'message': 'Refresh token missing'}, status=status.HTTP_401_UNAUTHORIZED)
            
        data = {'refresh': refresh_token}
        serializer = self.get_serializer(data=data)

        try:
            serializer.is_valid(raise_exception=True)
        except TokenError as e:
            raise InvalidToken(e.args[0])

        response_data = {'success': True, 'message': 'Token refreshed', 'data': {'token': serializer.validated_data['access']}}
        response = Response(response_data, status=status.HTTP_200_OK)
        
        if 'refresh' in serializer.validated_data:
            set_jwt_cookie(response, serializer.validated_data['refresh'])
            
        return response

class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # Eagerly load profile to avoid a lazy extra query in public_user()
        user = type(request.user).objects.select_related('profile').get(pk=request.user.pk)
        return Response({'success': True, 'message': 'User retrieved', 'data': public_user(user)})

    def patch(self, request):
        user = request.user
        data = request.data

        if 'name' in data:
            name = str(data['name']).strip()
            parts = name.split(' ', 1)
            user.first_name = parts[0]
            user.last_name = parts[1] if len(parts) > 1 else ''

        if 'first_name' in data:
            user.first_name = str(data['first_name']).strip()
        if 'last_name' in data:
            user.last_name = str(data['last_name']).strip()

        # Save avatar to profile
        profile = user.profile
        profile_updated_fields = []

        if 'avatar' in data:
            profile.avatar = data['avatar']
            profile_updated_fields.append('avatar')

        if 'customConfig' in data:
            profile.custom_config = data['customConfig']
            profile_updated_fields.append('custom_config')

        if profile_updated_fields:
            profile.save(update_fields=profile_updated_fields)

        if 'email' in data:
            new_email = str(data['email']).lower().strip()
            if new_email != user.email:
                if User.objects.filter(email__iexact=new_email).exclude(pk=user.pk).exists():
                    return Response(
                        {'success': False, 'code': 'EMAIL_EXISTS', 'message': 'Email already in use.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
                user.email = new_email
                user.username = new_email

        user.save()
        return Response({'success': True, 'message': 'Profile updated', 'data': public_user(user)})


class CustomConfigView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = request.user.profile
        config = profile.custom_config or default_config()
        return Response({'success': True, 'message': 'Config retrieved', 'data': config})

    def put(self, request):
        return self._save_config(request)

    def patch(self, request):
        return self._save_config(request)

    def _save_config(self, request):
        data = request.data
        if 'customConfig' in data:
            config_data = data['customConfig']
        else:
            config_data = data

        profile = request.user.profile
        existing = profile.custom_config or default_config()

        updated = {
            'coreChecklists': config_data.get('coreChecklists', existing.get('coreChecklists', [])),
            'coreMetrics': config_data.get('coreMetrics', existing.get('coreMetrics', [])),
            'deletedHistory': config_data.get('deletedHistory', existing.get('deletedHistory', [])),
        }

        profile.custom_config = updated
        profile.save(update_fields=['custom_config'])
        return Response({'success': True, 'message': 'Config updated', 'data': updated})

@method_decorator(ratelimit(key='ip', rate='3/h', block=True), name='dispatch')
class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'code': 'VALIDATION_ERROR', 'message': error_response(serializer, 'Invalid email format')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        email = serializer.validated_data['email'].lower().strip()
        
        try:
            user = User.objects.get(email__iexact=email)
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            
            frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173')
            reset_url = f"{frontend_url}/reset-password/{uid}/{token}"
            
            send_password_reset_email(user.email, reset_url)
        except User.DoesNotExist:
            pass
        except Exception as e:
            print(f"Password reset email failed: {str(e)}")
            
        return Response({
            'success': True,
            'message': 'If an account exists, a reset link has been sent.',
            'data': {}
        }, status=status.HTTP_200_OK)


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'code': 'INVALID_TOKEN', 'message': error_response(serializer, 'Invalid reset link or expired token.')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        serializer.save()
        return Response({
            'success': True,
            'message': 'Password has been reset successfully.',
            'data': {}
        }, status=status.HTTP_200_OK)


@method_decorator(ratelimit(key='ip', rate='5/10m', block=True), name='dispatch')
class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'code': 'VALIDATION_ERROR', 'message': error_response(serializer, 'Invalid email format')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = serializer.validated_data['email']

        recent_count = EmailOTP.get_recent_count(email, hours=1)
        if recent_count >= 3:
            return Response(
                {'success': False, 'code': 'RATE_LIMITED', 'message': 'Too many OTP requests. Please try again later.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        EmailOTP.cleanup_expired()
        EmailOTP.objects.filter(email__iexact=email, is_verified=False).delete()

        otp_code = EmailOTP.generate_otp()
        EmailOTP.objects.create(email=email, otp_code=otp_code)

        try:
            send_otp_email(email, otp_code)
        except Exception as e:
            return Response(
                {'success': False, 'code': 'EMAIL_FAILED', 'message': 'Failed to send verification email. Please try again.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({
            'success': True,
            'message': 'OTP sent successfully',
            'data': {}
        }, status=status.HTTP_200_OK)


@method_decorator(ratelimit(key='ip', rate='5/10m', block=True), name='dispatch')
class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'code': 'VALIDATION_ERROR', 'message': error_response(serializer, 'Invalid OTP format')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = serializer.validated_data['email']
        otp = serializer.validated_data['otp']

        try:
            otp_record = EmailOTP.objects.filter(
                email__iexact=email,
                is_verified=False,
            ).latest('created_at')
        except EmailOTP.DoesNotExist:
            return Response(
                {'success': False, 'code': 'OTP_NOT_FOUND', 'message': 'No OTP found for this email. Please request a new one.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if otp_record.is_expired:
            otp_record.delete()
            return Response(
                {'success': False, 'code': 'OTP_EXPIRED', 'message': 'OTP has expired. Please request a new one.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if otp_record.attempt_count >= 5:
            otp_record.delete()
            return Response(
                {'success': False, 'code': 'OTP_MAX_ATTEMPTS', 'message': 'Too many failed attempts. Please request a new OTP.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        if otp_record.otp_code != otp:
            otp_record.attempt_count += 1
            otp_record.save(update_fields=['attempt_count'])
            remaining = 5 - otp_record.attempt_count
            return Response(
                {'success': False, 'code': 'INVALID_OTP', 'message': f'Invalid OTP. {remaining} attempt(s) remaining.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp_record.is_verified = True
        otp_record.save(update_fields=['is_verified'])

        return Response({'success': True, 'message': 'OTP Verified', 'data': {}}, status=status.HTTP_200_OK)


class OTPRegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPRegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'code': 'VALIDATION_ERROR', 'message': error_response(serializer, 'Registration failed')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        verified_otp = EmailOTP.objects.filter(
            email__iexact=email,
            is_verified=True,
        ).first()

        if not verified_otp:
            return Response(
                {'success': False, 'code': 'EMAIL_NOT_VERIFIED', 'message': 'Email not verified. Please complete OTP verification first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    username=email,
                    email=email,
                    password=password,
                )
                user.profile.custom_config = default_config()
                user.profile.save(update_fields=['custom_config'])
        except IntegrityError:
            return Response(
                {'success': False, 'code': 'EMAIL_EXISTS', 'message': 'An account with this email already exists.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        EmailOTP.objects.filter(email__iexact=email).delete()

        tokens = token_payload(user)

        response = Response(
            {'success': True, 'message': 'Registration complete', 'data': {'token': tokens['access'], 'user': public_user(user)}},
            status=status.HTTP_201_CREATED,
        )
        set_jwt_cookie(response, tokens['refresh'])
        return response

class AchievementsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = user.profile
        
        streak = profile.streak
        xp = profile.xp
        level = (xp // 100) + 1
        
        achievements = [
            {
                "id": "first_streak",
                "category": "streak",
                "title": "Getting Started",
                "description": "Start a streak of 3 days.",
                "progress": min(streak, 3),
                "goal": 3,
                "earned": streak >= 3
            },
            {
                "id": "streak_7",
                "category": "streak",
                "title": "One Week Dedicated",
                "description": "Achieve a 7-day streak.",
                "progress": min(streak, 7),
                "goal": 7,
                "earned": streak >= 7
            },
            {
                "id": "streak_30",
                "category": "streak",
                "title": "Monthly Master",
                "description": "Maintain a 30-day streak.",
                "progress": min(streak, 30),
                "goal": 30,
                "earned": streak >= 30
            },
            {
                "id": "level_5",
                "category": "general",
                "title": "Level 5 Apprentice",
                "description": "Reach level 5.",
                "progress": min(level, 5),
                "goal": 5,
                "earned": level >= 5
            },
            {
                "id": "level_10",
                "category": "general",
                "title": "Level 10 Adept",
                "description": "Reach level 10.",
                "progress": min(level, 10),
                "goal": 10,
                "earned": level >= 10
            },
            {
                "id": "first_focus",
                "category": "focus",
                "title": "Focus Pioneer",
                "description": "Complete your first focus session.",
                "progress": 1 if xp > 0 else 0,
                "goal": 1,
                "earned": xp > 0
            }
        ]
        
        return Response({'success': True, 'message': 'Achievements retrieved', 'data': achievements}, status=status.HTTP_200_OK)
