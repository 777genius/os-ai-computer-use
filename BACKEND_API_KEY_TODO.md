# Backend API Key Integration - TODO

## Current Status

✅ **Frontend Complete**: Full UI for API key management with secure storage
⏳ **Backend Integration**: Needs to accept API key via WebSocket

## What's Needed

### 1. WebSocket Handler Update

File: `packages/backend/src/os_ai_backend/ws.py`

**In `handle()` method (line 43)**:
```python
async def handle(self, websocket: WebSocket) -> None:
    # TODO: Extract API key from WebSocket query parameters
    # query_params = websocket.query_params
    # api_key = query_params.get('anthropic_api_key')

    # Store api_key in handler instance for session creation
    # self._api_key = api_key
```

**In `_create_session()` method (line 246)**:
```python
def _create_session(self, provider: Optional[str], api_key: Optional[str] = None) -> tuple[str, LLMClient, ToolRegistry]:
    inj = _create_container(provider, api_key=api_key)
    # ...
```

### 2. Container Creation

File: `packages/core/src/os_ai_core/di.py`

Update `create_container()` to accept and pass api_key to LLMClient:
```python
def create_container(provider: Optional[str] = None, api_key: Optional[str] = None):
    # When creating AnthropicClient, pass api_key if provided
    # client = AnthropicClient(api_key=api_key)  # Already supports this!
```

### 3. Fallback to Environment Variable

The AnthropicClient already has fallback logic:
```python
# In adapters_anthropic.py line 38:
key = api_key or os.environ.get("ANTHROPIC_API_KEY")
```

This means:
- If API key passed from frontend → use it
- If not → fall back to environment variable (for CLI usage)

## Testing

After implementation, test:

1. **GUI with API key**: Settings → Enter key → Should work
2. **CLI with env var**: `export ANTHROPIC_API_KEY=... && python main.py` → Should work
3. **Error handling**: No key → Should show clear error message

## Frontend Already Sends Key

The `AppConfig.wsUri()` method (line 20-32 in `app_config.dart`) already adds the API key to WebSocket query parameters:

```dart
Uri wsUri() {
  final uri = Uri.parse('ws://$host:$port/ws?token=$token');

  if (anthropicApiKey != null && anthropicApiKey!.isNotEmpty) {
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'anthropic_api_key': anthropicApiKey!,
    });
  }

  return uri;
}
```

**WebSocket URL example**: `ws://127.0.0.1:8765/ws?token=secret&anthropic_api_key=sk-ant-...`

## Summary

The frontend is **100% complete** and ready to send API keys.
Backend needs **~20 lines of code** to extract and use the key.

All the infrastructure is in place - just need to wire it together!
