"""
Tests for authentication endpoints.

Covers: register, login, logout, token refresh, OTP flow, forgot/reset password,
check-email, change-password, delete-account.
"""
import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse

User = get_user_model()


# ── /api/auth/check-email ─────────────────────────────────────────

@pytest.mark.django_db
class TestCheckEmail:
    url = '/api/auth/check-email'

    def test_available_email(self, api_client):
        resp = api_client.post(self.url, {'email': 'new@example.com'}, format='json')
        assert resp.status_code == 200
        assert resp.data['data']['available'] is True

    def test_taken_email(self, api_client, user):
        resp = api_client.post(self.url, {'email': user.email}, format='json')
        assert resp.status_code == 200
        assert resp.data['data']['available'] is False

    def test_missing_email(self, api_client):
        resp = api_client.post(self.url, {}, format='json')
        assert resp.status_code == 400


# ── /api/auth/register ────────────────────────────────────────────

@pytest.mark.django_db
class TestRegister:
    url = '/api/auth/register'

    def test_successful_registration(self, api_client):
        resp = api_client.post(self.url, {
            'email': 'newuser@example.com',
            'password': 'SecurePass123!',
        }, format='json')
        assert resp.status_code == 201
        assert resp.data['success'] is True
        assert 'token' in resp.data['data']
        assert 'user' in resp.data['data']

    def test_duplicate_email(self, api_client, user):
        resp = api_client.post(self.url, {
            'email': user.email,
            'password': 'SecurePass123!',
        }, format='json')
        assert resp.status_code == 400
        assert resp.data['success'] is False

    def test_weak_password(self, api_client):
        resp = api_client.post(self.url, {
            'email': 'newuser2@example.com',
            'password': '123',
        }, format='json')
        assert resp.status_code == 400


# ── /api/auth/login ───────────────────────────────────────────────

@pytest.mark.django_db
class TestLogin:
    url = '/api/auth/login'

    def test_successful_login(self, api_client, user):
        resp = api_client.post(self.url, {
            'email': user.email,
            'password': 'TestPass123!',
        }, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True
        assert 'token' in resp.data['data']

    def test_wrong_password(self, api_client, user):
        resp = api_client.post(self.url, {
            'email': user.email,
            'password': 'WrongPassword!',
        }, format='json')
        assert resp.status_code == 401
        assert resp.data['success'] is False

    def test_nonexistent_user(self, api_client):
        resp = api_client.post(self.url, {
            'email': 'ghost@example.com',
            'password': 'AnyPass123!',
        }, format='json')
        assert resp.status_code == 401

    def test_missing_fields(self, api_client):
        resp = api_client.post(self.url, {'email': 'test@example.com'}, format='json')
        assert resp.status_code in (400, 401)


# ── /api/auth/logout ──────────────────────────────────────────────

@pytest.mark.django_db
class TestLogout:
    url = '/api/auth/logout'

    def test_logout_without_cookie(self, api_client):
        resp = api_client.post(self.url)
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_logout_with_valid_refresh(self, api_client, auth_tokens):
        api_client.cookies['refresh_token'] = auth_tokens['refresh']
        resp = api_client.post(self.url)
        assert resp.status_code == 200


# ── /api/auth/me ──────────────────────────────────────────────────

@pytest.mark.django_db
class TestMe:
    url = '/api/auth/me'

    def test_get_profile(self, authenticated_client, user):
        resp = authenticated_client.get(self.url)
        assert resp.status_code == 200
        assert resp.data['data']['email'] == user.email

    def test_unauthenticated(self, api_client):
        resp = api_client.get(self.url)
        assert resp.status_code == 401

    def test_patch_name(self, authenticated_client, user):
        resp = authenticated_client.patch(self.url, {'name': 'John Doe'}, format='json')
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.first_name == 'John'
        assert user.last_name == 'Doe'


# ── /api/auth/token/refresh ───────────────────────────────────────

@pytest.mark.django_db
class TestTokenRefresh:
    url = '/api/auth/token/refresh'

    def test_refresh_via_body(self, api_client, auth_tokens):
        resp = api_client.post(self.url, {'refresh': auth_tokens['refresh']}, format='json')
        assert resp.status_code == 200
        assert 'token' in resp.data['data']

    def test_refresh_via_cookie(self, api_client, auth_tokens):
        api_client.cookies['refresh_token'] = auth_tokens['refresh']
        resp = api_client.post(self.url)
        assert resp.status_code == 200

    def test_missing_token(self, api_client):
        resp = api_client.post(self.url, {}, format='json')
        assert resp.status_code == 401


# ── /api/auth/change-password ─────────────────────────────────────

@pytest.mark.django_db
class TestChangePassword:
    url = '/api/auth/change-password'

    def test_successful_change(self, authenticated_client, user):
        resp = authenticated_client.post(self.url, {
            'current_password': 'TestPass123!',
            'new_password': 'NewSecurePass456!',
        }, format='json')
        assert resp.status_code == 200
        user.refresh_from_db()
        assert user.check_password('NewSecurePass456!')

    def test_wrong_current_password(self, authenticated_client):
        resp = authenticated_client.post(self.url, {
            'current_password': 'WrongPass!',
            'new_password': 'NewSecurePass456!',
        }, format='json')
        assert resp.status_code == 400

    def test_missing_fields(self, authenticated_client):
        resp = authenticated_client.post(self.url, {}, format='json')
        assert resp.status_code == 400


# ── /api/auth/forgot-password ─────────────────────────────────────

@pytest.mark.django_db
class TestForgotPassword:
    url = '/api/auth/forgot-password'

    def test_existing_email_returns_200(self, api_client, user):
        # Always returns 200 to prevent user enumeration
        resp = api_client.post(self.url, {'email': user.email}, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_nonexistent_email_returns_200(self, api_client):
        resp = api_client.post(self.url, {'email': 'nobody@example.com'}, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_invalid_email_format(self, api_client):
        resp = api_client.post(self.url, {'email': 'not-an-email'}, format='json')
        assert resp.status_code == 400


# ── /api/auth/send-otp / verify-otp ─────────────────────────────

@pytest.mark.django_db
class TestOTPFlow:
    send_url = '/api/auth/send-otp'
    verify_url = '/api/auth/verify-otp'
    register_url = '/api/auth/complete-registration'

    def test_send_otp(self, api_client):
        resp = api_client.post(self.send_url, {'email': 'otp@example.com'}, format='json')
        # Console backend won't raise; response should be 200
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_verify_invalid_otp(self, api_client):
        from users.models import EmailOTP
        EmailOTP.objects.create(email='otp2@example.com', otp_code='123456')
        resp = api_client.post(self.verify_url, {
            'email': 'otp2@example.com',
            'otp': '999999',
        }, format='json')
        assert resp.status_code == 400

    def test_verify_correct_otp(self, api_client):
        from users.models import EmailOTP
        EmailOTP.objects.create(email='otp3@example.com', otp_code='654321')
        resp = api_client.post(self.verify_url, {
            'email': 'otp3@example.com',
            'otp': '654321',
        }, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_complete_registration_without_verification(self, api_client):
        resp = api_client.post(self.register_url, {
            'email': 'unverified@example.com',
            'password': 'SecurePass123!',
        }, format='json')
        assert resp.status_code == 400
        assert resp.data['code'] == 'EMAIL_NOT_VERIFIED'
