package me.mitlist.widgets

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class WidgetDisplayTest {
    private val utc: Calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
    private val noon = Rfc3339.parseMillis("2026-11-22T12:00:00Z")!!
    private val day = 86_400_000L

    private fun chore(id: String, dueAt: Long?, status: String = "due_soon", mine: Boolean = false) =
        WidgetChore(id, id, dueAt, status, mine, null, null)

    private fun household(chores: List<WidgetChore>, items: List<WidgetListItem> = emptyList()) =
        WidgetHousehold("h", "Home", listOf(WidgetList("l", "Groceries", "shopping", items.size, items)), chores, null, null)

    private fun snapshot(h: WidgetHousehold) = WidgetSnapshot(1, noon, "server", "u", WidgetDefaults("h", "l"), listOf(h))

    @Test
    fun bucketsFollowTheLocalDayNotTheServerStatus() {
        assertEquals(ChoreBucket.OVERDUE, WidgetDisplay.bucket(chore("a", noon - day, "due_today"), noon, utc))
        assertEquals(ChoreBucket.TODAY, WidgetDisplay.bucket(chore("b", noon + 3_600_000L, "due_soon"), noon, utc))
        assertEquals(ChoreBucket.SOON, WidgetDisplay.bucket(chore("c", noon + day), noon, utc))
        // No due time: the server's status decides.
        assertEquals(ChoreBucket.OVERDUE, WidgetDisplay.bucket(chore("d", null, "overdue"), noon, utc))
        assertEquals(ChoreBucket.TODAY, WidgetDisplay.bucket(chore("e", null, "due_today"), noon, utc))
        assertEquals(ChoreBucket.SOON, WidgetDisplay.bucket(chore("f", null, "due_soon"), noon, utc))
    }

    @Test
    fun choresGroupOverdueTodaySoonMineFirstAndCountOnlyDue() {
        val h = household(
            listOf(
                chore("soon", noon + 2 * day),
                chore("today-theirs", noon),
                chore("today-mine", noon, mine = true),
                chore("overdue", noon - 2 * day),
            ),
        )
        val rows = WidgetDisplay.choreRows(h, snapshot(h), emptySet(), noon, utc)
        assertEquals(listOf("overdue", "today-mine", "today-theirs", "soon"), rows.map { it.chore.id })
        assertEquals(3, WidgetDisplay.dueCount(rows))
        assertEquals(1, WidgetDisplay.overdueCount(rows))
        assertEquals(2, WidgetDisplay.todayCount(rows))
    }

    @Test
    fun aChoreDoneFromTheWidgetStaysMarkedDoneUntilTheNextSnapshot() {
        val raw = household(listOf(chore("a", noon), chore("b", noon)))
        val overlaid = raw.copy(chores = raw.chores.filterNot { it.id == "a" })
        val rows = WidgetDisplay.choreRows(overlaid, snapshot(raw), setOf("a"), noon, utc)
        assertEquals(listOf("a" to true, "b" to false), rows.map { it.chore.id to it.done })
        assertEquals(1, WidgetDisplay.dueCount(rows))
    }

    @Test
    fun tickedItemsStayInPlaceStruckThroughAndLocalAddsFollow() {
        val items = listOf(WidgetListItem("1", "Milk"), WidgetListItem("2", "Bread"), WidgetListItem("3", "Eggs"))
        val raw = household(emptyList(), items)
        val overlaidList = raw.lists[0].copy(
            items = listOf(items[0], items[2], WidgetListItem("op", "Tea", local = true)),
            openCount = 3,
        )
        val rows = WidgetDisplay.listRows(overlaidList, snapshot(raw), setOf("2"))
        assertEquals(listOf("1" to false, "2" to true, "3" to false, "op" to false), rows.map { it.item.id to it.ticked })
    }

    @Test
    fun withoutARawSnapshotRowsAreTheOverlaidItems() {
        val list = WidgetList("l", "G", "shopping", 1, listOf(WidgetListItem("1", "Milk")))
        assertEquals(listOf(ListRow(list.items[0], false)), WidgetDisplay.listRows(list, null, setOf("1")))
    }
}
