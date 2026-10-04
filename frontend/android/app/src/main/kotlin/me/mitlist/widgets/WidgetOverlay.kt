package me.mitlist.widgets

import org.json.JSONObject

/**
 * What widgets show: the snapshot with the queued ops applied on top
 * (contract C2, "Overlay"), so a tick or an add shows up at once and stays
 * visible until the server state includes it.
 */
object WidgetOverlay {
    fun apply(snapshot: WidgetSnapshot, ops: List<PendingOp>): WidgetSnapshot {
        var households = snapshot.households
        for (op in ops) {
            if (!affects(op, snapshot.generatedAt)) continue
            households = when (op.type) {
                PendingOp.TYPE_CHECK -> households.mapLists(op.listId) { list ->
                    val itemId = op.itemId
                    if (list.items.none { it.id == itemId }) {
                        list
                    } else {
                        list.copy(
                            items = list.items.filterNot { it.id == itemId },
                            openCount = (list.openCount - 1).coerceAtLeast(0),
                        )
                    }
                }
                PendingOp.TYPE_ADD -> households.mapLists(op.listId) { list -> applyAdd(list, op) }
                PendingOp.TYPE_COMPLETE_CHORE -> households.map { h ->
                    if (h.chores.none { it.id == op.choreId }) h else h.copy(chores = h.chores.filterNot { it.id == op.choreId })
                }
                else -> households
            }
        }
        return snapshot.copy(households = households)
    }

    /**
     * Failed ops never apply. A delivered op stops applying once a snapshot
     * generated after its delivery was written: the server state includes it.
     */
    fun affects(op: PendingOp, snapshotGeneratedAt: Long?): Boolean = when (op.state) {
        OpState.FAILED -> false
        OpState.PENDING -> true
        OpState.DELIVERED -> {
            val deliveredAt = op.deliveredAt
            deliveredAt == null || snapshotGeneratedAt == null || snapshotGeneratedAt <= deliveredAt
        }
    }

    private fun applyAdd(list: WidgetList, op: PendingOp): WidgetList {
        return when (op.state) {
            OpState.PENDING -> list.copy(
                items = list.items + WidgetListItem(id = op.opId, name = op.name ?: "", local = true),
                openCount = list.openCount + 1,
            )
            OpState.DELIVERED -> {
                val created = op.response?.let { runCatching { JSONObject(it) }.getOrNull() } ?: return list
                val id = created.str("id") ?: return list
                if (list.items.any { it.id == id }) return list
                list.copy(
                    items = list.items + WidgetListItem(
                        id = id,
                        name = created.str("name") ?: op.name ?: "",
                        quantity = if (created.has("quantity") && !created.isNull("quantity")) created.optDouble("quantity") else null,
                        unit = created.str("unit")?.takeIf { it.isNotEmpty() },
                    ),
                    openCount = list.openCount + 1,
                )
            }
            OpState.FAILED -> list
        }
    }

    private fun List<WidgetHousehold>.mapLists(listId: String?, transform: (WidgetList) -> WidgetList) =
        map { h ->
            if (h.lists.none { it.id == listId }) h else h.copy(lists = h.lists.map { if (it.id == listId) transform(it) else it })
        }
}

/** What a delivery attempt's HTTP status means for the op (C3, C4). */
enum class DeliveryOutcome {
    /** 2xx: the server applied it (or replayed the first result). */
    DELIVERED,

    /** 400/403/404/409/422: the server will never accept it. Drop from the overlay. */
    FAILED,

    /** 401: the widget credential is dead. Keep the op for the app. */
    AUTH_FAILED,

    /** No network, 5xx, 408/429, or a 409 "still processing": try again later. */
    RETRY;

    companion object {
        /**
         * [retryAfter] is the response's Retry-After header: the idempotency
         * middleware answers 409 with it while the first request with the same
         * key is still running, which is not a rejection.
         */
        fun fromStatus(status: Int, retryAfter: String? = null): DeliveryOutcome = when {
            status in 200..299 -> DELIVERED
            status == 401 -> AUTH_FAILED
            status == 409 && !retryAfter.isNullOrEmpty() -> RETRY
            status == 400 || status == 403 || status == 404 || status == 409 || status == 422 -> FAILED
            else -> RETRY
        }
    }
}

object QueuePruning {
    /** The server forgets idempotency keys after 7 days (C2). */
    const val MAX_AGE_MILLIS = 7L * 24 * 60 * 60 * 1000

    /** Drops ops of any state created more than 7 days ago. */
    fun prune(ops: List<PendingOp>, now: Long): List<PendingOp> = ops.filter { op ->
        val created = op.createdAt ?: return@filter false
        now - created <= MAX_AGE_MILLIS
    }
}
