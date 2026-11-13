"""
Tests for centralized Groq client (server/common/groq_client.py).

Verifies:
- Default model resolution: openai/gpt-oss-20b
- Environment and settings overrides (GROQ_MODEL)
- No fallback to deprecated llama models
- generate_ai_response and generate_ai_json functions
- Markdown cleanup utilities
"""
import json
import pytest
from unittest.mock import MagicMock, patch

from common.groq_client import (
    DEFAULT_GROQ_MODEL,
    clean_ai_response,
    generate_ai_json,
    generate_ai_response,
    get_groq_model,
)


class TestGroqModelResolution:
    def test_default_model_is_gpt_oss_20b(self):
        """When no setting or environment variable is set, default to openai/gpt-oss-20b."""
        with patch('django.conf.settings.GROQ_MODEL', ''):
            with patch.dict('os.environ', {}, clear=True):
                assert get_groq_model() == 'openai/gpt-oss-20b'
                assert get_groq_model() == DEFAULT_GROQ_MODEL

    def test_no_deprecated_fallback(self):
        """Ensure deprecated llama models are never used as fallbacks."""
        with patch('django.conf.settings.GROQ_MODEL', ''):
            with patch.dict('os.environ', {}, clear=True):
                model = get_groq_model()
                assert 'llama' not in model
                assert model != 'llama-3.3-70b-versatile'
                assert model != 'llama-3.1-8b-instant'

    def test_setting_override(self):
        """settings.GROQ_MODEL overrides default."""
        with patch('django.conf.settings.GROQ_MODEL', 'custom/custom-model-id'):
            assert get_groq_model() == 'custom/custom-model-id'

    def test_env_override(self):
        """os.environ['GROQ_MODEL'] is respected when settings is empty."""
        with patch('django.conf.settings.GROQ_MODEL', ''):
            with patch.dict('os.environ', {'GROQ_MODEL': 'env-model-30b'}):
                assert get_groq_model() == 'env-model-30b'


class TestGenerateAiResponse:
    def test_missing_api_key_raises_value_error(self):
        """When GROQ_API_KEY is not configured, raise ValueError."""
        with patch('django.conf.settings.GROQ_API_KEY', ''):
            with patch.dict('os.environ', {}, clear=True):
                with pytest.raises(ValueError, match='GROQ_API_KEY'):
                    generate_ai_response('Test prompt')

    def test_calls_configured_model(self):
        """Verify chat.completions.create is called with openai/gpt-oss-20b by default."""
        mock_client = MagicMock()
        mock_choice = MagicMock()
        mock_choice.message.content = 'Generated response'
        mock_client.chat.completions.create.return_value = MagicMock(choices=[mock_choice])

        with patch('common.groq_client._get_client', return_value=mock_client):
            with patch('common.groq_client.get_groq_model', return_value='openai/gpt-oss-20b'):
                resp = generate_ai_response('Hello coach', temperature=0.5, max_tokens=1500)

        assert resp == 'Generated response'
        mock_client.chat.completions.create.assert_called_once_with(
            model='openai/gpt-oss-20b',
            messages=[{'role': 'user', 'content': 'Hello coach'}],
            temperature=0.5,
            max_tokens=1500,
        )

    def test_explicit_model_override(self):
        """Callers can pass an explicit model argument."""
        mock_client = MagicMock()
        mock_choice = MagicMock()
        mock_choice.message.content = 'Custom response'
        mock_client.chat.completions.create.return_value = MagicMock(choices=[mock_choice])

        with patch('common.groq_client._get_client', return_value=mock_client):
            resp = generate_ai_response('Prompt', model='specialized/model-v1')

        assert resp == 'Custom response'
        mock_client.chat.completions.create.assert_called_once_with(
            model='specialized/model-v1',
            messages=[{'role': 'user', 'content': 'Prompt'}],
            temperature=0.7,
            max_tokens=2000,
        )

    def test_clean_response_flag(self):
        """clean=True removes markdown headers and bullet points."""
        mock_client = MagicMock()
        mock_choice = MagicMock()
        mock_choice.message.content = '### Summary\n* Do workout\n* Study math'
        mock_client.chat.completions.create.return_value = MagicMock(choices=[mock_choice])

        with patch('common.groq_client._get_client', return_value=mock_client):
            resp = generate_ai_response('Prompt', clean=True)

        assert '###' not in resp
        assert '* ' not in resp
        assert 'Do workout' in resp


class TestGenerateAiJson:
    def test_parses_json_with_code_fences(self):
        """Strips ```json markdown fences and loads JSON."""
        json_content = '{"plan": "focus", "duration": 45}'
        mock_raw = f'```json\n{json_content}\n```'

        with patch('common.groq_client.generate_ai_response', return_value=mock_raw):
            data = generate_ai_json('Prompt')

        assert data == {'plan': 'focus', 'duration': 45}

    def test_parses_raw_json_without_fences(self):
        """Loads valid JSON directly."""
        json_content = '{"items": [1, 2, 3]}'

        with patch('common.groq_client.generate_ai_response', return_value=json_content):
            data = generate_ai_json('Prompt')

        assert data == {'items': [1, 2, 3]}

    def test_invalid_json_raises_decode_error(self):
        """Raises JSONDecodeError when text is not valid JSON."""
        with patch('common.groq_client.generate_ai_response', return_value='Not a JSON string'):
            with pytest.raises(json.JSONDecodeError):
                generate_ai_json('Prompt')


class TestCleanAiResponse:
    def test_empty_or_none(self):
        assert clean_ai_response('') == ''
        assert clean_ai_response(None) is None

    def test_removes_markdown_headers(self):
        raw = '# Title\n## Subtitle\n### H3\nNormal text'
        cleaned = clean_ai_response(raw)
        assert '# ' not in cleaned
        assert 'Title' in cleaned
        assert 'Normal text' in cleaned

    def test_converts_bullets_to_sentences(self):
        raw = '- First bullet point\n* Second bullet point'
        cleaned = clean_ai_response(raw)
        assert '- ' not in cleaned
        assert '* ' not in cleaned
        assert 'First bullet point' in cleaned
        assert 'Second bullet point' in cleaned
