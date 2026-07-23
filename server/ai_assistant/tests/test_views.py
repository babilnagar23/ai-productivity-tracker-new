"""
Tests for AI assistant views: generate-plan, analyze-habits, chat-coach, job-status.
"""
import pytest
from unittest.mock import patch


# ── /api/ai/generate-plan ─────────────────────────────────────────

@pytest.mark.django_db
class TestGeneratePlan:
    url = '/api/ai/generate-plan'

    def test_unauthenticated(self, api_client):
        resp = api_client.post(self.url)
        assert resp.status_code == 401

    def test_no_groq_key_returns_local_fallback(self, authenticated_client):
        with patch('django.conf.settings.GROQ_API_KEY', ''):
            resp = authenticated_client.post(self.url)
        assert resp.status_code == 200
        assert resp.data['success'] is True
        assert 'plan' in resp.data

    def test_groq_available_success(self, authenticated_client):
        with patch('ai_assistant.views.generate_ai_response', return_value='Test plan response'):
            with patch('django.conf.settings.GROQ_API_KEY', 'test-key'):
                resp = authenticated_client.post(self.url)
        assert resp.status_code == 200
        assert resp.data['success'] is True

    def test_groq_error_returns_500(self, authenticated_client):
        with patch('ai_assistant.views.generate_ai_response', side_effect=Exception('Groq down')):
            with patch('ai_assistant.views._groq_available', return_value=True):
                resp = authenticated_client.post(self.url)
        assert resp.status_code == 500


# ── /api/ai/analyze ───────────────────────────────────────────────

@pytest.mark.django_db
class TestAnalyzeHabits:
    url = '/api/ai/analyze'

    def test_unauthenticated(self, api_client):
        resp = api_client.post(self.url)
        assert resp.status_code == 401

    def test_no_groq_key_returns_local_fallback(self, authenticated_client):
        with patch('django.conf.settings.GROQ_API_KEY', ''):
            resp = authenticated_client.post(self.url)
        assert resp.status_code == 200
        assert resp.data['success'] is True
        assert 'analysis' in resp.data


# ── /api/ai/chat ──────────────────────────────────────────────────

@pytest.mark.django_db
class TestChatCoach:
    url = '/api/ai/chat'

    def test_unauthenticated(self, api_client):
        resp = api_client.post(self.url, {'message': 'Hello'})
        assert resp.status_code == 401

    def test_empty_message(self, authenticated_client):
        resp = authenticated_client.post(self.url, {'message': ''}, format='json')
        assert resp.status_code == 400

    def test_missing_message(self, authenticated_client):
        resp = authenticated_client.post(self.url, {}, format='json')
        assert resp.status_code == 400

    def test_no_groq_key_returns_local_fallback(self, authenticated_client):
        with patch('django.conf.settings.GROQ_API_KEY', ''):
            resp = authenticated_client.post(self.url, {'message': 'Help me plan'}, format='json')
        assert resp.status_code == 200
        assert resp.data['success'] is True
        assert 'reply' in resp.data

    def test_with_groq_mocked(self, authenticated_client):
        with patch('ai_assistant.views.generate_ai_response', return_value='Great job!'):
            with patch('ai_assistant.views._groq_available', return_value=True):
                resp = authenticated_client.post(self.url, {'message': 'Hello coach'}, format='json')
        assert resp.status_code == 200
        assert resp.data['reply'] == 'Great job!'


# ── /api/ai/job/<id> ──────────────────────────────────────────────

@pytest.mark.django_db
class TestAiJobStatus:
    def test_job_not_found(self, authenticated_client):
        resp = authenticated_client.get('/api/ai/job/99999/')
        assert resp.status_code == 404

    def test_job_belonging_to_other_user(self, authenticated_client, make_user):
        from ai_assistant.models import AiJob
        other = make_user(email='other@example.com')
        job = AiJob.objects.create(user=other, prompt='test')
        resp = authenticated_client.get(f'/api/ai/job/{job.id}/')
        assert resp.status_code == 404

    def test_own_job_status(self, authenticated_client, user):
        from ai_assistant.models import AiJob
        job = AiJob.objects.create(user=user, prompt='test', status='done', result='Result here')
        resp = authenticated_client.get(f'/api/ai/job/{job.id}/')
        assert resp.status_code == 200
        assert resp.data['status'] == 'done'
        assert resp.data['result'] == 'Result here'
