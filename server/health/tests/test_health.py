"""
Tests for GET /health/ endpoint.
"""
import pytest
from unittest.mock import patch


@pytest.mark.django_db
class TestHealthEndpoint:
    url = '/health/'

    def test_health_endpoint_is_public(self, api_client):
        """Health endpoint must be accessible without authentication."""
        resp = api_client.get(self.url)
        # Should never return 401/403 — it's a public endpoint
        assert resp.status_code in (200, 503)

    def test_healthy_response_structure(self, api_client):
        """Response must contain all expected keys."""
        with patch('health.views._check_redis', return_value=('connected', True)):
            resp = api_client.get(self.url)

        assert 'status' in resp.data
        assert 'database' in resp.data
        assert 'redis' in resp.data
        assert 'email' in resp.data
        assert 'google_calendar' in resp.data
        assert 'ai' in resp.data
        assert 'environment' in resp.data
        assert 'version' in resp.data

    def test_database_check_passes(self, api_client):
        """Database check should pass in test environment."""
        with patch('health.views._check_redis', return_value=('connected', True)):
            resp = api_client.get(self.url)
        assert resp.data['database'] == 'connected'

    def test_returns_200_when_all_critical_pass(self, api_client):
        """Returns HTTP 200 when all critical checks pass."""
        with patch('health.views._check_redis', return_value=('connected', True)):
            resp = api_client.get(self.url)
        assert resp.status_code == 200
        assert resp.data['status'] == 'healthy'

    def test_returns_503_when_database_fails(self, api_client):
        """Returns HTTP 503 when a critical check fails."""
        with patch('health.views._check_database', return_value=('error: connection refused', False)):
            resp = api_client.get(self.url)
        assert resp.status_code == 503
        assert resp.data['status'] == 'degraded'

    def test_returns_503_when_redis_fails(self, api_client):
        """Returns HTTP 503 when Redis is unreachable."""
        with patch('health.views._check_redis', return_value=('error: connection refused', False)):
            resp = api_client.get(self.url)
        assert resp.status_code == 503

    def test_non_critical_failure_does_not_cause_503(self, api_client):
        """Email not configured is a warning, not a critical failure."""
        with patch('health.views._check_redis', return_value=('connected', True)):
            with patch('health.views._check_email', return_value=('not_configured', True)):
                resp = api_client.get(self.url)
        assert resp.status_code == 200
        assert resp.data['email'] == 'not_configured'

    def test_no_trailing_slash_also_works(self, api_client):
        """Both /health and /health/ should work."""
        with patch('health.views._check_redis', return_value=('connected', True)):
            resp = api_client.get('/health')
        assert resp.status_code in (200, 503, 301)  # 301 on redirect

    def test_version_in_response(self, api_client):
        with patch('health.views._check_redis', return_value=('connected', True)):
            resp = api_client.get(self.url)
        assert resp.data['version'] is not None
        assert isinstance(resp.data['version'], str)
