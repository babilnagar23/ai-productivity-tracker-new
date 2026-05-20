from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import (
    CustomConfigSerializer,
    LoginSerializer,
    RegisterSerializer,
    public_user,
    token_payload,
)


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
            return Response(
                {'success': False, 'error': error_response(serializer, 'Invalid credentials')},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        user = serializer.validated_data['user']
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
