"""Mitlist calendar aggregation platform."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from homeassistant.components.calendar import CalendarEntity, CalendarEvent
from homeassistant.core import HomeAssistant
from homeassistant.helpers.update_coordinator import CoordinatorEntity
from homeassistant.util import dt as dt_util

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
    async_add_entities(
        [MitlistCalendar(coordinator, group_id) for group_id in coordinator.group_ids]
    )


class MitlistCalendar(CoordinatorEntity[MitlistDataUpdateCoordinator], CalendarEntity):
    """Household calendar containing chores, meals, and expenses."""

    _attr_has_entity_name = True

    def __init__(
        self, coordinator: MitlistDataUpdateCoordinator, group_id: str
    ) -> None:
        super().__init__(coordinator)
        self.group_id = group_id
        group = group_data(coordinator, group_id).get("group", {})
        self._attr_name = f"{item_name(group, 'Household')} calendar"
        self._attr_unique_id = (
            f"{DOMAIN}_{coordinator.entry.entry_id}_{group_id}_calendar"
        )

    @property
    def event(self) -> CalendarEvent | None:
        now = dt_util.now()
        upcoming = [event for event in self._events() if event.end > now]
        return min(upcoming, key=lambda event: event.start) if upcoming else None

    async def async_get_events(
        self, hass: HomeAssistant, start_date: datetime, end_date: datetime
    ) -> list[CalendarEvent]:
        return [
            event
            for event in self._events()
            if event.end > start_date and event.start < end_date
        ]

    def _events(self) -> list[CalendarEvent]:
        events: list[CalendarEvent] = []
        for raw in group_data(self.coordinator, self.group_id).get("calendar", []):
            start = _parse(
                raw.get("start")
                or raw.get("start_at")
                or raw.get("due_date")
                or raw.get("date")
            )
            if start is None:
                continue
            end = _parse(raw.get("end") or raw.get("end_at"))
            if end is None or end <= start:
                end = start + timedelta(hours=1)
            events.append(
                CalendarEvent(
                    uid=str(raw.get("id")) if raw.get("id") else None,
                    summary=item_name(raw, "Mitlist event"),
                    start=start,
                    end=end,
                    description=raw.get("description")
                    or raw.get("notes")
                    or str(raw.get("type") or "Mitlist"),
                    location=raw.get("location"),
                )
            )
        return sorted(events, key=lambda event: event.start)

    @property
    def device_info(self):
        return group_device_info(self.coordinator, self.group_id)


def _parse(value: Any) -> datetime | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
