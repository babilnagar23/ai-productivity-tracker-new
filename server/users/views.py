import logging

from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.db import IntegrityError, transaction
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.conf import settings
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

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


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Registration failed')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = serializer.save()
        return Response(
            {'success': True, **token_payload(user), 'user': public_user(user)},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            logger.warning('[AUTH] Login failed — invalid credentials for %s',
                           request.data.get('email', 'unknown'))
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid credentials')},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        user = serializer.validated_data['user']
        logger.info('[AUTH] Login success for %s', user.email)
        return Response({'success': True, **token_payload(user), 'user': public_user(user)})


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({'success': True, 'data': public_user(request.user)})


class CustomConfigView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request):
        serializer = CustomConfigSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid configuration data format')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile = request.user.profile
        profile.custom_config = serializer.validated_data['customConfig']
        profile.save(update_fields=['custom_config'])
        return Response({'success': True, 'customConfig': profile.custom_config})


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid email format')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        email = serializer.validated_data['email'].lower().strip()
        
        try:
            user = User.objects.get(email__iexact=email)
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            
            frontend_url = getattr(settings, 'FRONTEND_URL', 'http://localhost:5173')
            reset_url = f"{frontend_url}/reset-password/{uid}/{token}"
            
            logger.info('[PASSWORD RESET] Request received for %s', email)
            logger.info('[PASSWORD RESET] Token generated')
            logger.info('[PASSWORD RESET] Email sending to %s', email)
            send_password_reset_email(user.email, reset_url)
            logger.info('[PASSWORD RESET] Email sent to %s', email)
        except User.DoesNotExist:
            logger.info('[PASSWORD RESET] No account found for %s (silent)', email)
        except Exception as e:
            logger.error('[PASSWORD RESET] Email failed for %s: %s', email, str(e))
            print(f"Password reset email failed: {str(e)}")
            
        return Response({
            'success': True,
            'message': 'If an account exists, a reset link has been sent.'
        }, status=status.HTTP_200_OK)


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid reset link or expired token.')},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        serializer.save()
        return Response({
            'success': True,
            'message': 'Password has been reset successfully.'
        }, status=status.HTTP_200_OK)


# ── OTP Registration Views ────────────────────────────────────────


class SendOTPView(APIView):
    """Step 1: User submits email, receives a 6-digit OTP."""
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid email format')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = serializer.validated_data['email']

        # Rate limit: max 3 OTP requests per email per hour
        recent_count = EmailOTP.get_recent_count(email, hours=1)
        if recent_count >= 3:
            logger.warning('[OTP] Rate limit exceeded for %s (%d in last hour)', email, recent_count)
            return Response(
                {'success': False, 'error': 'Too many OTP requests. Please try again later.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        # Clean up old expired OTPs
        EmailOTP.cleanup_expired()

        # Invalidate any previous unverified OTPs for this email
        EmailOTP.objects.filter(email__iexact=email, is_verified=False).delete()

        # Generate and store new OTP
        otp_code = EmailOTP.generate_otp()
        EmailOTP.objects.create(email=email, otp_code=otp_code)
        logger.info('[OTP] Generated code for %s', email)

        # Send email
        try:
            send_otp_email(email, otp_code)
        except Exception as e:
            logger.error('[OTP] Failed to send email to %s: %s', email, str(e))
            return Response(
                {'success': False, 'error': 'Failed to send verification email. Please try again.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({
            'success': True,
            'message': 'OTP sent successfully',
        }, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    """Step 2: User submits OTP for verification."""
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid OTP format')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = serializer.validated_data['email']
        otp = serializer.validated_data['otp']

        # Find the latest unverified OTP for this email
        try:
            otp_record = EmailOTP.objects.filter(
                email__iexact=email,
                is_verified=False,
            ).latest('created_at')
        except EmailOTP.DoesNotExist:
            logger.warning('[OTP] No OTP found for %s', email)
            return Response(
                {'success': False, 'error': 'No OTP found for this email. Please request a new one.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check expiry
        if otp_record.is_expired:
            logger.warning('[OTP] Expired OTP used for %s', email)
            otp_record.delete()
            return Response(
                {'success': False, 'error': 'OTP has expired. Please request a new one.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check attempt count
        if otp_record.attempt_count >= 5:
            logger.warning('[OTP] Max attempts reached for %s', email)
            otp_record.delete()
            return Response(
                {'success': False, 'error': 'Too many failed attempts. Please request a new OTP.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        # Verify OTP
        if otp_record.otp_code != otp:
            otp_record.attempt_count += 1
            otp_record.save(update_fields=['attempt_count'])
            remaining = 5 - otp_record.attempt_count
            logger.info('[OTP] Failed verification for %s (attempts: %d)', email, otp_record.attempt_count)
            return Response(
                {'success': False, 'error': f'Invalid OTP. {remaining} attempt(s) remaining.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Mark as verified
        otp_record.is_verified = True
        otp_record.save(update_fields=['is_verified'])
        logger.info('[OTP] Verified successfully for %s', email)

        return Response({'success': True}, status=status.HTTP_200_OK)


class OTPRegisterView(APIView):
    """Step 3: User creates password after OTP verification; account + JWT created."""
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPRegisterSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {'success': False, 'error': error_response(serializer, 'Registration failed')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        # Ensure OTP was verified for this email
        verified_otp = EmailOTP.objects.filter(
            email__iexact=email,
            is_verified=True,
        ).first()

        if not verified_otp:
            return Response(
                {'success': False, 'error': 'Email not verified. Please complete OTP verification first.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Create user account
        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    username=email,
                    email=email,
                    password=password,
                )
                # Ensure profile is created with default config
                user.profile.custom_config = default_config()
                user.profile.save(update_fields=['custom_config'])
                logger.info('[USER] Created account for %s', email)
        except IntegrityError:
            return Response(
                {'success': False, 'error': 'An account with this email already exists.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Clean up all OTPs for this email
        EmailOTP.objects.filter(email__iexact=email).delete()

        # Generate JWT tokens
        tokens = token_payload(user)
        logger.info('[JWT] Generated tokens for %s', email)

        return Response(
            {'success': True, **tokens, 'user': public_user(user)},
            status=status.HTTP_201_CREATED,
        )

