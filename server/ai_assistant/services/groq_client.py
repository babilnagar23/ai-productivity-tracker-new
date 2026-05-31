"""
Thin re-export so any code that previously imported from
ai_assistant.services.gemini_client still works.
"""
from common.groq_client import generate_ai_response, generate_ai_json  # noqa: F401
