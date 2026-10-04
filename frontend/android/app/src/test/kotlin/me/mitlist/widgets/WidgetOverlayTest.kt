package me.mitlist.widgets

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The C2 overlay rules against overlay_expected_v1.json. */
class WidgetOverlayTest {
    private val household = "11111111-1111-4111-8111-111111111111"
    private val list = "22222222-2222-4222-8222-222222222222"

    @Test
    fun matchesTheGoldenOverlay() {
        val expected = JSONObject(Fixtures.text("overlay_expected_v1.json"))
        val result = WidgetOverlay.apply(Fixtures.snapshot(), Fixtures.ops())
        val h = result.household(household)!!
        val l = h.lists.first { it.id == list }

        assertEquals(expected.getInt("list_open_count"), l.openCount)
        assertEquals(expected.getJSONArray("list_item_ids").toList(), l.items.map { it.id })
        assertEquals(expected.getJSONArray("local_item_ids").toList(), l.items.filter { it.local }.map { it.id })
        assertEquals(expected.getJSONArray("chore_ids").toList(), h.chores.map { it.id })
        // The delivered add shows under its server id and name.
        assertEquals("Eggs", l.items.last().name)
        assertFalse(l.items.last().local)
    }

    @Test
    fun deliveredOpsStopApplyingOnceANewerSnapshotIsWritten() {
        val ops = Fixtures.ops()
        val newer = Fixtures.snapshot().copy(generatedAt = Rfc3339.parseMillis("2026-10-02T10:00:00Z"))
        val l = WidgetOverlay.apply(newer, ops).household(household)!!.lists.first { it.id == list }
        // Pending ops still apply; the delivered "Eggs" add is now the server's job.
        assertFalse(l.items.any { it.id == "88888888-8888-4888-8888-888888888888" })
        assertTrue(l.items.any { it.id == "77777777-7777-4777-8777-777777777772" })
        assertEquals(3, l.openCount)
    }

    @Test
    fun deliveredAddIsNotDuplicatedWhenTheSnapshotAlreadyHasIt() {
        val snapshot = Fixtures.snapshot()
        val withEggs = snapshot.copy(
            households = snapshot.households.map { h ->
                h.copy(lists = h.lists.map { l ->
                    if (l.id != list) l else l.copy(items = l.items + WidgetListItem("88888888-8888-4888-8888-888888888888", "Eggs"), openCount = 4)
                })
            },
        )
        val l = WidgetOverlay.apply(withEggs, Fixtures.ops()).household(household)!!.lists.first { it.id == list }
        assertEquals(1, l.items.count { it.id == "88888888-8888-4888-8888-888888888888" })
    }

    @Test
    fun aCheckForAnItemNotInTheSnapshotChangesNothing() {
        val now = System.currentTimeMillis()
        val op = PendingOp.checkItem(household, list, "not-there", now)
        val l = WidgetOverlay.apply(Fixtures.snapshot(), listOf(op)).household(household)!!.lists.first { it.id == list }
        assertEquals(3, l.openCount)
        assertEquals(3, l.items.size)
    }

    @Test
    fun failedOpsNeverApply() {
        val now = System.currentTimeMillis()
        val failed = PendingOp.checkItem(household, list, "33333333-3333-4333-8333-333333333331", now).failed(404)
        assertFalse(WidgetOverlay.affects(failed, null))
        val l = WidgetOverlay.apply(Fixtures.snapshot(), listOf(failed)).household(household)!!.lists.first { it.id == list }
        assertEquals(3, l.items.size)
    }

    private fun org.json.JSONArray.toList(): List<String> = (0 until length()).map { getString(it) }
}
