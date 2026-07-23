"""
Shared pytest fixtures for AI Productivity Tracker backend tests.
"""
import os
import pytest

# Force test mode before Django settings are loaded
os.environ.setdefault('DJANGO_TESTING', '1')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'server.settings')
os.environ.setdefault('DJANGO_SECRET_KEY', 'test-secret-key-not-for-production-1234567890')
os.environ.setdefault('DATABASE_URL', 'sqlite:///test_db.sqlite3')

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken


User = get_user_model()


@pytest.fixture
def api_client():
    """Unauthenticated DRF API client."""
    return APIClient()


@pytest.fixture
def make_user(db):
    """Factory fixture — create a user with a profile."""
    def _make_user(email='test@example.com', password='TestPass123!', **kwargs):
        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            **kwargs,
        )
        return user
    return _make_user


@pytest.fixture
def user(make_user):
    """A single test user."""
    return make_user()


@pytest.fixture
def authenticated_client(user):
    """APIClient pre-authenticated with a valid JWT access token."""
    client = APIClient()
    refresh = RefreshToken.for_user(user)
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
    return client


@pytest.fixture
def auth_tokens(user):
    """Return access + refresh token strings for a user."""
    refresh = RefreshToken.for_user(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }
