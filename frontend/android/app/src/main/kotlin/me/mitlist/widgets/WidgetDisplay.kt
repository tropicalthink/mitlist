package me.mitlist.widgets

import java.util.Calendar

/**
 * What widgets draw, worked out from the model without any Glance or
 * Android types, so the JVM tests cover it.
 */

/** A list row: an open item, or one ticked from the widget and not yet gone from the server's snapshot. */
data class ListRow(val item: WidgetListItem, val ticked: Boolean)

/** A chore row: due, or completed from the widget and waiting for the next snapshot. */
data class ChoreRow(val chore: WidgetChore, val bucket: ChoreBucket, val done: Boolean)

/**
 * When a chore falls, in the device's time zone. Both platforms agree: a
 * chore is "due" when it is [OVERDUE] or [TODAY]; [SOON] is shown below them
 * but never counted as due.
 */
enum class ChoreBucket { OVERDUE, TODAY, SOON }

object WidgetDisplay {
    /**
     * The overlaid list's rows, with items ticked from the widget kept in
     * place (struck through) instead of vanishing, until a snapshot taken
     * after the tick drops them.
     */
    fun listRows(list: WidgetList, raw: WidgetSnapshot?, tickedItemIds: Set<String>): List<ListRow> {
        val rawList = raw?.households?.asSequence()?.flatMap { it.lists.asSequence() }?.firstOrNull { it.id == list.id }
            ?: return list.items.map { ListRow(it, false) }
        val open = list.items.associateBy { it.id }
        val rows = rawList.items.mapNotNull { item ->
            when {
                open.containsKey(item.id) -> ListRow(open.getValue(item.id), false)
                item.id in tickedItemIds -> ListRow(item, true)
                else -> null
            }
        }
        val rawIds = rawList.items.mapTo(HashSet()) { it.id }
        return rows + list.items.filter { it.id !in rawIds }.map { ListRow(it, false) }
    }

    fun bucket(chore: WidgetChore, now: Long, calendar: Calendar = Calendar.getInstance()): ChoreBucket {
        val due = chore.dueAt ?: return when (chore.dueStatus) {
            "overdue" -> ChoreBucket.OVERDUE
            "due_today" -> ChoreBucket.TODAY
            else -> ChoreBucket.SOON
        }
        val today = startOfDay(now, calendar)
        val dueDay = startOfDay(due, calendar)
        return when {
            dueDay < today -> ChoreBucket.OVERDUE
            dueDay == today -> ChoreBucket.TODAY
            else -> ChoreBucket.SOON
        }
    }

    /**
     * The household's chores grouped Overdue, Today, Soon, mine first in each
     * group, otherwise in server order (which sorts by due time). Chores done
     * from the widget stay, marked done, until the next snapshot.
     */
    fun choreRows(
        household: WidgetHousehold,
        raw: WidgetSnapshot?,
        doneChoreIds: Set<String>,
        now: Long,
        calendar: Calendar = Calendar.getInstance(),
    ): List<ChoreRow> {
        val rawHousehold = raw?.household(household.id)
        val open = household.chores.associateBy { it.id }
        val source = rawHousehold?.chores ?: household.chores
        val rows = source.mapNotNull { chore ->
            when {
                open.containsKey(chore.id) -> open.getValue(chore.id) to false
                chore.id in doneChoreIds -> chore to true
                else -> null
            }
        }.map { (chore, done) -> ChoreRow(chore, bucket(chore, now, calendar), done) }
        return rows.sortedWith(compareBy<ChoreRow> { it.bucket.ordinal }.thenBy { if (it.chore.isMine) 0 else 1 })
    }

    /** Overdue plus today, not counting chores already done: what an "N due" label counts. */
    fun dueCount(rows: List<ChoreRow>): Int = rows.count { !it.done && it.bucket != ChoreBucket.SOON }

    fun overdueCount(rows: List<ChoreRow>): Int = rows.count { !it.done && it.bucket == ChoreBucket.OVERDUE }

    fun todayCount(rows: List<ChoreRow>): Int = rows.count { !it.done && it.bucket == ChoreBucket.TODAY }

    private fun startOfDay(millis: Long, calendar: Calendar): Long {
        val cal = calendar.clone() as Calendar
        cal.timeInMillis = millis
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}
