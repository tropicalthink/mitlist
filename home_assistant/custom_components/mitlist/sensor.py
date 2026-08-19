"""Useful household counters and connection telemetry."""

from __future__ import annotations

from typing import Any

from homeassistant.components.sensor import SensorEntity
from homeassistant.const import EntityCategory
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity import Entity
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import (
    MitlistConfigEntry,
    MitlistDataUpdateCoordinator,
    group_data,
    group_device_info,
    item_name,
)


async def async_setup_entry(
    hass: HomeAssistant, entry: MitlistConfigEntry, async_add_entities
) -> None:
    coordinator = entry.runtime_data.coordinator
    entities: list[Entity] = [MitlistConnectionSensor(coordinator)]
    for group_id in coordinator.group_ids:
        for key in (
            "lists",
            "chores_due",
            "calendar",
            "pinwall",
            "notifications_unread",
            "finance_reimbursements",
            "groceries_known",
        ):
            source_domain = key.split("_", maxsplit=1)[0]
            if source_domain in coordinator.domains:
                entities.append(MitlistCountSensor(coordinator, group_id, key))
    async_add_entities(entities)


class MitlistConnectionSensor(
    CoordinatorEntity[MitlistDataUpdateCoordinator], SensorEntity
):
    _attr_has_entity_name = True
    _attr_entity_category = EntityCategory.DIAGNOSTIC
    _attr_name = "Connection"
    _attr_icon = "mdi:cloud-check"

    @property
    def native_value(self) -> str:
        return self.coordinator.connection_state

    @property
    def available(self) -> bool:
        """Keep connection diagnostics visible while other entities are unavailable."""
        return True

    def __init__(self, coordinator: MitlistDataUpdateCoordinator) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = f"{DOMAIN}_{coordinator.entry.entry_id}_connection"


class MitlistCountSensor(CoordinatorEntity[MitlistDataUpdateCoordinator], SensorEntity):
    _attr_has_entity_name = True

    def __init__(
        self,
        coordinator: MitlistDataUpdateCoordinator,
        group_id: str,
        key: str,
    ) -> None:
        super().__init__(coordinator)
        self.group_id, self.key = group_id, key
        self._attr_unique_id = (
            f"{DOMAIN}_{coordinator.entry.entry_id}_{group_id}_{key}_count"
        )
        self._attr_name = {
            "lists": "Lists",
            "chores_due": "Chores due",
            "calendar": "Upcoming events",
            "pinwall": "Pinwall posts",
            "notifications_unread": "Unread notifications",
            "finance_reimbursements": "Suggested reimbursements",
            "groceries_known": "Known groceries",
        }[key]
        self._attr_icon = {
            "lists": "mdi:format-list-checks",
            "chores_due": "mdi:broom",
            "calendar": "mdi:calendar",
            "pinwall": "mdi:note-multiple",
            "notifications_unread": "mdi:bell-badge",
            "finance_reimbursements": "mdi:cash-sync",
            "groceries_known": "mdi:food-apple",
        }[key]

    @property
    def native_value(self) -> int:
        data = group_data(self.coordinator, self.group_id)
        if self.key == "chores_due":
            return sum(
                item.get("pending_assignment") is not None
                and item.get("due_status") in {"overdue", "due_today", "due_soon"}
                for item in data.get("chores", [])
            )
        if self.key == "notifications_unread":
            return sum(
                not item.get("is_read", False) for item in data.get("notifications", [])
            )
        if self.key == "finance_reimbursements":
            return len(data.get("finance", {}).get("reimbursements", []))
        if self.key == "groceries_known":
            return len(data.get("groceries", {}).get("canonical_items", []))
        source = "pinwall" if self.key == "pinwall" else self.key
        return len(data.get(source, []))

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        return {
            "household": item_name(
                group_data(self.coordinator, self.group_id).get("group", {}),
                "Household",
            ),
            "group_id": self.group_id,
        }

    @property
    def device_info(self):
        return group_device_info(self.coordinator, self.group_id)
