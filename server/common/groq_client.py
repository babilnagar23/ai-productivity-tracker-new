"""
Centralized Groq AI client for Productivity Tracker.

All AI features route through generate_ai_response() and generate_ai_json().
Default Model: openai/gpt-oss-20b (configurable via GROQ_MODEL environment variable).
"""
import json
import logging
import os
import re

from django.conf import settings

logger = logging.getLogger('ai')

DEFAULT_GROQ_MODEL = 'openai/gpt-oss-20b'
_GROQ_MODEL = DEFAULT_GROQ_MODEL


def get_groq_model() -> str:
    """
    Return the active Groq model identifier.

    Checks:
    1. settings.GROQ_MODEL
    2. os.environ['GROQ_MODEL']
    3. DEFAULT_GROQ_MODEL ('openai/gpt-oss-20b')
    """
    model = getattr(settings, 'GROQ_MODEL', '') or os.getenv('GROQ_MODEL', '')
    if model and str(model).strip():
        return str(model).strip()
    return DEFAULT_GROQ_MODEL


def _get_client():
    """Return a configured Groq client, or None if the key is missing."""
    api_key = getattr(settings, 'GROQ_API_KEY', '') or os.getenv('GROQ_API_KEY', '')
    if not api_key:
        logger.error('[AI] GROQ_API_KEY is not configured')
        return None
    try:
        from groq import Groq
        return Groq(api_key=api_key)
    except Exception as exc:
        logger.error('[AI] Failed to initialise Groq client: %s', exc)
        return None


def clean_ai_response(text: str) -> str:
    """
    Cleans up AI response to remove markdown headers and convert lists to readable sentences.
    """
    if not text:
        return text

    # Remove ###, ##, # headings
    text = re.sub(r'^#{1,3}\s+', '', text, flags=re.MULTILINE)
    
    # Remove bold/italic markers
    text = text.replace('**', '')
    
    # Convert bullet points into readable sentences (remove bullets)
    text = re.sub(r'^[\*\-]\s+(.*)$', r'\1', text, flags=re.MULTILINE)
    
    # Replace multiple newlines with a double newline for paragraph spacing
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    return text.strip()


def generate_ai_response(
    prompt: str,
    *,
    model: str = None,
    temperature: float = 0.7,
    max_tokens: int = 2000,
    clean: bool = False,
) -> str:
    """
    Send a plain-text prompt to Groq and return the response string.

    Args:
        prompt: Plain-text prompt string.
        model: Optional model override. Defaults to get_groq_model().
        temperature: Sampling temperature.
        max_tokens: Maximum tokens in completion.
        clean: Whether to strip markdown headers and bullets.

    Raises:
        ValueError  — GROQ_API_KEY missing or client failed to initialise.
        Exception   — Groq API error (rate-limit, invalid request, network, …).
    """
    logger.info('[AI] Request received')

    client = _get_client()
    if client is None:
        raise ValueError('Groq API key is missing or invalid. Set GROQ_API_KEY in your .env file.')

    active_model = (model or get_groq_model()).strip()
    logger.info('[AI] Calling Groq (%s)', active_model)
    try:
        response = client.chat.completions.create(
            model=active_model,
            messages=[{'role': 'user', 'content': prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
        )
        text = response.choices[0].message.content
        logger.info('[AI] Response received (%d chars)', len(text) if text else 0)
        
        if clean and text:
            text = clean_ai_response(text)
            
        return text or ''
    except Exception as exc:
        logger.error('[AI] Error calling Groq model %s: %s', active_model, exc)
        raise


def generate_ai_json(
    prompt: str,
    *,
    model: str = None,
    temperature: float = 0.7,
    max_tokens: int = 2000,
) -> dict:
    """
    Like generate_ai_response but strips markdown fences and parses JSON.

    Raises:
        json.JSONDecodeError — if the model returned non-JSON text.
        Any exception from generate_ai_response.
    """
    raw = generate_ai_response(
        prompt,
        model=model,
        temperature=temperature,
        max_tokens=max_tokens,
    )
    raw = (raw or '').strip()

    # Strip ```json ... ``` or ``` ... ``` fences
    if raw.startswith('```'):
        lines = raw.split('\n')
        # Drop first line (```json or ```) and last line (```)
        inner = lines[1:]
        if inner and inner[-1].strip() == '```':
            inner = inner[:-1]
        raw = '\n'.join(inner).strip()

    return json.loads(raw)
