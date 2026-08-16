"""Async client contract tests that do not require a Home Assistant install."""

from __future__ import annotations

import asyncio
import importlib.util
import json
import sys
import types
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).parents[1]


def _load_api_module():
    """Load api.py with only the two package constants it depends on."""
    custom_components = types.ModuleType("custom_components")
    custom_components.__path__ = [str(ROOT / "custom_components")]
    package = types.ModuleType("custom_components.mitlist")
    package.__path__ = [str(ROOT / "custom_components" / "mitlist")]
    constants = types.ModuleType("custom_components.mitlist.const")
    constants.API_PREFIX = "/api/v1"
    constants.DEFAULT_TIMEOUT = 30
    module_names = (
        "custom_components",
        "custom_components.mitlist",
        "custom_components.mitlist.const",
        "custom_components.mitlist.api",
    )
    previous = {name: sys.modules.get(name) for name in module_names}
    sys.modules.update(
        {
            "custom_components": custom_components,
            "custom_components.mitlist": package,
            "custom_components.mitlist.const": constants,
        }
    )
    spec = importlib.util.spec_from_file_location(
        "custom_components.mitlist.api",
        ROOT / "custom_components" / "mitlist" / "api.py",
    )
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    try:
        spec.loader.exec_module(module)
        return module
    finally:
        for name, old_module in previous.items():
            if old_module is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = old_module


api = _load_api_module()


class _Content:
    def __init__(self, lines: list[bytes]) -> None:
        self._lines = lines

    async def __aiter__(self) -> AsyncIterator[bytes]:
        for line in self._lines:
            yield line


class _Response:
    def __init__(
        self,
        status: int,
        payload: Any = None,
        *,
        headers: dict[str, str] | None = None,
        lines: list[bytes] | None = None,
    ) -> None:
        self.status = status
        self.reason = "test"
        self.headers = headers or {}
        self.content = _Content(lines or [])
        self._payload = payload

    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args: object) -> None:
        return None

    async def text(self) -> str:
        if self._payload is None:
            return ""
        if isinstance(self._payload, str):
            return self._payload
        return json.dumps(self._payload)


class _Session:
    def __init__(self, responses: list[_Response]) -> None:
        self.responses = responses
        self.calls: list[tuple[str, str, dict[str, Any]]] = []

    def request(self, method: str, url: str, **kwargs: Any) -> _Response:
        self.calls.append((method, url, kwargs))
        return self.responses.pop(0)

    def get(self, url: str, **kwargs: Any) -> _Response:
        return self.request("GET", url, **kwargs)


def test_as_list_accepts_envelopes_and_discards_non_objects() -> None:
    assert api._as_list([{"id": "one"}], "items") == [{"id": "one"}]
    assert api._as_list({"items": [None, {"id": "two"}]}, "items") == [{"id": "two"}]
    assert api._as_list({"data": [{"id": "three"}]}, "items") == [{"id": "three"}]


def test_mutation_sends_group_scope_header() -> None:
    session = _Session([_Response(200, {"id": "item-1"})])
    client = api.MitlistApiClient(session, "https://example.test", "ml_int_secret")

    asyncio.run(
        client.update_item("list-1", "item-1", {"checked": True}, group_id="group-1")
    )

    method, url, kwargs = session.calls[0]
    assert method == "PATCH"
    assert url == "https://example.test/api/v1/lists/list-1/items/item-1"
    assert kwargs["headers"]["X-Mitlist-Group-ID"] == "group-1"


def test_auth_failures_use_distinct_exception() -> None:
    session = _Session([_Response(401, {"message": "revoked"})])
    client = api.MitlistApiClient(session, "https://example.test", "ml_int_secret")

    with pytest.raises(api.MitlistAuthError):
        asyncio.run(client.get_groups())


def test_sse_preserves_durable_cursor() -> None:
    response = _Response(
        200,
        lines=[
            b"id: 42\n",
            b'data: {"type":"list:updated","group_id":"group-1"}\n',
            b"\n",
        ],
    )
    session = _Session([response])
    client = api.MitlistApiClient(session, "https://example.test", "ml_int_secret")

    async def collect() -> list[dict[str, Any]]:
        return [event async for event in client.stream_events("group-1", "41")]

    assert asyncio.run(collect()) == [
        {"type": "list:updated", "group_id": "group-1", "_sse_id": "42"}
    ]
    assert session.calls[0][2]["headers"]["Last-Event-ID"] == "41"
