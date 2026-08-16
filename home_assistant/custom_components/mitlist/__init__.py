"""Mitlist Home Assistant integration."""

from __future__ import annotations

import logging
from typing import Any

import voluptuous as vol
from homeassistant.config_entries import ConfigEntryState
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.exceptions import (
    ConfigEntryAuthFailed,
    ConfigEntryNotReady,
    HomeAssistantError,
)
from homeassistant.helpers import aiohttp_client
from homeassistant.helpers import config_validation as cv

from .api import MitlistApiClient, MitlistApiError
from .const import (
    CONF_BASE_URL,
    CONF_TOKEN,
    DOMAIN,
    PLATFORMS,
    SERVICE_ADD_CHORE_SUPPLIES,
    SERVICE_ADD_ITEM,
    SERVICE_ADD_MISSING_INGREDIENTS,
    SERVICE_ADD_RECIPE_TO_LIST,
    SERVICE_COMPLETE_CHORE,
    SERVICE_CONFIRM_SETTLEMENT,
    SERVICE_CREATE_EXPENSE,
    SERVICE_CREATE_LIST,
    SERVICE_DECLINE_SETTLEMENT,
    SERVICE_GENERATE_SHOPPING_LIST,
    SERVICE_MARK_ALL_NOTIFICATIONS_READ,
    SERVICE_MARK_NOTIFICATION_READ,
    SERVICE_REFRESH,
    SERVICE_RESCHEDULE_CHORE,
    SERVICE_SKIP_CHORE,
    SERVICE_UNDO_CHORE,
)
from .coordinator import (
    MitlistConfigEntry,
    MitlistDataUpdateCoordinator,
    MitlistRuntimeData,
)

_LOGGER = logging.getLogger(__name__)
_PLATFORM_MAP = {name: Platform(name) for name in PLATFORMS}


async def async_setup(hass: HomeAssistant, config: dict[str, Any]) -> bool:
    """Set up Mitlist services (configuration is entry-based)."""
    _register_services(hass)
    return True


async def async_setup_entry(hass: HomeAssistant, entry: MitlistConfigEntry) -> bool:
    client = MitlistApiClient(
        aiohttp_client.async_get_clientsession(hass),
        entry.options.get(CONF_BASE_URL, entry.data[CONF_BASE_URL]),
        entry.options.get(CONF_TOKEN, entry.data[CONF_TOKEN]),
        verify_ssl=entry.options.get("verify_ssl", entry.data.get("verify_ssl", True)),
    )
    coordinator = MitlistDataUpdateCoordinator(hass, client, entry)
    try:
        await coordinator.async_config_entry_first_refresh()
    except ConfigEntryAuthFailed:
        await coordinator.async_shutdown()
        raise
    except MitlistApiError as err:
        await coordinator.async_shutdown()
        raise ConfigEntryNotReady(str(err)) from err
    entry.runtime_data = MitlistRuntimeData(client=client, coordinator=coordinator)
    entry.async_on_unload(entry.add_update_listener(_async_options_updated))
    await hass.config_entries.async_forward_entry_setups(
        entry, list(_PLATFORM_MAP.values())
    )
    return True


async def async_unload_entry(hass: HomeAssistant, entry: MitlistConfigEntry) -> bool:
    unloaded = await hass.config_entries.async_unload_platforms(
        entry, list(_PLATFORM_MAP.values())
    )
    if unloaded:
        await entry.runtime_data.coordinator.async_shutdown()
    return unloaded


async def _async_options_updated(
    hass: HomeAssistant, entry: MitlistConfigEntry
) -> None:
    await hass.config_entries.async_reload(entry.entry_id)


def _register_services(hass: HomeAssistant) -> None:
    if hass.services.has_service(DOMAIN, SERVICE_CREATE_LIST):
        return
    service_defs: dict[str, vol.Schema] = {
        SERVICE_CREATE_LIST: vol.Schema(
            {
                vol.Required("group_id"): cv.string,
                vol.Required("name"): cv.string,
                vol.Optional("type", default="shopping"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_ADD_ITEM: vol.Schema(
            {
                vol.Required("list_id"): cv.string,
                vol.Required("name"): cv.string,
                vol.Optional("quantity"): vol.Coerce(float),
                vol.Optional("group_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_COMPLETE_CHORE: _chore_schema(),
        SERVICE_SKIP_CHORE: _chore_schema(),
        SERVICE_UNDO_CHORE: _chore_schema(),
        SERVICE_RESCHEDULE_CHORE: vol.Schema(
            {
                vol.Required("chore_id"): cv.string,
                vol.Required("due_date"): cv.string,
                vol.Optional("group_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_ADD_CHORE_SUPPLIES: vol.Schema(
            {
                vol.Required("chore_id"): cv.string,
                vol.Required("list_id"): cv.string,
                vol.Optional("group_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_GENERATE_SHOPPING_LIST: vol.Schema(
            {
                vol.Required("group_id"): cv.string,
                vol.Required("from"): cv.string,
                vol.Required("to"): cv.string,
                vol.Optional("list_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_ADD_RECIPE_TO_LIST: vol.Schema(
            {
                vol.Required("recipe_id"): cv.string,
                vol.Required("list_id"): cv.string,
                vol.Optional("group_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_ADD_MISSING_INGREDIENTS: vol.Schema(
            {
                vol.Required("recipe_id"): cv.string,
                vol.Required("list_id"): cv.string,
                vol.Optional("group_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_CREATE_EXPENSE: vol.Schema(
            {
                vol.Required("group_id"): cv.string,
                vol.Required("payer_id"): cv.string,
                vol.Required("amount_cents"): vol.Coerce(int),
                vol.Required("description"): cv.string,
                vol.Required("currency"): cv.string,
                vol.Required("date"): cv.string,
                vol.Required("split_user_ids"): vol.All(cv.ensure_list, [cv.string]),
                vol.Optional("category", default="other"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_CONFIRM_SETTLEMENT: vol.Schema(
            {
                vol.Required("group_id"): cv.string,
                vol.Required("settlement_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_DECLINE_SETTLEMENT: vol.Schema(
            {
                vol.Required("group_id"): cv.string,
                vol.Required("settlement_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_MARK_NOTIFICATION_READ: vol.Schema(
            {
                vol.Required("group_id"): cv.string,
                vol.Required("notification_id"): cv.string,
                vol.Optional("entry_id"): cv.string,
            }
        ),
        SERVICE_MARK_ALL_NOTIFICATIONS_READ: vol.Schema(
            {vol.Required("group_id"): cv.string, vol.Optional("entry_id"): cv.string}
        ),
        SERVICE_REFRESH: vol.Schema({vol.Optional("entry_id"): cv.string}),
    }
    for service, schema in service_defs.items():
        hass.services.async_register(
            DOMAIN, service, _make_service_handler(hass, service), schema
        )


def _chore_schema() -> vol.Schema:
    return vol.Schema(
        {
            vol.Required("chore_id"): cv.string,
            vol.Optional("group_id"): cv.string,
            vol.Optional("entry_id"): cv.string,
        }
    )


def _make_service_handler(hass: HomeAssistant, service: str):
    async def handle(call: ServiceCall) -> None:
        payload = {
            key: value for key, value in call.data.items() if not key.startswith("_")
        }
        runtimes = [
            (entry.entry_id, entry.runtime_data)
            for entry in hass.config_entries.async_entries(DOMAIN)
            if entry.state is ConfigEntryState.LOADED
        ]
        entry_id = payload.get("entry_id")
        if entry_id:
            runtimes = [runtime for runtime in runtimes if runtime[0] == entry_id]
        else:
            runtimes = [
                (key, value)
                for key, value in runtimes
                if _runtime_matches(value.coordinator, payload)
            ]
        if not runtimes:
            raise HomeAssistantError(
                "No Mitlist household matches this service request"
            )
        for _, runtime in runtimes:
            coordinator = runtime.coordinator
            try:
                if service == SERVICE_REFRESH:
                    await coordinator.async_request_refresh()
                elif service == SERVICE_CREATE_LIST:
                    await runtime.client.create_list(
                        payload["group_id"],
                        payload["name"],
                        payload.get("type", "shopping"),
                    )
                elif service == SERVICE_ADD_ITEM:
                    group_id = payload.get("group_id") or _find_group_id(
                        coordinator, payload["list_id"]
                    )
                    fields = {
                        key: value
                        for key, value in payload.items()
                        if key not in {"list_id", "name", "group_id", "entry_id"}
                    }
                    await runtime.client.add_item(
                        payload["list_id"], payload["name"], group_id=group_id, **fields
                    )
                elif service.startswith(("complete_", "skip_", "undo_")):
                    await runtime.client.chore_action(
                        payload["chore_id"],
                        service.removesuffix("_chore"),
                        group_id=payload.get("group_id")
                        or _find_group_id(coordinator, payload["chore_id"]),
                    )
                else:
                    group_id = payload.get("group_id") or _find_group_id(
                        coordinator,
                        str(
                            payload.get("list_id")
                            or payload.get("chore_id")
                            or payload.get("recipe_id")
                            or payload.get("meal_plan_id")
                            or ""
                        ),
                    )
                    await runtime.client.action(
                        _service_path(service, payload),
                        _action_payload(service, payload, coordinator),
                        method=_service_method(service),
                        group_id=group_id,
                    )
            except MitlistApiError as err:
                raise HomeAssistantError(
                    f"Mitlist service {service} failed: {err}"
                ) from err
        for _, runtime in runtimes:
            await runtime.coordinator.async_request_refresh()

    return handle


def _runtime_matches(
    coordinator: MitlistDataUpdateCoordinator, payload: dict[str, Any]
) -> bool:
    group_id = payload.get("group_id")
    if group_id:
        return group_id in coordinator.group_ids
    for key in ("list_id", "chore_id", "meal_plan_id", "recipe_id"):
        if payload.get(key) and _find_group_id(coordinator, str(payload[key])):
            return True
    return not any(
        payload.get(key)
        for key in ("group_id", "list_id", "chore_id", "meal_plan_id", "recipe_id")
    )


def _find_group_id(
    coordinator: MitlistDataUpdateCoordinator, entity_id: str
) -> str | None:
    for group_id in coordinator.group_ids:
        data = coordinator.data.get(group_id, {}) if coordinator.data else {}
        for domain in ("lists", "chores", "meal_plans", "recipes"):
            if any(
                str(item.get("id") or item.get("chore", {}).get("id")) == str(entity_id)
                for item in data.get(domain, [])
            ):
                return group_id
    return None


def _service_path(service: str, payload: dict[str, Any]) -> str:
    mapping = {
        SERVICE_RESCHEDULE_CHORE: f"chores/{payload['chore_id']}/pending",
        SERVICE_ADD_CHORE_SUPPLIES: f"chores/{payload['chore_id']}/add-supplies-to-list",
        SERVICE_GENERATE_SHOPPING_LIST: "meal-plans/generate-shopping-list",
        SERVICE_ADD_RECIPE_TO_LIST: f"recipes/{payload['recipe_id']}/add-to-list",
        SERVICE_ADD_MISSING_INGREDIENTS: f"recipes/{payload['recipe_id']}/add-missing-to-list",
        SERVICE_CREATE_EXPENSE: "expenses",
        SERVICE_CONFIRM_SETTLEMENT: f"finance/settlements/{payload['settlement_id']}/confirm",
        SERVICE_DECLINE_SETTLEMENT: f"finance/settlements/{payload['settlement_id']}/decline",
        SERVICE_MARK_NOTIFICATION_READ: f"notifications/{payload['notification_id']}/read",
        SERVICE_MARK_ALL_NOTIFICATIONS_READ: "notifications/read-all",
    }
    return mapping.get(service, service)


def _service_method(service: str) -> str:
    return (
        "PATCH"
        if service
        in {
            SERVICE_RESCHEDULE_CHORE,
            SERVICE_MARK_NOTIFICATION_READ,
            SERVICE_MARK_ALL_NOTIFICATIONS_READ,
        }
        else "POST"
    )


def _action_payload(
    service: str, payload: dict[str, Any], coordinator: MitlistDataUpdateCoordinator
) -> dict[str, Any]:
    group_id = payload.get("group_id") or _find_group_id(
        coordinator,
        str(
            payload.get("list_id")
            or payload.get("chore_id")
            or payload.get("meal_plan_id")
            or payload.get("recipe_id")
            or ""
        ),
    )
    if service == SERVICE_RESCHEDULE_CHORE:
        return {"due_date": _rfc3339(payload["due_date"])}
    if service == SERVICE_ADD_CHORE_SUPPLIES:
        return {"list_id": payload["list_id"]}
    if service in {SERVICE_ADD_RECIPE_TO_LIST, SERVICE_ADD_MISSING_INGREDIENTS}:
        return {"list_id": payload["list_id"]}
    if service == SERVICE_GENERATE_SHOPPING_LIST:
        return {
            key: payload[key]
            for key in ("group_id", "from", "to", "list_id")
            if key in payload
        }
    if service == SERVICE_CREATE_EXPENSE:
        amount = payload["amount_cents"]
        return {
            "group_id": group_id,
            "payer_id": payload["payer_id"],
            "amount": amount,
            "base_amount": amount,
            "fx_rate": 1,
            "description": payload["description"],
            "category": payload["category"],
            "currency": payload["currency"],
            "date": _rfc3339(payload["date"]),
            "split_user_ids": payload["split_user_ids"],
            "split_mode": "equal",
        }
    if service in {
        SERVICE_MARK_NOTIFICATION_READ,
        SERVICE_MARK_ALL_NOTIFICATIONS_READ,
        SERVICE_CONFIRM_SETTLEMENT,
        SERVICE_DECLINE_SETTLEMENT,
    }:
        return {}
    return {
        key: value
        for key, value in payload.items()
        if key
        not in {
            "entry_id",
            "group_id",
            "chore_id",
            "recipe_id",
            "meal_plan_id",
            "settlement_id",
            "notification_id",
        }
    }


def _rfc3339(value: str) -> str:
    """Normalize Home Assistant date selectors for Go time.Time fields."""
    return value if "T" in value else f"{value}T00:00:00Z"
