"""Recent Mitlist activity as an HA event entity."""

from __future__ import annotations

from typing import ClassVar

from homeassistant.components.event import EventEntity
from homeassistant.core import HomeAssistant
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import (
    MitlistConfigEntry,
    MitlistDataUpdateCoordinator,
    group_device_info,
)


async def async_setup_entry(
    hass: HomeAssistant, entry: MitlistConfigEntry, async_add_entities
) -> None:
    coordinator = entry.runtime_data.coordinator
    async_add_entities(
        [
            MitlistActivityEvent(coordinator, group_id)
            for group_id in coordinator.group_ids
        ]
    )


class MitlistActivityEvent(
    CoordinatorEntity[MitlistDataUpdateCoordinator], EventEntity
):
    _attr_has_entity_name = True
    _attr_name = "Latest activity"
    _attr_event_types: ClassVar[list[str]] = ["update"]

    def __init__(self, coordinator, group_id: str) -> None:
        super().__init__(coordinator)
        self.group_id = group_id
        self._attr_unique_id = (
            f"{DOMAIN}_{coordinator.entry.entry_id}_{group_id}_activity"
        )
        self._seen: str | None = None

    def _handle_coordinator_update(self) -> None:
        latest = self.coordinator.last_events.get(self.group_id)
        if latest:
            event_id = str(
                latest.get("event_id")
                or latest.get("id")
                or latest.get("created_at")
                or ""
            )
            if event_id and event_id != self._seen:
                self._seen = event_id
                self._trigger_event("update", latest)
                self.async_write_ha_state()
        super()._handle_coordinator_update()

    @property
    def device_info(self):
        return group_device_info(self.coordinator, self.group_id)
