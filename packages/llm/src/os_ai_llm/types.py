from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Literal


# Basic content parts
ContentType = Literal["text", "image"]


@dataclass
class TextPart:
    type: Literal["text"] = "text"
    text: str = ""


@dataclass
class ImagePart:
    type: Literal["image"] = "image"
    media_type: str = "image/png"
    data_base64: str = ""  # base64-encoded image data


@dataclass
class ProviderPart:
    """Opaque provider-specific content block.

    Each provider adapter knows how to serialize/deserialize its own ProviderPart.
    Used instead of text-based markers for tool_use/tool_result round-tripping.
    """
    type: Literal["provider_native"] = "provider_native"
    provider: str = ""
    data: Any = None
    sub_type: str = ""


ContentPart = TextPart | ImagePart | ProviderPart


@dataclass
class Message:
    role: Literal["system", "user", "assistant", "tool"]
    content: List[ContentPart]


@dataclass
class ToolDescriptor:
    name: str
    kind: Literal["computer_use", "function"]
    params: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ToolCall:
    id: str
    name: str
    args: Dict[str, Any]           # action data only (clean, no internal routing flags)
    metadata: Dict[str, Any] = field(default_factory=dict)  # internal routing (_openai_batch, safety_checks)


@dataclass
class ToolResult:
    tool_call_id: str
    content: List[ContentPart]
    is_error: bool = False
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class Usage:
    input_tokens: int = 0
    output_tokens: int = 0
    provider_raw: Any = None


@dataclass
class LLMResponse:
    messages: List[Message]
    tool_calls: List[ToolCall]
    usage: Usage
    provider_context: Optional[Dict[str, Any]] = None
