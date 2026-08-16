"""Mitlist shopping and task lists as Home Assistant todo entities."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from homeassistant.components.todo import (
    TodoItem,
    TodoItemStatus,
    TodoListEntity,
    TodoListEntityFeature,
)
from homeassistant.core import HomeAssistant
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
    known: dict[str, TodoListEntity] = {}

    def discover() -> None:
        entities: list[TodoListEntity] = []
        active: set[str] = set()
        for group_id in coordinator.group_ids:
            chore_key = f"chores:{group_id}"
            active.add(chore_key)
            if chore_key not in known:
                entity = MitlistChoresTodo(coordinator, group_id)
                known[chore_key] = entity
                entities.append(entity)
            for list_item in group_data(coordinator, group_id).get("lists", []):
                list_id = str(list_item.get("id") or "")
                key = f"list:{group_id}:{list_id}"
                if list_id:
                    active.add(key)
                if list_id and key not in known:
                    entity = MitlistTodoList(coordinator, group_id, list_item)
                    known[key] = entity
                    entities.append(entity)
        for key in set(known) - active:
            entity = known.pop(key)
            hass.async_create_task(entity.async_remove())
        if entities:
            async_add_entities(entities)

    discover()
    entry.async_on_unload(coordinator.async_add_listener(discover))


class MitlistTodoList(CoordinatorEntity[MitlistDataUpdateCoordinator], TodoListEntity):
    """One Mitlist list, including its item mutation operations."""

    _attr_has_entity_name = True
    _attr_supported_features = (
        TodoListEntityFeature.CREATE_TODO_ITEM
        | TodoListEntityFeature.UPDATE_TODO_ITEM
        | TodoListEntityFeature.DELETE_TODO_ITEM
        | TodoListEntityFeature.SET_DESCRIPTION_ON_ITEM
    )

    def __init__(
        self,
        coordinator: MitlistDataUpdateCoordinator,
        group_id: str,
        list_item: dict[str, Any],
    ) -> None:
        super().__init__(coordinator)
        self.group_id = group_id
        self.list_id = str(list_item["id"])
        self._attr_unique_id = (
            f"{DOMAIN}_{coordinator.entry.entry_id}_{group_id}_list_{self.list_id}"
        )

    @property
    def name(self) -> str:
        for item in group_data(self.coordinator, self.group_id).get("lists", []):
            if str(item.get("id")) == self.list_id:
                return item_name(item, "List")
        return "List"

    @property
    def todo_items(self) -> list[TodoItem]:
        for item in group_data(self.coordinator, self.group_id).get("lists", []):
            if str(item.get("id")) == self.list_id:
                return [
                    TodoItem(
                        uid=str(value["id"]),
                        summary=item_name(value, "Item"),
                        status=(
                            TodoItemStatus.COMPLETED
                            if value.get("checked", False)
                            else TodoItemStatus.NEEDS_ACTION
                        ),
                        description=_list_item_description(value),
                    )
                    for value in item.get("items", [])
                    if value.get("id")
                ]
        return []

    async def async_create_todo_item(self, item: TodoItem) -> None:
        await self.coordinator.client.add_item(
            self.list_id,
            item.summary or "Item",
            group_id=self.group_id,
            note=item.description or "",
        )
        await self.coordinator.async_request_refresh()

    async def async_update_todo_item(self, item: TodoItem) -> None:
        completed = item.status == TodoItemStatus.COMPLETED
        await self.coordinator.client.update_item(
            self.list_id,
            str(item.uid),
            {
                "name": item.summary or "Item",
                "checked": completed,
                "note": item.description or "",
            },
            group_id=self.group_id,
        )
        await self.coordinator.async_request_refresh()

    async def async_delete_todo_items(self, uids: list[str]) -> None:
        for uid in uids:
            await self.coordinator.client.delete_item(
                self.list_id, str(uid), group_id=self.group_id
            )
        await self.coordinator.async_request_refresh()

    @property
    def device_info(self):
        return group_device_info(self.coordinator, self.group_id)


class MitlistChoresTodo(
    CoordinatorEntity[MitlistDataUpdateCoordinator], TodoListEntity
):
    """Expose due chores in the same native todo UI as shopping lists."""

    _attr_has_entity_name = True
    _attr_supported_features = TodoListEntityFeature.UPDATE_TODO_ITEM

    def __init__(
        self, coordinator: MitlistDataUpdateCoordinator, group_id: str
    ) -> None:
        super().__init__(coordinator)
        self.group_id = group_id
        self._attr_unique_id = (
            f"{DOMAIN}_{coordinator.entry.entry_id}_{group_id}_chores_todo"
        )
        self._attr_name = "Chores"

    @property
    def todo_items(self) -> list[TodoItem]:
        items: list[TodoItem] = []
        for current in group_data(self.coordinator, self.group_id).get("chores", []):
            chore = current.get("chore", current)
            chore_id = chore.get("id")
            assignment = current.get("pending_assignment")
            if not chore_id or not assignment:
                continue
            items.append(
                TodoItem(
                    uid=str(chore_id),
                    summary=item_name(chore, "Chore"),
                    status=TodoItemStatus.NEEDS_ACTION,
                    due=_parse_datetime(assignment.get("due_date")),
                    description=chore.get("description"),
                )
            )
        return items

    async def async_update_todo_item(self, item: TodoItem) -> None:
        raw = next(
            (
                current
                for current in group_data(self.coordinator, self.group_id).get(
                    "chores", []
                )
                if str(current.get("chore", current).get("id")) == str(item.uid)
            ),
            None,
        )
        if raw is not None:
            action = "complete" if item.status == TodoItemStatus.COMPLETED else "undo"
            await self.coordinator.client.chore_action(
                str(item.uid), action, group_id=self.group_id
            )
            await self.coordinator.async_request_refresh()

    @property
    def device_info(self):
        return group_device_info(self.coordinator, self.group_id)


def _list_item_description(item: dict[str, Any]) -> str | None:
    parts: list[str] = []
    quantity = item.get("quantity")
    unit = item.get("unit")
    if quantity and quantity != 1:
        parts.append(f"{quantity:g} {unit or ''}".strip())
    if note := item.get("note"):
        parts.append(str(note))
    return " · ".join(parts) or None


def _parse_datetime(value: Any) -> datetime | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
