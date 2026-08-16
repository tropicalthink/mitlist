"""Focused contracts against the installed Home Assistant entity APIs."""

# ruff: noqa: I001

from __future__ import annotations

from types import SimpleNamespace

import pytest

pytest.importorskip("homeassistant")

from homeassistant.components.sensor import SensorEntity
from homeassistant.components.todo import (
    TodoItemStatus,
    TodoListEntity,
)

from custom_components.mitlist import _action_payload, _find_group_id
from custom_components.mitlist.sensor import (
    MitlistConnectionSensor,
    MitlistCountSensor,
)
from custom_components.mitlist.todo import MitlistChoresTodo


class _Coordinator(SimpleNamespace):
    last_update_success = True


def _coordinator() -> _Coordinator:
    group_id = "group-1"
    return _Coordinator(
        entry=SimpleNamespace(entry_id="entry-1"),
        group_ids=[group_id],
        connection_state="connected",
        data={
            group_id: {
                "group": {"id": group_id, "name": "Home"},
                "lists": [{"id": "list-1", "items": []}],
                "chores": [
                    {
                        "chore": {"id": "chore-1", "name": "Kitchen"},
                        "pending_assignment": {"due_date": "2026-08-17T08:00:00Z"},
                        "due_status": "due_today",
                    },
                    {
                        "chore": {"id": "chore-future", "name": "Windows"},
                        "pending_assignment": None,
                        "due_status": "not_due",
                    },
                ],
            }
        },
    )


def test_entities_use_native_home_assistant_platform_bases() -> None:
    assert issubclass(MitlistConnectionSensor, SensorEntity)
    assert issubclass(MitlistCountSensor, SensorEntity)
    assert issubclass(MitlistChoresTodo, TodoListEntity)


def test_nested_current_chore_is_resolved_and_only_pending_is_exposed() -> None:
    coordinator = _coordinator()
    assert _find_group_id(coordinator, "chore-1") == "group-1"
    entity = MitlistChoresTodo(coordinator, "group-1")
    assert [item.uid for item in entity.todo_items] == ["chore-1"]
    assert entity.todo_items[0].status is TodoItemStatus.NEEDS_ACTION


def test_service_dates_are_normalized_for_go_time_fields() -> None:
    coordinator = _coordinator()
    assert _action_payload(
        "reschedule_chore",
        {"chore_id": "chore-1", "due_date": "2026-08-17"},
        coordinator,
    ) == {"due_date": "2026-08-17T00:00:00Z"}
