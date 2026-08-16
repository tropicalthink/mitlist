"""Binary health and due-state sensors."""

from __future__ import annotations

from homeassistant.components.binary_sensor import (
    BinarySensorDeviceClass,
    BinarySensorEntity,
)
from homeassistant.core import HomeAssistant
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import (
    MitlistConfigEntry,
    MitlistDataUpdateCoordinator,
    group_data,
    group_device_info,
)


async def async_setup_entry(
    hass: HomeAssistant, entry: MitlistConfigEntry, async_add_entities
) -> None:
    coordinator = entry.runtime_data.coordinator
    async_add_entities(
        [MitlistDueSensor(coordinator, group_id) for group_id in coordinator.group_ids]
    )


class MitlistDueSensor(
    CoordinatorEntity[MitlistDataUpdateCoordinator], BinarySensorEntity
):
    _attr_has_entity_name = True
    _attr_device_class = BinarySensorDeviceClass.PROBLEM
    _attr_name = "Items due"

    def __init__(self, coordinator, group_id: str) -> None:
        super().__init__(coordinator)
        self.group_id = group_id
        self._attr_unique_id = (
            f"{DOMAIN}_{coordinator.entry.entry_id}_{group_id}_items_due"
        )

    @property
    def is_on(self) -> bool:
        return any(
            chore.get("pending_assignment") is not None
            and chore.get("due_status") in {"overdue", "due_today", "due_soon"}
            for chore in group_data(self.coordinator, self.group_id).get("chores", [])
        )

    @property
    def device_info(self):
        return group_device_info(self.coordinator, self.group_id)
