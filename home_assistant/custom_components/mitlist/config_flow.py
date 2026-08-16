"""Config and options flows for Mitlist."""

from __future__ import annotations

import hashlib
from typing import Any

import voluptuous as vol
from homeassistant import config_entries
from homeassistant.const import CONF_SCAN_INTERVAL
from homeassistant.core import callback
from homeassistant.helpers import selector
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .api import MitlistApiClient, MitlistApiError, MitlistAuthError
from .const import (
    ALL_DOMAINS,
    CONF_BASE_URL,
    CONF_DOMAINS,
    CONF_ENABLE_FINANCE,
    CONF_GROUPS,
    CONF_SSE,
    CONF_TOKEN,
    CONF_VERIFY_SSL,
    DEFAULT_BASE_URL,
    DEFAULT_DOMAINS,
    DEFAULT_SCAN_INTERVAL,
    DOMAIN,
)


class MitlistConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Set up one Mitlist account (which can contain multiple households)."""

    VERSION = 1

    async def async_step_user(self, user_input: dict[str, Any] | None = None):
        errors: dict[str, str] = {}
        if user_input:
            try:
                groups = await self._validate(user_input)
            except MitlistAuthError:
                errors[CONF_TOKEN] = "invalid_auth"
            except MitlistApiError:
                errors["base"] = "cannot_connect"
            else:
                if not groups:
                    errors["base"] = "no_households"
                    return self.async_show_form(
                        step_id="user",
                        data_schema=_schema(user_input),
                        errors=errors,
                    )
                group_ids = sorted(
                    str(group["id"]) for group in groups if group.get("id")
                )
                identity = "\0".join(
                    [user_input[CONF_BASE_URL].rstrip("/").lower(), *group_ids]
                )
                unique_id = hashlib.sha256(identity.encode()).hexdigest()[:32]
                await self.async_set_unique_id(f"mitlist_{unique_id}")
                self._abort_if_unique_id_configured()
                user_input = {
                    **user_input,
                    CONF_GROUPS: group_ids,
                    CONF_DOMAINS: list(DEFAULT_DOMAINS),
                    CONF_SSE: True,
                    CONF_SCAN_INTERVAL: int(DEFAULT_SCAN_INTERVAL.total_seconds()),
                    CONF_ENABLE_FINANCE: False,
                }
                title = (
                    str(groups[0].get("name") or "Mitlist")
                    if len(groups) == 1
                    else "Mitlist"
                )
                return self.async_create_entry(title=title, data=user_input)
        return self.async_show_form(
            step_id="user", data_schema=_schema(user_input), errors=errors
        )

    async def _validate(self, values: dict[str, Any]) -> list[dict[str, Any]]:
        client = MitlistApiClient(
            async_get_clientsession(self.hass),
            values[CONF_BASE_URL],
            values[CONF_TOKEN],
            verify_ssl=values.get(CONF_VERIFY_SSL, True),
        )
        return await client.get_groups()

    async def async_step_reauth(self, user_input: dict[str, Any] | None = None):
        entry = self._get_reauth_entry()
        if user_input:
            try:
                await self._validate({**entry.data, **user_input})
            except MitlistAuthError:
                return self.async_show_form(
                    step_id="reauth",
                    data_schema=vol.Schema({vol.Required(CONF_TOKEN): str}),
                    errors={CONF_TOKEN: "invalid_auth"},
                )
            except MitlistApiError:
                return self.async_show_form(
                    step_id="reauth",
                    data_schema=vol.Schema({vol.Required(CONF_TOKEN): str}),
                    errors={"base": "cannot_connect"},
                )
            self.hass.config_entries.async_update_entry(
                entry, data={**entry.data, **user_input}
            )
            await self.hass.config_entries.async_reload(entry.entry_id)
            return self.async_abort(reason="reauth_successful")
        return self.async_show_form(
            step_id="reauth", data_schema=vol.Schema({vol.Required(CONF_TOKEN): str})
        )

    @staticmethod
    @callback
    def async_get_options_flow(config_entry):
        return MitlistOptionsFlow(config_entry)


class MitlistOptionsFlow(config_entries.OptionsFlow):
    """Tune households, domains, polling, and SSE without re-entering token."""

    def __init__(self, config_entry: config_entries.ConfigEntry) -> None:
        self.config_entry = config_entry

    async def async_step_init(self, user_input: dict[str, Any] | None = None):
        errors: dict[str, str] = {}
        if user_input is not None and user_input.get(CONF_GROUPS):
            return self.async_create_entry(title="", data=user_input)
        if user_input is not None:
            errors[CONF_GROUPS] = "select_household"
        selected_groups = self.config_entry.options.get(
            CONF_GROUPS, self.config_entry.data.get(CONF_GROUPS, [])
        )
        if user_input is not None:
            selected_groups = user_input.get(CONF_GROUPS, selected_groups)
        try:
            client = MitlistApiClient(
                async_get_clientsession(self.hass),
                self.config_entry.data[CONF_BASE_URL],
                self.config_entry.data[CONF_TOKEN],
                verify_ssl=self.config_entry.options.get(
                    CONF_VERIFY_SSL,
                    self.config_entry.data.get(CONF_VERIFY_SSL, True),
                ),
            )
            available = await client.get_groups()
            group_options = [
                {
                    "value": str(group["id"]),
                    "label": str(group.get("name") or group["id"]),
                }
                for group in available
                if group.get("id")
            ]
        except MitlistApiError:
            group_options = [
                {"value": group_id, "label": group_id} for group_id in selected_groups
            ]
        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Optional(
                        CONF_GROUPS, default=selected_groups
                    ): selector.SelectSelector(
                        selector.SelectSelectorConfig(
                            options=group_options, multiple=True
                        )
                    ),
                    vol.Optional(
                        CONF_DOMAINS,
                        default=self.config_entry.options.get(
                            CONF_DOMAINS, DEFAULT_DOMAINS
                        ),
                    ): selector.SelectSelector(
                        selector.SelectSelectorConfig(
                            options=list(ALL_DOMAINS), multiple=True
                        )
                    ),
                    vol.Optional(
                        CONF_ENABLE_FINANCE,
                        default=bool(
                            self.config_entry.options.get(CONF_ENABLE_FINANCE, False)
                        ),
                    ): bool,
                    vol.Optional(
                        CONF_SSE,
                        default=bool(self.config_entry.options.get(CONF_SSE, True)),
                    ): bool,
                    vol.Optional(
                        CONF_VERIFY_SSL,
                        default=self.config_entry.options.get(
                            CONF_VERIFY_SSL,
                            self.config_entry.data.get(CONF_VERIFY_SSL, True),
                        ),
                    ): bool,
                    vol.Optional(
                        CONF_SCAN_INTERVAL,
                        default=self.config_entry.options.get(CONF_SCAN_INTERVAL, 300),
                    ): vol.All(vol.Coerce(int), vol.Range(min=30, max=86400)),
                }
            ),
            errors=errors,
        )


def _schema(values: dict[str, Any] | None) -> vol.Schema:
    values = values or {}
    return vol.Schema(
        {
            vol.Required(
                CONF_BASE_URL, default=values.get(CONF_BASE_URL, DEFAULT_BASE_URL)
            ): str,
            vol.Required(CONF_TOKEN): str,
            vol.Optional(CONF_VERIFY_SSL, default=True): bool,
        }
    )
