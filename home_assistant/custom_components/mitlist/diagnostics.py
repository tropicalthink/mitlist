"""Diagnostics support without exposing API credentials."""

from __future__ import annotations

from typing import Any

from homeassistant.core import HomeAssistant
from homeassistant.helpers.redact import async_redact_data

from .coordinator import MitlistConfigEntry

TO_REDACT = {"token", "access_token", "refresh_token", "authorization", "password"}


async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: MitlistConfigEntry
) -> dict[str, Any]:
    coordinator = entry.runtime_data.coordinator
    return {
        "config_entry": async_redact_data(dict(entry.data), TO_REDACT),
        "options": async_redact_data(dict(entry.options), TO_REDACT),
        "connection": getattr(coordinator, "connection_state", "not_loaded"),
        "last_event": getattr(coordinator, "last_event", None).isoformat()
        if getattr(coordinator, "last_event", None)
        else None,
        "households": [
            {"id": group_id, "domains": sorted(value.keys())}
            for group_id, value in (getattr(coordinator, "data", {}) or {}).items()
            if group_id != "groups" and isinstance(value, dict)
        ],
    }
