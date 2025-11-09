# services/openai_client.py
import os
from openai import OpenAI

_client = None

def get_client() -> OpenAI:
    global _client
    if _client is None:
        api_key = os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise RuntimeError("OPENAI_API_KEY not set")
        base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
        _client = OpenAI(api_key=api_key, base_url=base_url)
    return _client

def get_model_text() -> str:
    return os.getenv("OPENAI_MODEL_TEXT", "gpt-4o-mini")

def get_model_vision() -> str:
    return os.getenv("OPENAI_MODEL_VISION", "gpt-4o-mini")

def get_temperature(default: float = 0.2) -> float:
    try:
        return float(os.getenv("OPENAI_TEMPERATURE", str(default)))
    except Exception:
        return default

def get_max_tokens(default: int = 512) -> int:
    try:
        return int(os.getenv("OPENAI_MAX_TOKENS", str(default)))
    except Exception:
        return default

def app_origin() -> str:
    return os.getenv("APP_ORIGIN", "").rstrip("/")
