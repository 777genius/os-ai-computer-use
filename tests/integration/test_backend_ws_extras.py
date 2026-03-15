import os
import json
import time
import concurrent.futures
import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from os_ai_backend.app import create_app
from os_ai_llm.interfaces import LLMClient
from os_ai_llm.types import LLMResponse, Message, TextPart, Usage
from os_ai_core.tools.registry import ToolRegistry


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.setenv("OS_AI_BACKEND_TOKEN", "secret")

    class DummyLLM(LLMClient):  # type: ignore[abstract-method]
        def __init__(self):
            self.calls = 0
        def generate(self, *, messages, tools, system, **kwargs):  # type: ignore[override]
            self.calls += 1
            # Return no tool calls and simple assistant
            return LLMResponse(messages=[Message(role="assistant", content=[TextPart(text=f"iter{self.calls}")])], tool_calls=[], usage=Usage(input_tokens=1, output_tokens=2))
        def format_tool_result(self, result):  # type: ignore[override]
            return Message(role="user", content=[TextPart(text="tool_result")])

    def fake_container(_provider=None, **kw):
        class _Inj:
            _llm = DummyLLM()
            def get(self, cls):
                if cls.__name__ == "LLMClient":
                    return self._llm
                if cls.__name__ == "ToolRegistry":
                    return ToolRegistry()
                raise KeyError(cls)
        return _Inj()

    import os_ai_backend.ws as backend_ws
    monkeypatch.setattr(backend_ws, "_create_container", fake_container)

    app = create_app()
    return TestClient(app)


def _recv_until(ws, method, timeout: float = 5.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
            fut = ex.submit(ws.receive_text)
            try:
                raw = fut.result(timeout=max(0.1, deadline - time.time()))
            except concurrent.futures.TimeoutError:
                continue
        msg = json.loads(raw)
        if msg.get("method") == method:
            return msg
    raise AssertionError("event not received")


def test_settings_update_and_metrics(client):
    # metrics before
    m0 = client.get("/metrics").json()
    assert "ws_connections" in m0

    # change log level
    r = client.post("/settings.update", headers={"Authorization": "Bearer secret"}, json={"log_level": "DEBUG"})
    assert r.status_code == 200
    assert r.json()["ok"] is True

    # auth required
    r2 = client.post("/settings.update", json={"log_level": "INFO"})
    assert r2.status_code == 401


def test_cancel_flow(client):
    with client.websocket_connect("/ws?token=secret") as ws:
        ws.send_text(json.dumps({"jsonrpc": "2.0", "id": "1", "method": "agent.run", "params": {"task": "long", "maxIterations": 2}}))
        r1 = json.loads(ws.receive_text())
        job_id = r1["result"]["jobId"]
        # cancel immediately
        ws.send_text(json.dumps({"jsonrpc": "2.0", "id": "2", "method": "agent.cancel", "params": {"jobId": job_id}}))
        # responses and events may race; wait for reply with id=="2"
        r2 = None
        for _ in range(10):
            msg = json.loads(ws.receive_text())
            if msg.get("id") == "2":
                r2 = msg
                break
        assert r2 is not None
        assert r2["result"]["ok"] is True
        # we should still receive final
        final = _recv_until(ws, "event.final")
        assert final["params"]["jobId"] == job_id


def test_upload_large_file_returns_413(client, monkeypatch):
    # patch store limit live to avoid singleton caching
    import os_ai_backend.files as fmod
    fmod.store.max_file_bytes = 100
    data = b"x" * 10000
    r = client.post("/v1/files", headers={"Authorization": "Bearer secret"}, files={"file": ("b.bin", data, "application/octet-stream")})
    assert r.status_code == 413
