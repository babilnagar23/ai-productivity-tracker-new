from django.contrib.auth import authenticate, get_user_model
from django.db import IntegrityError, transaction
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import default_config

User = get_user_model()


def public_user(user):
    profile, _ = user.profile.__class__.objects.get_or_create(user=user)
    name = user.get_full_name() or user.first_name or user.username
    return {
        'id': str(user.id),
        'name': name,
        'email': user.email,
        'streak': profile.streak,
        'xp': profile.xp,
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
    name = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=6)

    def validate_email(self, value):
        email = value.lower().strip()
        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError('User credentials profile already registered.')
        return email

    @transaction.atomic
    def create(self, validated_data):
        name = validated_data['name'].strip()
        email = validated_data['email']
        first_name, _, last_name = name.partition(' ')
        try:
            user = User.objects.create_user(
                username=email,
                email=email,
                password=validated_data['password'],
                first_name=first_name,
                last_name=last_name,
            )
        except IntegrityError as exc:
            raise serializers.ValidationError({'email': 'User credentials profile already registered.'}) from exc
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
