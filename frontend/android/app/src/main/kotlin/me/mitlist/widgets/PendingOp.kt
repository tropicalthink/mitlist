package me.mitlist.widgets

import org.json.JSONObject
import java.util.UUID

/** Delivery state of a queued op (contract C2). */
enum class OpState(val wire: String) {
    PENDING("pending"),
    DELIVERED("delivered"),
    FAILED("failed");

    companion object {
        fun fromWire(value: String?): OpState = entries.firstOrNull { it.wire == value } ?: PENDING
    }
}

/**
 * One line of the pending ops queue (contract C2). Backed by the line's own
 * JSON object so fields this build does not know survive a rewrite.
 *
 * `method`, `path` and `body` are the exact request: they are built once, when
 * the op is created, and never re-serialised. The app replays the same bytes
 * with `Idempotency-Key = op_id`, and the server's idempotency hash covers
 * them.
 */
class PendingOp private constructor(private val json: JSONObject) {
    val opId: String get() = json.str("op_id") ?: ""
    val createdAt: Long? get() = json.str("created_at")?.let(Rfc3339::parseMillis)
    val source: String get() = json.str("source") ?: ""
    val type: String get() = json.str("type") ?: ""
    val householdId: String get() = json.str("household_id") ?: ""
    val listId: String? get() = json.str("list_id")
    val itemId: String? get() = json.str("item_id")
    val choreId: String? get() = json.str("chore_id")
    val name: String? get() = json.str("name")
    val method: String get() = json.str("method") ?: "POST"
    val path: String get() = json.str("path") ?: ""
    val body: String get() = json.str("body") ?: "{}"
    val state: OpState get() = OpState.fromWire(json.str("state"))
    val attempts: Int get() = json.optInt("attempts", 0)
    val deliveredAt: Long? get() = json.str("delivered_at")?.let(Rfc3339::parseMillis)
    val response: String? get() = json.str("response")
    val lastError: String? get() = json.str("last_error")

    fun toLine(): String = json.toString()

    /** A copy marked delivered, with the response body when it is small. */
    fun delivered(now: Long, responseBody: String?): PendingOp = edit {
        put("state", OpState.DELIVERED.wire)
        put("attempts", attempts + 1)
        put("delivered_at", Rfc3339.format(now))
        remove("last_error")
        if (responseBody != null && responseBody.toByteArray(Charsets.UTF_8).size <= MAX_RESPONSE_BYTES) {
            put("response", responseBody)
        } else {
            remove("response")
        }
    }

    /** A copy marked failed for good (a 4xx the server will never accept). */
    fun failed(status: Int): PendingOp = edit {
        put("state", OpState.FAILED.wire)
        put("attempts", attempts + 1)
        put("last_error", status.toString())
    }

    /** A copy still pending after a try that did not get through. */
    fun retried(error: String): PendingOp = edit {
        put("state", OpState.PENDING.wire)
        put("attempts", attempts + 1)
        put("last_error", error)
    }

    private fun edit(block: JSONObject.() -> Unit): PendingOp =
        PendingOp(JSONObject(json.toString()).apply(block))

    override fun equals(other: Any?): Boolean = other is PendingOp && other.toLine() == toLine()

    override fun hashCode(): Int = toLine().hashCode()

    override fun toString(): String = "PendingOp(${toLine()})"

    companion object {
        const val TYPE_CHECK = "list_item.check"
        const val TYPE_ADD = "list_item.add"
        const val TYPE_COMPLETE_CHORE = "chore.complete"

        const val SOURCE_WIDGET = "android_widget"
        const val SOURCE_QUICK_ADD = "android_quick_add"

        /** Responses larger than this are not kept on the op (C2). */
        const val MAX_RESPONSE_BYTES = 16 * 1024

        /** Parses a queue line; null for blank or malformed lines. */
        fun parse(line: String): PendingOp? {
            if (line.isBlank()) return null
            return try {
                val o = JSONObject(line)
                if (o.str("op_id").isNullOrEmpty()) null else PendingOp(o)
            } catch (_: Exception) {
                null
            }
        }

        fun checkItem(householdId: String, listId: String, itemId: String, now: Long, source: String = SOURCE_WIDGET) =
            create(
                type = TYPE_CHECK,
                source = source,
                householdId = householdId,
                method = "PATCH",
                path = "/lists/$listId/items/$itemId",
                body = JSONObject().put("checked", true).toString(),
                now = now,
            ) {
                put("list_id", listId)
                put("item_id", itemId)
            }

        fun addItem(householdId: String, listId: String, name: String, now: Long, source: String) =
            create(
                type = TYPE_ADD,
                source = source,
                householdId = householdId,
                method = "POST",
                path = "/lists/$listId/items",
                body = JSONObject().put("name", name).toString(),
                now = now,
            ) {
                put("list_id", listId)
                put("name", name)
            }

        // decodeJSON rejects an empty body, so a completion sends "{}" (C2).
        fun completeChore(householdId: String, choreId: String, now: Long, source: String = SOURCE_WIDGET) =
            create(
                type = TYPE_COMPLETE_CHORE,
                source = source,
                householdId = householdId,
                method = "POST",
                path = "/chores/$choreId/complete",
                body = "{}",
                now = now,
            ) {
                put("chore_id", choreId)
            }

        private fun create(
            type: String,
            source: String,
            householdId: String,
            method: String,
            path: String,
            body: String,
            now: Long,
            extra: JSONObject.() -> Unit,
        ): PendingOp {
            val o = JSONObject()
            o.put("op_id", UUID.randomUUID().toString())
            o.put("created_at", Rfc3339.format(now))
            o.put("source", source)
            o.put("type", type)
            o.put("household_id", householdId)
            o.extra()
            o.put("method", method)
            o.put("path", path)
            o.put("body", body)
            o.put("state", OpState.PENDING.wire)
            o.put("attempts", 0)
            return PendingOp(o)
        }
    }
}
