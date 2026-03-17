from __future__ import annotations

import asyncio
import logging
import os
from typing import Any, Dict

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware

try:
    import orjson as json  # type: ignore
except Exception:  # pragma: no cover - fallback if orjson not available
    import json  # type: ignore

from os_ai_core.utils.logger import setup_logging

from . import __version__
from .ws import WebSocketRPCHandler
from .security import require_token
from .config import load_config
from .files import store
from .metrics import metrics
from .settings import settings


def create_app() -> FastAPI:
    cfg = load_config()
    try:
        debug = os.getenv("OS_AI_BACKEND_DEBUG", "0") not in ("", "0", "false", "False")
        setup_logging(debug=debug)
    except Exception:
        pass
    app = FastAPI(title="OS AI Backend", version=__version__)

    # CORS can be relaxed in development; keep strict by default
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(cfg.allow_origins),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"]
    )

    @app.get("/healthz")
    async def healthz() -> Dict[str, Any]:
        logging.getLogger("os_ai.backend").info("GET /healthz -> ok")
        cfg = load_config()
        # возвращаем выборочно публичные поля конфига
        return {
            "status": "ok",
            "version": __version__,
            "config": {
                "history_pairs_limit": cfg.history_pairs_limit,
            },
        }

    handler = WebSocketRPCHandler()

    @app.websocket("/ws")
    async def ws_endpoint(websocket: WebSocket) -> None:
        # Optional token check via query param `token`
        token = websocket.query_params.get("token")
        cfg = load_config()
        if cfg.token and token != cfg.token:
            logging.getLogger("os_ai.backend").warning("WS unauthorized: missing/invalid token")
            await websocket.close(code=4401)
            return
        await websocket.accept()
        logging.getLogger("os_ai.backend").info("WS connected")
        try:
            await handler.handle(websocket)
        except WebSocketDisconnect:
            # Normal disconnect by client
            logging.getLogger("os_ai.backend").info("WS disconnected")
        except Exception as exc:  # pragma: no cover - last resort safety
            logging.getLogger("os_ai.backend").exception("WS handler error: %s", exc)
            try:
                await websocket.close()
            except Exception:
                pass

    @app.post("/v1/files")
    async def upload_file(request: Request, file: UploadFile = File(...)) -> dict:
        cfg = load_config()
        require_token(request, cfg.token)
        data = await file.read()
        try:
            meta = store.save_bytes(data, file.filename or "upload.bin", getattr(file, "content_type", None))
        except ValueError as e:
            raise HTTPException(status_code=413, detail=str(e))
        logging.getLogger("os_ai.backend").info("Uploaded file id=%s name=%s size=%s", meta.id, meta.original_name, len(data))
        return {"fileId": meta.id, "name": meta.original_name}

    @app.get("/v1/files/{file_id}")
    async def download_file(file_id: str, request: Request):
        cfg = load_config()
        require_token(request, cfg.token)
        try:
            meta = store.get(file_id)
        except KeyError:
            logging.getLogger("os_ai.backend").warning("Download file not found id=%s", file_id)
            raise HTTPException(status_code=404, detail="file not found")
        from fastapi.responses import FileResponse
        logging.getLogger("os_ai.backend").info("Download file id=%s name=%s", file_id, meta.original_name)
        return FileResponse(path=str(meta.path), filename=meta.original_name, media_type=meta.mime or "application/octet-stream")

    @app.get("/metrics")
    async def get_metrics() -> Dict[str, Any]:
        return metrics.snapshot()

    @app.post("/settings.update")
    async def update_settings(request: Request, body: Dict[str, Any]) -> Dict[str, Any]:
        cfg = load_config()
        require_token(request, cfg.token)
        s = settings.update(**body)
        logging.getLogger("os_ai.backend").info("Settings updated: %s", list(body.keys()))
        return {"ok": True, "settings": s.__dict__}

    return app


def _ensure_std_streams() -> None:
    """Гарантирует, что sys.stdout/stderr не None.

    На Windows при запуске без консоли (PyInstaller --noconsole)
    Python ставит sys.stdout = sys.stderr = None,
    и uvicorn падает с AttributeError: 'NoneType' has no attribute 'isatty'.
    """
    import sys
    if sys.stdout is None:
        sys.stdout = open(os.devnull, "w")
    if sys.stderr is None:
        sys.stderr = open(os.devnull, "w")


def main() -> None:
    _ensure_std_streams()

    debug = os.getenv("OS_AI_BACKEND_DEBUG", "0") not in ("", "0", "false", "False")
    setup_logging(debug=debug)

    cfg = load_config()
    host = cfg.host
    port = cfg.port
    logging.getLogger("os_ai.backend").info("Starting backend on %s:%s (debug=%s)", host, port, debug)

    import uvicorn

    uvicorn.run(
        create_app(),
        host=host,
        port=port,
        reload=False,
        log_level="debug" if debug else "info",
    )
