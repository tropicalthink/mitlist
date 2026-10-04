package me.mitlist.widgets

import org.json.JSONArray
import org.json.JSONObject

/**
 * The widget snapshot (plans/047 contract C1). Parsed leniently: unknown
 * fields are ignored and every optional field may be missing, so a newer
 * server never breaks an older widget.
 */
data class WidgetSnapshot(
    val version: Int,
    /** Epoch millis of `generated_at`, or null when absent/unparseable. */
    val generatedAt: Long?,
    val source: String,
    val userId: String,
    val defaults: WidgetDefaults,
    val households: List<WidgetHousehold>,
) {
    fun household(id: String?): WidgetHousehold? =
        if (id == null) null else households.firstOrNull { it.id == id }

    /**
     * The household a widget shows: its configured one when it still exists,
     * otherwise the snapshot default, otherwise the first.
     */
    fun resolveHousehold(configured: String?): WidgetHousehold? =
        household(configured) ?: household(defaults.householdId) ?: households.firstOrNull()

    /** The list a widget shows, with the household that owns it. */
    fun resolveList(configuredHousehold: String?, configuredList: String?): Pair<WidgetHousehold, WidgetList>? {
        if (configuredList != null) {
            for (h in households) {
                h.lists.firstOrNull { it.id == configuredList }?.let { return h to it }
            }
        }
        val household = resolveHousehold(configuredHousehold) ?: return null
        val defaultList = if (household.id == defaults.householdId) {
            household.lists.firstOrNull { it.id == defaults.listId }
        } else {
            null
        }
        val list = defaultList
            ?: household.lists.firstOrNull { it.type == "shopping" }
            ?: household.lists.firstOrNull()
            ?: return null
        return household to list
    }

    companion object {
        fun parse(json: String): WidgetSnapshot = parse(JSONObject(json))

        fun parse(o: JSONObject): WidgetSnapshot {
            val defaults = o.optJSONObject("defaults")
            return WidgetSnapshot(
                version = o.optInt("version", 1),
                generatedAt = o.str("generated_at")?.let(Rfc3339::parseMillis),
                source = o.str("source") ?: "server",
                userId = o.str("user_id") ?: "",
                defaults = WidgetDefaults(
                    householdId = defaults?.str("household_id"),
                    listId = defaults?.str("list_id"),
                ),
                households = o.optJSONArray("households").objects().map(WidgetHousehold::parse),
            )
        }
    }
}

data class WidgetDefaults(val householdId: String?, val listId: String?)

data class WidgetHousehold(
    val id: String,
    val name: String,
    val lists: List<WidgetList>,
    val chores: List<WidgetChore>,
    val tonightMeal: TonightMeal?,
    val balance: WidgetBalance?,
) {
    companion object {
        fun parse(o: JSONObject) = WidgetHousehold(
            id = o.str("id") ?: "",
            name = o.str("name") ?: "",
            lists = o.optJSONArray("lists").objects().map(WidgetList::parse),
            chores = o.optJSONArray("chores").objects().map(WidgetChore::parse),
            tonightMeal = o.optJSONObject("tonight_meal")?.let(TonightMeal::parse),
            balance = o.optJSONObject("balance")?.let(WidgetBalance::parse),
        )
    }
}

data class WidgetList(
    val id: String,
    val name: String,
    val type: String,
    val openCount: Int,
    val items: List<WidgetListItem>,
) {
    companion object {
        fun parse(o: JSONObject) = WidgetList(
            id = o.str("id") ?: "",
            name = o.str("name") ?: "",
            type = o.str("type") ?: "",
            openCount = o.optInt("open_count", 0),
            items = o.optJSONArray("items").objects().map(WidgetListItem::parse),
        )
    }
}

data class WidgetListItem(
    val id: String,
    val name: String,
    val quantity: Double? = null,
    val unit: String? = null,
    val addedByName: String? = null,
    /** Added by a queued op that has not reached the server (C2 overlay). */
    val local: Boolean = false,
) {
    companion object {
        fun parse(o: JSONObject) = WidgetListItem(
            id = o.str("id") ?: "",
            name = o.str("name") ?: "",
            quantity = if (o.has("quantity") && !o.isNull("quantity")) o.optDouble("quantity") else null,
            unit = o.str("unit")?.takeIf { it.isNotEmpty() },
            addedByName = o.str("added_by_name")?.takeIf { it.isNotEmpty() },
            local = o.optBoolean("local", false),
        )
    }
}

data class WidgetChore(
    val id: String,
    val title: String,
    val dueAt: Long?,
    val dueStatus: String,
    val isMine: Boolean,
    val assigneeName: String?,
    val nextAssigneeName: String?,
) {
    companion object {
        fun parse(o: JSONObject) = WidgetChore(
            id = o.str("id") ?: "",
            title = o.str("title") ?: "",
            dueAt = o.str("due_at")?.let(Rfc3339::parseMillis),
            dueStatus = o.str("due_status") ?: "",
            isMine = o.optBoolean("is_mine", false),
            assigneeName = o.str("assignee_name")?.takeIf { it.isNotEmpty() },
            nextAssigneeName = o.str("next_assignee_name")?.takeIf { it.isNotEmpty() },
        )
    }
}

data class TonightMeal(val title: String, val slot: String?, val recipeId: String?) {
    companion object {
        fun parse(o: JSONObject) = TonightMeal(
            title = o.str("title") ?: "",
            slot = o.str("slot"),
            recipeId = o.str("recipe_id"),
        )
    }
}

data class WidgetBalance(
    val currency: String,
    /** Positive: others owe the user. Negative: the user owes. */
    val netCents: Long,
    val settleWithName: String?,
    /** Always positive when present. */
    val settleCents: Long?,
) {
    companion object {
        fun parse(o: JSONObject) = WidgetBalance(
            currency = o.str("currency") ?: "EUR",
            netCents = o.optLong("net_cents", 0),
            settleWithName = o.str("settle_with_name")?.takeIf { it.isNotEmpty() },
            settleCents = if (o.has("settle_cents") && !o.isNull("settle_cents")) o.optLong("settle_cents") else null,
        )
    }
}

/** A string field, or null when it is missing or JSON null (org.json would say "null"). */
internal fun JSONObject.str(key: String): String? =
    if (has(key) && !isNull(key)) optString(key) else null

internal fun JSONArray?.objects(): List<JSONObject> {
    if (this == null) return emptyList()
    val out = ArrayList<JSONObject>(length())
    for (i in 0 until length()) optJSONObject(i)?.let(out::add)
    return out
}
