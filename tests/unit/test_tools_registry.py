from __future__ import annotations

from os_ai_core.tools.registry import ToolRegistry
from os_ai_llm.types import ToolCall


def test_tools_registry_normalizes_text_and_image_blocks():
    reg = ToolRegistry()

    def handler(args):
        return [
            {"type": "text", "text": "hello"},
            {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": "abc"}},
        ]

    reg.register("computer", handler)

    call = ToolCall(id="1", name="computer", args={})
    res = reg.execute(call)

    assert res.tool_call_id == "1"
    assert len(res.content) == 2

