from __future__ import annotations

from typing import List, Dict, Any, Tuple

from os_ai_core.config import (
    SIMPLE_STEP_MAX_TOKENS,
    HISTORY_MAX_MESSAGES,
    HISTORY_SUMMARY_MAX_CHARS,
)


SIMPLE_ACTIONS = {
    "mouse_move",
    "left_click",
    "double_click",
    "triple_click",
    "right_click",
    "middle_click",
    "left_mouse_down",
    "left_mouse_up",
    "scroll",
    "type",  # короткие вводы
}


class ConversationOptimizer:
    def __init__(self):
        self.summary: str | None = None

    def choose_max_tokens(self, pending_tool_action: str | None) -> int | None:
        """Если шаг простой — ограничить max_tokens для экономии.

        Возвращает None, если ограничение не нужно.
        """
        if pending_tool_action and pending_tool_action in SIMPLE_ACTIONS:
            return int(SIMPLE_STEP_MAX_TOKENS)
        return None

    def summarize_history(self, messages: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], str | None]:
        """Оставляет только последние HISTORY_MAX_MESSAGES сообщений.
        Старшие сообщения сворачивает в текстовую сводку (короткая), которую можно подмешать в system.
        """
        if len(messages) <= HISTORY_MAX_MESSAGES:
            return messages, None

        head = messages[:-HISTORY_MAX_MESSAGES]
        tail = messages[-HISTORY_MAX_MESSAGES:]

        # Грубая текстовая сводка из head (без картинок/больших блоков)
        parts: List[str] = []
        for m in head:
            role = m.get("role", "user")
            content = m.get("content")
            if isinstance(content, str):
                parts.append(f"[{role}] {content}")
            elif isinstance(content, list):
                # собрать короткий текст
                texts: List[str] = []
                for c in content:
                    try:
                        if isinstance(c, dict):
                            t = c.get("text")
                            if isinstance(t, str) and t.strip():
                                texts.append(t.strip())
                    except Exception:
                        pass
                if texts:
                    parts.append(f"[{role}] " + " | ".join(texts))

        summary_text = "\n".join(parts)
        if len(summary_text) > HISTORY_SUMMARY_MAX_CHARS:
            summary_text = summary_text[:HISTORY_SUMMARY_MAX_CHARS] + "…"
        self.summary = summary_text if summary_text else None
        return tail, self.summary


