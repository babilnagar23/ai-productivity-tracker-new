import logging
from django.conf import settings
from google import genai
from google.genai.errors import APIError

logger = logging.getLogger('ai')

def get_gemini_client():
    api_key = getattr(settings, 'GEMINI_API_KEY', '')
    if not api_key or api_key == 'dummy_placeholder_key_replace_me' or api_key == 'your_gemini_api_key_here':
        return None
    try:
        return genai.Client(api_key=api_key)
    except Exception as e:
        logger.error(f"[AI] Error initializing client: {e}")
        return None

def generate_gemini_content(prompt, model_name=None):
    """
    Generate content using the new google-genai client models.generate_content API.
    Provides standard logging and maps API exceptions to informative wrappers.
    """
    logger.info("[AI] Request received")
    
    client = get_gemini_client()
    if not client:
        logger.error("[AI] Error: Gemini client is not configured")
        raise ValueError("Gemini API key is missing or invalid.")
        
    model = model_name or getattr(settings, 'GEMINI_MODEL', 'gemini-2.0-flash')
    
    try:
        logger.info("[AI] Sending request")
        response = client.models.generate_content(
            model=model,
            contents=prompt
        )
        logger.info("[AI] Response received")
        return response.text
    except APIError as e:
        logger.error(f"[AI] Error: Google GenAI API error: {e}")
        # Capture error code and details
        status_code = getattr(e, 'code', None)
        message = getattr(e, 'message', str(e))
        
        # Handle specific exceptions as requested: ResourceExhausted, InvalidArgument, API key errors, Network errors
        if status_code == 429:
            raise Exception(f"ResourceExhausted: API rate limit exceeded. {message}") from e
        elif status_code == 400:
            raise Exception(f"InvalidArgument: Invalid request structure. {message}") from e
        elif status_code in (401, 403):
            raise Exception(f"API key error: Access denied. {message}") from e
        else:
            raise Exception(f"Google GenAI API error ({status_code}): {message}") from e
    except Exception as e:
        logger.error(f"[AI] Error: {e}")
        raise e