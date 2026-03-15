# LLM generic config
LLM_PROVIDER = 'anthropic'
MAX_TOKENS = 1500
# HTTP 429 retry/backoff (generic)
API_MAX_RETRIES = 5
API_BACKOFF_BASE_SECONDS = 3.0
API_BACKOFF_MAX_SECONDS = 30.0
API_BACKOFF_JITTER_SECONDS = 0.5
ALLOW_PARALLEL_TOOL_USE = False
API_REQUEST_TIMEOUT_SECONDS = 20.0

# Computer tool types per provider
COMPUTER_TOOL_TYPES = {
    "anthropic": "computer_20250124",
    "openai": "computer",
}
