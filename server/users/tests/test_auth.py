"""
Comprehensive authentication test suite.

Covers:
- OTP-Free Registration (email + password + confirm_password)
- Password strength validation (5 rules + Django validators)
- IP-based signup cooldown rate limiting (429 Retry-After, atomic locks)
- IP extraction and hashing utilities
- Login, Logout, Me, Token Refresh
- Authenticated Change Password
- Gmail Password Recovery flow (forgot-password + reset-password)
- Legacy OTP fallback flow (complete-registration requires OTP)
"""
import pytest
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.utils import timezone
from users.models import SignupIPCooldown, EmailOTP
from users.ip_utils import get_client_ip, normalize_ip, hash_ip

User = get_user_model()


# ── /api/auth/check-email ─────────────────────────────────────────

@pytest.mark.django_db
class TestCheckEmail:
    url = '/api/auth/check-email'

    def test_available_email(self, api_client):
        resp = api_client.post(self.url, {'email': 'brandnew@example.com'}, format='json')
        assert resp.status_code == 200
        assert resp.data['data']['available'] is True

    def test_taken_email(self, api_client, user):
        resp = api_client.post(self.url, {'email': user.email}, format='json')
        assert resp.status_code == 200
        assert resp.data['data']['available'] is False

    def test_taken_email_case_insensitive(self, api_client, user):
        resp = api_client.post(self.url, {'email': user.email.upper()}, format='json')
        assert resp.status_code == 200
        assert resp.data['data']['available'] is False

    def test_missing_email(self, api_client):
        resp = api_client.post(self.url, {}, format='json')
        assert resp.status_code == 400


# ── /api/auth/register (OTP-Free Direct Registration) ─────────────

@pytest.mark.django_db
class TestRegister:
    url = '/api/auth/register'

    def test_successful_registration(self, api_client):
        resp = api_client.post(
            self.url,
            {
                'email': 'newuser@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR='198.51.100.10',
        )
        assert resp.status_code == 201
        assert resp.data['success'] is True
        assert 'token' in resp.data['data']
        assert 'user' in resp.data['data']
        assert resp.data['data']['user']['email'] == 'newuser@example.com'

        # Verify user is created in database
        u = User.objects.get(email='newuser@example.com')
        assert u.check_password('SecurePass123!')
        assert hasattr(u, 'profile')

        # Verify NO EmailOTP was created or used
        assert not EmailOTP.objects.filter(email='newuser@example.com').exists()

    def test_missing_confirm_password(self, api_client):
        resp = api_client.post(
            self.url,
            {
                'email': 'noconfirm@example.com',
                'password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR='198.51.100.11',
        )
        assert resp.status_code == 400
        assert resp.data['success'] is False
        assert not User.objects.filter(email='noconfirm@example.com').exists()

    def test_password_mismatch(self, api_client):
        resp = api_client.post(
            self.url,
            {
                'email': 'mismatch@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'DifferentPass123!',
            },
            format='json',
            REMOTE_ADDR='198.51.100.12',
        )
        assert resp.status_code == 400
        assert resp.data['success'] is False
        assert not User.objects.filter(email='mismatch@example.com').exists()

    def test_duplicate_email(self, api_client, user):
        resp = api_client.post(
            self.url,
            {
                'email': user.email,
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR='198.51.100.13',
        )
        assert resp.status_code == 400
        assert resp.data['success'] is False

    def test_duplicate_email_case_insensitive(self, api_client, user):
        resp = api_client.post(
            self.url,
            {
                'email': user.email.upper(),
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR='198.51.100.14',
        )
        assert resp.status_code == 400
        assert resp.data['success'] is False

    @pytest.mark.parametrize('weak_pw', [
        'short1!',         # < 8 chars
        'alllowercase1!',  # no uppercase
        'ALLUPPERCASE1!',  # no lowercase
        'NoDigitsHere!',   # no digits
        'NoSpecialChar12', # no special char
    ])
    def test_weak_password_rejected(self, api_client, weak_pw):
        resp = api_client.post(
            self.url,
            {
                'email': f'weak_{weak_pw[:5]}@example.com',
                'password': weak_pw,
                'confirm_password': weak_pw,
            },
            format='json',
            REMOTE_ADDR='198.51.100.15',
        )
        assert resp.status_code == 400
        assert resp.data['success'] is False


# ── IP-Based Signup Cooldown Rate Limiting ────────────────────────

@pytest.mark.django_db
class TestSignupIPCooldown:
    url = '/api/auth/register'

    def test_ip_cooldown_enforced(self, api_client):
        ip = '203.0.113.10'

        # First signup succeeds
        resp1 = api_client.post(
            self.url,
            {
                'email': 'first_signup@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        assert resp1.status_code == 201

        # Second signup from same IP within 60s is rate limited
        resp2 = api_client.post(
            self.url,
            {
                'email': 'second_signup@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        assert resp2.status_code == 429
        assert resp2.data['success'] is False
        assert resp2.data['code'] == 'SIGNUP_IP_COOLDOWN'
        assert 'retry_after_seconds' in resp2.data
        assert resp2.data['retry_after_seconds'] > 0
        assert 'Retry-After' in resp2.headers
        assert not User.objects.filter(email='second_signup@example.com').exists()

    def test_different_ip_not_blocked(self, api_client):
        # Signup on IP A
        resp_a = api_client.post(
            self.url,
            {
                'email': 'user_a@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR='203.0.113.20',
        )
        assert resp_a.status_code == 201

        # Immediate signup on IP B succeeds
        resp_b = api_client.post(
            self.url,
            {
                'email': 'user_b@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR='203.0.113.21',
        )
        assert resp_b.status_code == 201

    def test_validation_error_does_not_consume_cooldown(self, api_client):
        ip = '203.0.113.30'

        # Failed attempt with mismatched password
        resp_fail = api_client.post(
            self.url,
            {
                'email': 'fail_validation@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'MismatchPass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        assert resp_fail.status_code == 400

        # Subsequent valid attempt from same IP should succeed immediately
        resp_success = api_client.post(
            self.url,
            {
                'email': 'succeeds_now@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        assert resp_success.status_code == 201

    def test_cooldown_expires_after_window(self, api_client):
        ip = '203.0.113.40'

        # First signup
        resp1 = api_client.post(
            self.url,
            {
                'email': 'user_first@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        assert resp1.status_code == 201

        # Simulate 61 seconds passing
        cooldown = SignupIPCooldown.objects.get(ip_hash=hash_ip(ip))
        cooldown.last_signup_at = timezone.now() - timedelta(seconds=65)
        cooldown.save(update_fields=['last_signup_at'])

        # Second signup now succeeds
        resp2 = api_client.post(
            self.url,
            {
                'email': 'user_after_window@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        assert resp2.status_code == 201

    def test_ip_hash_storage_no_plaintext(self, api_client):
        ip = '203.0.113.50'
        api_client.post(
            self.url,
            {
                'email': 'hashed_check@example.com',
                'password': 'SecurePass123!',
                'confirm_password': 'SecurePass123!',
            },
            format='json',
            REMOTE_ADDR=ip,
        )
        expected_hash = hash_ip(ip)
        assert SignupIPCooldown.objects.filter(ip_hash=expected_hash).exists()
        # Verify plaintext IP is not stored anywhere in the table fields
        for row in SignupIPCooldown.objects.all():
            assert ip not in row.ip_hash


# ── IP Extraction & Utilities ─────────────────────────────────────

class DummyRequest:
    def __init__(self, meta):
        self.META = meta


class TestIPExtraction:
    def test_remote_addr(self):
        req = DummyRequest({'REMOTE_ADDR': '192.0.2.1'})
        assert get_client_ip(req) == '192.0.2.1'

    def test_x_forwarded_for_single(self):
        req = DummyRequest({
            'HTTP_X_FORWARDED_FOR': '198.51.100.5',
            'REMOTE_ADDR': '127.0.0.1',
        })
        assert get_client_ip(req) == '198.51.100.5'

    def test_x_forwarded_for_multiple_with_proxy(self):
        req = DummyRequest({
            'HTTP_X_FORWARDED_FOR': '198.51.100.7, 10.0.0.1, 172.16.0.2',
            'REMOTE_ADDR': '127.0.0.1',
        })
        assert get_client_ip(req) == '198.51.100.7'

    def test_trusted_edge_headers(self):
        req = DummyRequest({
            'HTTP_TRUE_CLIENT_IP': '203.0.113.88',
            'HTTP_X_FORWARDED_FOR': '10.0.0.1',
            'REMOTE_ADDR': '127.0.0.1',
        })
        assert get_client_ip(req) == '203.0.113.88'

    def test_cf_connecting_ip(self):
        req = DummyRequest({
            'HTTP_CF_CONNECTING_IP': '203.0.113.99',
            'REMOTE_ADDR': '127.0.0.1',
        })
        assert get_client_ip(req) == '203.0.113.99'

    def test_port_stripping(self):
        assert normalize_ip('192.0.2.1:8000') == '192.0.2.1'
        assert normalize_ip('[2001:db8::1]:8080') == '2001:db8::1'

    def test_ipv6_normalization(self):
        assert normalize_ip('2001:0db8:0000:0000:0000:0000:0000:0001') == '2001:db8::1'

    def test_invalid_ip_fallback(self):
        assert normalize_ip('invalid-ip-string') == '127.0.0.1'


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


# ── /api/auth/change-password (Authenticated User) ─────────────────

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


# ── Gmail Password Recovery: forgot-password & reset-password ─────

@pytest.mark.django_db
class TestPasswordRecovery:
    forgot_url = '/api/auth/forgot-password'
    reset_url = '/api/auth/reset-password'

    def test_existing_email_returns_200(self, api_client, user):
        resp = api_client.post(self.forgot_url, {'email': user.email}, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_nonexistent_email_returns_200(self, api_client):
        # Always returns 200 to prevent user enumeration
        resp = api_client.post(self.forgot_url, {'email': 'nobody@example.com'}, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_invalid_email_format(self, api_client):
        resp = api_client.post(self.forgot_url, {'email': 'not-an-email'}, format='json')
        assert resp.status_code == 400

    def test_reset_password_with_valid_token(self, api_client, user):
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))

        resp = api_client.post(self.reset_url, {
            'uid': uid,
            'token': token,
            'password': 'BrandNewPassword123!',
        }, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

        user.refresh_from_db()
        assert user.check_password('BrandNewPassword123!')

    def test_reset_password_with_invalid_token(self, api_client, user):
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        resp = api_client.post(self.reset_url, {
            'uid': uid,
            'token': 'invalid-or-expired-token',
            'password': 'BrandNewPassword123!',
        }, format='json')
        assert resp.status_code == 400
        assert resp.data['success'] is False


# ── Legacy / Fallback OTP Flow ───────────────────────────────────

@pytest.mark.django_db
class TestOTPFlow:
    send_url = '/api/auth/send-otp'
    verify_url = '/api/auth/verify-otp'
    register_url = '/api/auth/complete-registration'

    def test_send_otp(self, api_client):
        resp = api_client.post(self.send_url, {'email': 'otp@example.com'}, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_verify_invalid_otp(self, api_client):
        EmailOTP.objects.create(email='otp2@example.com', otp_code='123456')
        resp = api_client.post(self.verify_url, {
            'email': 'otp2@example.com',
            'otp': '999999',
        }, format='json')
        assert resp.status_code == 400

    def test_verify_correct_otp(self, api_client):
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
            'confirm_password': 'SecurePass123!',
        }, format='json')
        assert resp.status_code == 400
        assert resp.data['code'] == 'EMAIL_NOT_VERIFIED'

    def test_complete_registration_with_verification(self, api_client):
        email = 'verified_otp_user@example.com'
        EmailOTP.objects.create(email=email, otp_code='112233', is_verified=True)
        resp = api_client.post(self.register_url, {
            'email': email,
            'password': 'SecurePass123!',
            'confirm_password': 'SecurePass123!',
        }, format='json')
        assert resp.status_code == 201
        assert resp.data['success'] is True
        assert 'token' in resp.data['data']
        assert User.objects.filter(email=email).exists()
