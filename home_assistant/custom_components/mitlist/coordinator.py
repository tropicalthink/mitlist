"""Polling and Server-Sent Events coordinator."""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryAuthFailed
from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.storage import Store
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .api import (
    MitlistApiClient,
    MitlistApiError,
    MitlistAuthError,
    MitlistCursorResetError,
)
from .const import DEFAULT_SCAN_INTERVAL, DEFAULT_SSE_RECONNECT, DOMAIN

_LOGGER = logging.getLogger(__name__)


@dataclass(slots=True)
class MitlistRuntimeData:
    """Objects owned by one config entry for its loaded lifetime."""

    client: MitlistApiClient
    coordinator: MitlistDataUpdateCoordinator


MitlistConfigEntry = ConfigEntry[MitlistRuntimeData]


class MitlistDataUpdateCoordinator(DataUpdateCoordinator[dict[str, Any]]):
    """Keep all configured households in one shared update stream."""

    def __init__(
        self,
        hass: HomeAssistant,
        client: MitlistApiClient,
        entry: ConfigEntry,
    ) -> None:
        self.client = client
        self.entry = entry
        self.group_ids: list[str] = list(
            entry.options.get("groups", entry.data.get("groups", []))
        )
        self.domains: list[str] = list(
            entry.options.get("domains", entry.data.get("domains", []))
        )
        if (
            entry.options.get("enable_finance", entry.data.get("enable_finance", False))
            and "finance" not in self.domains
        ):
            self.domains.append("finance")
        self.sse_enabled = bool(
            entry.options.get("enable_sse", entry.data.get("enable_sse", True))
        )
        self._sse_tasks: dict[str, asyncio.Task[None]] = {}
        self._sse_cursors: dict[str, str] = {}
        self._cursor_store: Store[dict[str, str]] = Store(
            hass, 1, f"{DOMAIN}.{entry.entry_id}.sse_cursors"
        )
        self._cursors_loaded = False
        self.last_events: dict[str, dict[str, Any]] = {}
        self.last_event: datetime | None = None
        self.connection_state = "disconnected"
        interval = entry.options.get(
            "scan_interval",
            entry.data.get("scan_interval", DEFAULT_SCAN_INTERVAL.total_seconds()),
        )
        super().__init__(
            hass,
            _LOGGER,
            name=f"{DOMAIN}_{entry.entry_id}",
            update_method=self._async_update_data,
            update_interval=timedelta(seconds=max(30, float(interval))),
        )

    async def _async_update_data(self) -> dict[str, Any]:
        if not self._cursors_loaded:
            stored = await self._cursor_store.async_load()
            if isinstance(stored, dict):
                self._sse_cursors = {
                    str(key): str(value)
                    for key, value in stored.items()
                    if value is not None
                }
            self._cursors_loaded = True
        try:
            groups = await self.client.get_groups()
        except MitlistAuthError as err:
            raise ConfigEntryAuthFailed("Mitlist token is invalid") from err
        except MitlistApiError as err:
            raise UpdateFailed(str(err)) from err
        selected = {str(group.get("id")): group for group in groups if group.get("id")}
        if self.group_ids:
            selected = {gid: selected[gid] for gid in self.group_ids if gid in selected}
        self.group_ids = list(selected)
        result: dict[str, Any] = {
            "groups": selected,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "connection": "connected",
        }
        for group_id, group in selected.items():
            group_data: dict[str, Any] = {"group": group}
            for domain in self.domains:
                try:
                    if domain == "lists":
                        lists = await self.client.get_lists(group_id)
                        for item in lists:
                            if item.get("id"):
                                try:
                                    item["items"] = await self.client.get_list_items(
                                        str(item["id"]), group_id
                                    )
                                except MitlistApiError:
                                    item["items"] = []
                        group_data[domain] = lists
                    elif domain == "chores":
                        group_data[domain] = await self.client.get_chores(group_id)
                    elif domain == "calendar":
                        today = datetime.now(timezone.utc).date()
                        group_data[domain] = await self.client.get_calendar(
                            group_id,
                            today.isoformat(),
                            (today + timedelta(days=90)).isoformat(),
                        )
                    elif domain == "activity":
                        group_data[domain] = await self.client.get_activity(group_id)
                    elif domain == "notifications":
                        notifications = await self.client.get_domain(domain, group_id)
                        group_data[domain] = [
                            item
                            for item in notifications
                            if str(item.get("group_id") or group_id) == group_id
                        ]
                    else:
                        group_data[domain] = await self.client.get_domain(
                            domain, group_id
                        )
                except MitlistAuthError:
                    raise
                except MitlistApiError as err:
                    _LOGGER.warning(
                        "Unable to refresh %s for household %s: %s",
                        domain,
                        group_id,
                        err,
                    )
                    group_data[domain] = []
            result[group_id] = group_data
        self.connection_state = "connected"
        self._ensure_sse_tasks()
        return result

    def _ensure_sse_tasks(self) -> None:
        if not self.sse_enabled:
            return
        for group_id in self.group_ids:
            task = self._sse_tasks.get(group_id)
            if task is None or task.done():
                self._sse_tasks[group_id] = self.hass.async_create_task(
                    self._sse_loop(group_id)
                )

    async def _sse_loop(self, group_id: str) -> None:
        while True:
            try:
                self.connection_state = "connected"
                async for event in self.client.stream_events(
                    group_id, self._sse_cursors.get(group_id)
                ):
                    self.last_event = datetime.now(timezone.utc)
                    cursor = (
                        event.pop("_sse_id", None)
                        or event.get("id")
                        or event.get("event_id")
                    )
                    if cursor:
                        self._sse_cursors[group_id] = str(cursor)
                        await self._cursor_store.async_save(self._sse_cursors)
                    self.last_events[group_id] = dict(event)
                    self.connection_state = "connected"
                    self.hass.async_create_task(self.async_request_refresh())
            except asyncio.CancelledError:
                raise
            except MitlistAuthError:
                self.connection_state = "auth_failed"
                self.entry.async_start_reauth(self.hass)
                return
            except MitlistCursorResetError:
                self._sse_cursors.pop(group_id, None)
                await self._cursor_store.async_save(self._sse_cursors)
                await self.async_request_refresh()
            except MitlistApiError as err:
                self.connection_state = "disconnected"
                _LOGGER.debug("SSE household %s: %s", group_id, err)
            await asyncio.sleep(DEFAULT_SSE_RECONNECT.total_seconds())

    async def async_shutdown(self) -> None:
        for task in self._sse_tasks.values():
            task.cancel()
        if self._sse_tasks:
            await asyncio.gather(*self._sse_tasks.values(), return_exceptions=True)
        self._sse_tasks.clear()
        await super().async_shutdown()


def group_data(
    coordinator: MitlistDataUpdateCoordinator, group_id: str
) -> dict[str, Any]:
    """Return a household payload, tolerating an initial empty refresh."""
    if not coordinator.data:
        return {
            "group": {"id": group_id},
            "lists": [],
            "chores": [],
            "calendar": [],
            "activity": [],
        }
    return coordinator.data.get(group_id, {"group": {"id": group_id}})


def item_name(item: dict[str, Any], fallback: str = "Mitlist") -> str:
    return str(item.get("name") or item.get("title") or item.get("content") or fallback)


def group_device_info(
    coordinator: MitlistDataUpdateCoordinator, group_id: str
) -> DeviceInfo:
    """Represent a Mitlist household as a Home Assistant device."""
    group = group_data(coordinator, group_id).get("group", {})
    return DeviceInfo(
        identifiers={(DOMAIN, group_id)},
        manufacturer="mitlist",
        model="Household",
        name=item_name(group, "Mitlist household"),
    )
