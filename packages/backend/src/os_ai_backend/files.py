from __future__ import annotations

import os
import tempfile
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple
import threading
import time


import sys


def _default_root() -> Path:
    base = os.getenv("OS_AI_BACKEND_FILES_DIR")
    if base:
        p = Path(base)
    elif sys.platform == "win32":
        local = os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))
        p = Path(local) / "OS AI" / "files"
    else:
        p = Path(tempfile.gettempdir()) / "os_ai_backend_files"
    p.mkdir(parents=True, exist_ok=True)
    return p


_WINDOWS_RESERVED = {"CON", "PRN", "AUX", "NUL"} | {f"COM{i}" for i in range(1, 10)} | {f"LPT{i}" for i in range(1, 10)}


def _sanitize_filename(name: str) -> str:
    safe = "".join(ch for ch in name if ch.isalnum() or ch in (".", "-", "_", " ")).strip().replace(" ", "_")
    # Защита от зарезервированных имён Windows (CON, PRN, NUL и т.д.)
    stem = safe.split(".")[0].upper()
    if stem in _WINDOWS_RESERVED:
        safe = f"_{safe}"
    return safe


@dataclass
class StoredFile:
    id: str
    path: Path
    original_name: str
    mime: str | None = None


class FileStore:
    def __init__(self, root: Path | None = None) -> None:
        self._root = root or _default_root()
        self._index: Dict[str, StoredFile] = {}
        self._lock = threading.Lock()
        # Limits from env (MB → bytes)
        max_total_mb = float(os.getenv("OS_AI_BACKEND_FILES_MAX_TOTAL_MB", "256"))
        max_file_mb = float(os.getenv("OS_AI_BACKEND_FILES_MAX_FILE_MB", "64"))
        ttl_seconds = float(os.getenv("OS_AI_BACKEND_FILES_TTL_SECONDS", "86400"))  # 24h
        self.max_total_bytes = int(max_total_mb * 1024 * 1024)
        self.max_file_bytes = int(max_file_mb * 1024 * 1024)
        self.ttl_seconds = int(ttl_seconds)

    def save_bytes(self, data: bytes, filename: str, mime: str | None = None) -> StoredFile:
        if len(data) > self.max_file_bytes:
            raise ValueError("file too large")
        fid = str(uuid.uuid4())
        safe_name = _sanitize_filename(filename) or "file.bin"
        path = self._root / f"{fid}_{safe_name}"
        path.write_bytes(data)
        meta = StoredFile(id=fid, path=path, original_name=safe_name, mime=mime)
        with self._lock:
            self._index[fid] = meta
            self._gc_locked()
        return meta

    def get(self, file_id: str) -> StoredFile:
        # Opportunistic cleanup on get
        with self._lock:
            self._gc_locked()
            sf = self._index.get(file_id)
            if not sf:
                prefix = f"{file_id}_"
                for child in self._root.glob(f"{file_id}_*"):
                    name = child.name
                    if name.startswith(prefix):
                        sf = StoredFile(id=file_id, path=child, original_name=name[len(prefix):])
                        self._index[file_id] = sf
                        break
            if not sf:
                raise KeyError(file_id)
            return sf

    def _list_index_files_locked(self) -> List[Tuple[str, StoredFile]]:
        items: List[Tuple[str, StoredFile]] = []
        for fid, sf in list(self._index.items()):
            try:
                if not sf.path.exists():
                    self._index.pop(fid, None)
                    continue
                items.append((fid, sf))
            except Exception:
                pass
        return items

    def _total_size_bytes_locked(self) -> int:
        total = 0
        for _, sf in self._list_index_files_locked():
            try:
                total += sf.path.stat().st_size
            except Exception:
                pass
        return total

    def _gc_locked(self) -> None:
        now = time.time()
        # TTL-based deletion first
        for fid, sf in list(self._index.items()):
            try:
                st = sf.path.stat()
                if now - st.st_mtime > self.ttl_seconds:
                    try:
                        sf.path.unlink(missing_ok=True)  # type: ignore[arg-type]
                    except Exception:
                        pass
                    self._index.pop(fid, None)
            except FileNotFoundError:
                self._index.pop(fid, None)
            except Exception:
                pass

        # Enforce total size limit by removing oldest files
        total = self._total_size_bytes_locked()
        if total <= self.max_total_bytes:
            return
        entries = []
        for fid, sf in self._list_index_files_locked():
            try:
                st = sf.path.stat()
                entries.append((st.st_mtime, fid, sf))
            except Exception:
                entries.append((0.0, fid, sf))
        entries.sort(key=lambda t: (t[0], t[1]))  # old first
        for _, fid, sf in entries:
            try:
                size = sf.path.stat().st_size
            except Exception:
                size = 0
            try:
                sf.path.unlink(missing_ok=True)  # type: ignore[arg-type]
            except Exception:
                pass
            self._index.pop(fid, None)
            total -= size
            if total <= self.max_total_bytes:
                break


# singleton for app
store = FileStore()


