"""Constants for the mitlist Home Assistant integration."""

from __future__ import annotations

from datetime import timedelta

DOMAIN = "mitlist"
NAME = "mitlist"
MANUFACTURER = "mitlist"
API_PREFIX = "/api/v1"
DEFAULT_SCAN_INTERVAL = timedelta(minutes=5)
DEFAULT_SSE_RECONNECT = timedelta(seconds=30)
DEFAULT_TIMEOUT = 30
DEFAULT_BASE_URL = "https://api.mitlist.me"
CONF_BASE_URL = "base_url"
CONF_TOKEN = "token"
CONF_GROUPS = "groups"
CONF_DOMAINS = "domains"
CONF_ENABLE_FINANCE = "enable_finance"
CONF_SCAN_INTERVAL = "scan_interval"
CONF_MEMBER_ID = "member_id"
CONF_SSE = "enable_sse"
CONF_VERIFY_SSL = "verify_ssl"

PLATFORMS = ("todo", "calendar", "sensor", "binary_sensor", "event")

DOMAIN_LISTS = "lists"
DOMAIN_CHORES = "chores"
DOMAIN_CALENDAR = "calendar"
DOMAIN_RECIPES = "recipes"
DOMAIN_FINANCE = "finance"
DOMAIN_PINWALL = "pinwall"
DOMAIN_NOTIFICATIONS = "notifications"
DOMAIN_GROCERIES = "groceries"
DOMAIN_ACTIVITY = "activity"

DEFAULT_DOMAINS = (
    DOMAIN_LISTS,
    DOMAIN_CHORES,
    DOMAIN_CALENDAR,
    DOMAIN_RECIPES,
    DOMAIN_GROCERIES,
    DOMAIN_PINWALL,
    DOMAIN_NOTIFICATIONS,
    DOMAIN_ACTIVITY,
)
ALL_DOMAINS = DEFAULT_DOMAINS + (DOMAIN_FINANCE,)

SERVICE_CREATE_LIST = "create_list"
SERVICE_ADD_ITEM = "add_item"
SERVICE_COMPLETE_CHORE = "complete_chore"
SERVICE_SKIP_CHORE = "skip_chore"
SERVICE_RESCHEDULE_CHORE = "reschedule_chore"
SERVICE_UNDO_CHORE = "undo_chore"
SERVICE_ADD_CHORE_SUPPLIES = "add_chore_supplies"
SERVICE_GENERATE_SHOPPING_LIST = "generate_shopping_list"
SERVICE_ADD_RECIPE_TO_LIST = "add_recipe_to_list"
SERVICE_ADD_MISSING_INGREDIENTS = "add_missing_ingredients"
SERVICE_CREATE_EXPENSE = "create_expense"
SERVICE_CONFIRM_SETTLEMENT = "confirm_settlement"
SERVICE_DECLINE_SETTLEMENT = "decline_settlement"
SERVICE_MARK_NOTIFICATION_READ = "mark_notification_read"
SERVICE_MARK_ALL_NOTIFICATIONS_READ = "mark_all_notifications_read"
SERVICE_REFRESH = "refresh"

EVENT_UPDATE = "mitlist_update"
EVENT_CONNECTION = "mitlist_connection"

DATA_CLIENT = "client"
DATA_COORDINATOR = "coordinator"
