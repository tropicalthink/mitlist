"""Async HTTP and SSE client for the Mitlist API.

The client intentionally returns JSON dictionaries rather than mirroring every
Mitlist model.  This keeps the integration compatible with additive backend
fields and makes old installations fail soft when a new field is introduced.
"""

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator, Mapping
from typing import Any
from urllib.parse import urlencode

import aiohttp

from .const import API_PREFIX, DEFAULT_TIMEOUT

_LOGGER = logging.getLogger(__name__)


class MitlistApiError(Exception):
    """An API request failed."""

    def __init__(self, status: int, message: str, *, payload: Any = None) -> None:
        super().__init__(message)
        self.status = status
        self.payload = payload


class MitlistAuthError(MitlistApiError):
    """The configured token is no longer valid."""


class MitlistCursorResetError(MitlistApiError):
    """The SSE replay cursor has fallen outside server retention."""


class MitlistApiClient:
    """Small, Home Assistant friendly, asynchronous Mitlist client."""

    def __init__(
        self,
        session: aiohttp.ClientSession,
        base_url: str,
        token: str,
        *,
        timeout: int = DEFAULT_TIMEOUT,
        verify_ssl: bool = True,
    ) -> None:
        self.session = session
        self.base_url = base_url.rstrip("/")
        if self.base_url.endswith(API_PREFIX):
            self.api_url = self.base_url
        else:
            self.api_url = f"{self.base_url}{API_PREFIX}"
        self.token = token
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.verify_ssl = verify_ssl

    @property
    def headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
            "User-Agent": "mitlist-home-assistant/1.0",
        }

    async def request(self, method: str, path: str, **kwargs: Any) -> Any:
        """Make an authenticated API request and decode its JSON response."""
        url = f"{self.api_url}/{path.lstrip('/')}"
        group_id = kwargs.pop("group_id", None)
        headers = {**self.headers, **kwargs.pop("headers", {})}
        if group_id:
            headers["X-Mitlist-Group-ID"] = str(group_id)
        try:
            async with self.session.request(
                method,
                url,
                headers=headers,
                timeout=kwargs.pop("timeout", self.timeout),
                ssl=self.verify_ssl,
                **kwargs,
            ) as response:
                text = await response.text()
                payload: Any = None
                if text:
                    try:
                        payload = json.loads(text)
                    except json.JSONDecodeError:
                        payload = text
                if response.status in (401, 403):
                    raise MitlistAuthError(
                        response.status,
                        "Mitlist authentication failed",
                        payload=payload,
                    )
                if response.status >= 400:
                    message = (
                        payload.get("message", payload.get("error", text))
                        if isinstance(payload, Mapping)
                        else text
                    )
                    raise MitlistApiError(
                        response.status,
                        str(message or response.reason),
                        payload=payload,
                    )
                return payload
        except asyncio.TimeoutError as err:
            raise MitlistApiError(408, "Mitlist request timed out") from err
        except aiohttp.ClientError as err:
            raise MitlistApiError(0, f"Unable to connect to Mitlist: {err}") from err

    async def get(self, path: str, **params: Any) -> Any:
        return await self.request(
            "GET", path, params={k: v for k, v in params.items() if v is not None}
        )

    async def post(
        self,
        path: str,
        payload: Mapping[str, Any] | None = None,
        *,
        group_id: str | None = None,
    ) -> Any:
        return await self.request(
            "POST", path, json=dict(payload or {}), group_id=group_id
        )

    async def patch(
        self, path: str, payload: Mapping[str, Any], *, group_id: str | None = None
    ) -> Any:
        return await self.request("PATCH", path, json=dict(payload), group_id=group_id)

    async def delete(
        self, path: str, *, group_id: str | None = None, **params: Any
    ) -> Any:
        return await self.request(
            "DELETE",
            path,
            params={k: v for k, v in params.items() if v is not None} or None,
            group_id=group_id,
        )

    async def get_groups(self) -> list[dict[str, Any]]:
        return _as_list(await self.get("groups"), "groups")

    async def get_domain(self, domain: str, group_id: str, **params: Any) -> Any:
        paths = {
            "groceries": (
                f"groups/{group_id}/grocery/graph",
                {**params, "since_version": 0},
            ),
            "meal_plans": ("meal-plans", {**params, "group_id": group_id}),
            "finance": ("finance/summary", {**params, "group_id": group_id}),
            "notifications": ("notifications", {**params}),
            "pinwall": ("pinwall/posts", {**params, "group_id": group_id}),
            "recipes": ("recipes", {**params, "group_id": group_id}),
        }
        path, query = paths.get(domain, (domain, {**params, "group_id": group_id}))
        return await self.get(path, **query)

    async def get_lists(self, group_id: str) -> list[dict[str, Any]]:
        return _as_list(await self.get("lists", group_id=group_id), "lists")

    async def get_list_items(self, list_id: str, group_id: str) -> list[dict[str, Any]]:
        return _as_list(
            await self.request(
                "GET",
                f"lists/{list_id}/items",
                params={"group_id": group_id},
                group_id=group_id,
            ),
            "items",
        )

    async def get_chores(self, group_id: str) -> list[dict[str, Any]]:
        return _as_list(
            await self.get("chores/current", group_id=group_id, due_soon_days=30),
            "chores",
        )

    async def get_calendar(
        self, group_id: str, start: str, end: str
    ) -> list[dict[str, Any]]:
        return _as_list(
            await self.get("calendar", group_id=group_id, **{"from": start, "to": end}),
            "events",
        )

    async def get_activity(
        self, group_id: str, limit: int = 50
    ) -> list[dict[str, Any]]:
        return _as_list(
            await self.get("activity", group_id=group_id, limit=limit), "events"
        )

    async def create_list(
        self, group_id: str, name: str, list_type: str = "shopping"
    ) -> Any:
        return await self.post(
            "lists",
            {"group_id": group_id, "name": name, "type": list_type},
            group_id=group_id,
        )

    async def add_item(
        self, list_id: str, name: str, *, group_id: str | None = None, **fields: Any
    ) -> Any:
        return await self.post(
            f"lists/{list_id}/items",
            {"name": name, **fields},
            group_id=group_id,
        )

    async def update_item(
        self,
        list_id: str,
        item_id: str,
        payload: Mapping[str, Any],
        *,
        group_id: str | None = None,
    ) -> Any:
        return await self.patch(
            f"lists/{list_id}/items/{item_id}", payload, group_id=group_id
        )

    async def delete_item(
        self, list_id: str, item_id: str, *, group_id: str | None = None
    ) -> Any:
        return await self.delete(f"lists/{list_id}/items/{item_id}", group_id=group_id)

    async def chore_action(
        self,
        chore_id: str,
        action: str,
        payload: Mapping[str, Any] | None = None,
        *,
        group_id: str | None = None,
    ) -> Any:
        return await self.request(
            "PATCH" if action == "pending" else "POST",
            f"chores/{chore_id}/{action}",
            json=dict(payload or {}),
            group_id=group_id,
        )

    async def action(
        self,
        path: str,
        payload: Mapping[str, Any] | None = None,
        *,
        method: str = "POST",
        group_id: str | None = None,
    ) -> Any:
        return await self.request(
            method, path, json=dict(payload or {}), group_id=group_id
        )

    async def stream_events(
        self, group_id: str, last_event_id: str | None = None
    ) -> AsyncIterator[dict[str, Any]]:
        """Yield decoded SSE data frames until the server closes the stream."""
        url = f"{self.api_url}/events?{urlencode({'group_id': group_id})}"
        headers = {**self.headers, "Accept": "text/event-stream"}
        if last_event_id:
            headers["Last-Event-ID"] = last_event_id
        try:
            async with self.session.get(
                url,
                headers=headers,
                timeout=None,
                ssl=self.verify_ssl,
            ) as response:
                if response.status in (401, 403):
                    raise MitlistAuthError(
                        response.status, "Mitlist authentication failed"
                    )
                if (
                    response.status == 409
                    and response.headers.get("X-SSE-Cursor-Reset") == "true"
                ):
                    raise MitlistCursorResetError(
                        response.status, "Mitlist event cursor expired"
                    )
                if response.status >= 400:
                    raise MitlistApiError(
                        response.status, f"SSE connection failed ({response.status})"
                    )
                data_lines: list[str] = []
                event_id: str | None = None
                async for raw_line in response.content:
                    line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
                    if line.startswith("data:"):
                        data_lines.append(line[5:].lstrip())
                    elif line.startswith("id:"):
                        event_id = line[3:].strip()
                    elif not line and data_lines:
                        raw_data = "\n".join(data_lines)
                        data_lines.clear()
                        try:
                            decoded = json.loads(raw_data)
                        except json.JSONDecodeError:
                            _LOGGER.debug("Ignoring malformed Mitlist SSE frame")
                            continue
                        if isinstance(decoded, dict):
                            if event_id and "_sse_id" not in decoded:
                                decoded["_sse_id"] = event_id
                            yield decoded
                        event_id = None
        except asyncio.CancelledError:
            raise
        except aiohttp.ClientError as err:
            raise MitlistApiError(
                0, f"Mitlist event stream disconnected: {err}"
            ) from err


def _as_list(payload: Any, key: str) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, Mapping):
        value = payload.get(key, payload.get("data", []))
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
    return []
