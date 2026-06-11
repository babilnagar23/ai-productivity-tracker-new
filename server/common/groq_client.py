"""
Centralized Groq AI client for Productivity Tracker.

All AI features route through generate_ai_response().
Model: llama-3.3-70b-versatile
"""
import json
import logging
import re

from django.conf import settings

logger = logging.getLogger('ai')

_GROQ_MODEL = 'llama-3.3-70b-versatile'


def _get_client():
    """Return a configured Groq client, or None if the key is missing."""
    api_key = getattr(settings, 'GROQ_API_KEY', '')
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


def generate_ai_response(prompt: str, *, temperature: float = 0.7, max_tokens: int = 2000, clean: bool = False) -> str:
    """
    Send a plain-text prompt to Groq and return the response string.

    Raises:
        ValueError  — GROQ_API_KEY missing or client failed to initialise.
        Exception   — Groq API error (rate-limit, invalid request, network, …).
    """
    logger.info('[AI] Request received')

    client = _get_client()
    if client is None:
        raise ValueError('Groq API key is missing or invalid. Set GROQ_API_KEY in your .env file.')

    logger.info('[AI] Calling Groq (%s)', _GROQ_MODEL)
    try:
        response = client.chat.completions.create(
            model=_GROQ_MODEL,
            messages=[{'role': 'user', 'content': prompt}],
            temperature=temperature,
            max_tokens=max_tokens,
        )
        text = response.choices[0].message.content
        logger.info('[AI] Response received (%d chars)', len(text))
        
        if clean:
            text = clean_ai_response(text)
            
        return text
    except Exception as exc:
        logger.error('[AI] Error: %s', exc)
        raise


def generate_ai_json(prompt: str, *, temperature: float = 0.7, max_tokens: int = 2000) -> dict:
    """
    Like generate_ai_response but strips markdown fences and parses JSON.

    Raises:
        json.JSONDecodeError — if the model returned non-JSON text.
        Any exception from generate_ai_response.
    """
    raw = generate_ai_response(prompt, temperature=temperature, max_tokens=max_tokens)
    raw = raw.strip()

    # Strip ```json ... ``` or ``` ... ``` fences
    if raw.startswith('```'):
        lines = raw.split('\n')
        # Drop first line (```json or ```) and last line (```)
        inner = lines[1:]
        if inner and inner[-1].strip() == '```':
            inner = inner[:-1]
        raw = '\n'.join(inner).strip()

    return json.loads(raw)
