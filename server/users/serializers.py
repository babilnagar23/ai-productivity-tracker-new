from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import default_config

User = get_user_model()


def public_user(user):
    # Use the reverse OneToOne relation directly — profile is auto-created via signal.
    # No need for get_or_create; avoids an extra DB query on every call.
    profile = user.profile
    name = user.get_full_name() or user.first_name or user.username
    return {
        'id': str(user.id),
        'name': name,
        'email': user.email,
        'firstName': user.first_name or '',
        'lastName': user.last_name or '',
        'avatar': profile.avatar or '',
        'streak': profile.streak,
        'xp': profile.xp,
        'has_selected_template': profile.has_selected_template,
        'customConfig': profile.custom_config or default_config(),
    }


def token_payload(user):
    refresh = RefreshToken.for_user(user)
    return {
        'token': str(refresh.access_token),
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


class RegisterSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    def validate_email(self, value):
        email = value.lower().strip()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return email

    def validate(self, attrs):
        password = attrs.get('password')
        confirm_password = attrs.get('confirm_password')

        if not confirm_password:
            raise serializers.ValidationError({'confirm_password': 'Confirm password is required.'})

        if password != confirm_password:
            raise serializers.ValidationError({'confirm_password': 'Passwords do not match.'})

        # Enforce consistent password strength policy across web, mobile, and backend
        if len(password) < 8:
            raise serializers.ValidationError({'password': 'Password must be at least 8 characters long.'})
        if not any(c.isupper() for c in password):
            raise serializers.ValidationError({'password': 'Password must contain at least one uppercase letter.'})
        if not any(c.islower() for c in password):
            raise serializers.ValidationError({'password': 'Password must contain at least one lowercase letter.'})
        if not any(c.isdigit() for c in password):
            raise serializers.ValidationError({'password': 'Password must contain at least one number.'})
        if not any(c in '!@#$%^&*(),.?":{}|<>' for c in password):
            raise serializers.ValidationError({'password': 'Password must contain at least one special character.'})

        # Apply standard Django password validators
        try:
            validate_password(password)
        except DjangoValidationError as e:
            raise serializers.ValidationError({'password': list(e.messages)})

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        email = validated_data['email'].lower().strip()
        name = validated_data.get('name', '').strip()
        if name:
            first_name, _, last_name = name.partition(' ')
        else:
            first_name, last_name = email.split('@')[0], ''

        try:
            user = User.objects.create_user(
                username=email,
                email=email,
                password=validated_data['password'],
                first_name=first_name,
                last_name=last_name,
            )
        except IntegrityError as exc:
            raise serializers.ValidationError({'email': 'An account with this email already exists.'}) from exc

        # Ensure custom_config is set on profile
        if hasattr(user, 'profile'):
            user.profile.custom_config = default_config()
            user.profile.save(update_fields=['custom_config'])

        return user



class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        email = attrs['email'].lower().strip()
        user = authenticate(username=email, password=attrs['password'])
        if not user:
            raise serializers.ValidationError('Invalid credentials')
        attrs['user'] = user
        return attrs


class CustomConfigSerializer(serializers.Serializer):
    customConfig = serializers.DictField()

    def validate_customConfig(self, value):
        return {
            'coreChecklists': value.get('coreChecklists', []),
            'coreMetrics': value.get('coreMetrics', []),
            'deletedHistory': value.get('deletedHistory', []),
        }


from django.utils.http import urlsafe_base64_decode
from django.utils.encoding import force_str
from django.contrib.auth.tokens import default_token_generator

class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ResetPasswordSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    password = serializers.CharField(write_only=True, min_length=6)

    def validate(self, attrs):
        uid = attrs.get('uid')
        token = attrs.get('token')
        
        try:
            user_id = force_str(urlsafe_base64_decode(uid))
            user = User.objects.get(pk=user_id)
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            raise serializers.ValidationError('Invalid reset link or expired token.')

        if not default_token_generator.check_token(user, token):
            raise serializers.ValidationError('Invalid reset link or expired token.')

        attrs['user'] = user
        return attrs

    def save(self):
        user = self.validated_data['user']
        password = self.validated_data['password']
        user.set_password(password)
        user.save()
        return user


# ── OTP Registration Serializers ──────────────────────────────────


class SendOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        return value.lower().strip()


class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp = serializers.CharField(max_length=6, min_length=6)

    def validate_email(self, value):
        return value.lower().strip()

    def validate_otp(self, value):
        if not value.isdigit():
            raise serializers.ValidationError('OTP must contain only digits.')
        return value


class OTPRegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, min_length=6)

    def validate_email(self, value):
        email = value.lower().strip()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return email

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({'confirm_password': 'Passwords do not match.'})
        password = attrs['password']
        if len(password) < 8:
            raise serializers.ValidationError({'password': 'Password must be at least 8 characters.'})
        if not any(c.isupper() for c in password):
            raise serializers.ValidationError({'password': 'Password must contain at least one uppercase letter.'})
        if not any(c.isdigit() for c in password):
            raise serializers.ValidationError({'password': 'Password must contain at least one number.'})
        return attrs

