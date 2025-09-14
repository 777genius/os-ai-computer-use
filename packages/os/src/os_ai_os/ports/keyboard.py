from __future__ import annotations

from typing import Protocol, Tuple


class Keyboard(Protocol):
    def press_enter(self) -> None: ...
    def press_combo(self, keys: Tuple[str, ...]) -> None: ...
    def type_text(self, text: str, *, wpm: int = 180) -> None: ...


