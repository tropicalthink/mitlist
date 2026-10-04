package me.mitlist.widgets

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** C1 and C2 parsing against the golden fixtures. */
class WidgetContractsTest {
    @Test
    fun parsesEveryFieldOfTheSnapshotFixture() {
        val s = Fixtures.snapshot()
        assertEquals(1, s.version)
        assertEquals(Rfc3339.parseMillis("2026-10-02T09:00:00Z"), s.generatedAt)
        assertEquals("server", s.source)
        assertEquals("6f1c2a8e-1d2b-4c3a-9e8f-0a1b2c3d4e5f", s.userId)
        assertEquals("11111111-1111-4111-8111-111111111111", s.defaults.householdId)
        assertEquals("22222222-2222-4222-8222-222222222222", s.defaults.listId)
        assertEquals(2, s.households.size)

        val flat = s.households[0]
        assertEquals("Flat 3B", flat.name)
        assertEquals(2, flat.lists.size)
        val groceries = flat.lists[0]
        assertEquals("shopping", groceries.type)
        assertEquals(3, groceries.openCount)
        assertEquals(listOf("Oat milk", "Bread", "Coffee beans \"dark\" / 1 kg"), groceries.items.map { it.name })
        assertEquals(2.0, groceries.items[0].quantity!!, 0.0)
        assertEquals("l", groceries.items[0].unit)
        assertEquals("Sam", groceries.items[0].addedByName)
        assertNull(groceries.items[1].unit)
        assertNull(groceries.items[1].addedByName)
        assertFalse(groceries.items.any { it.local })
        assertEquals(0, flat.lists[1].items.size)

        assertEquals(2, flat.chores.size)
        val bins = flat.chores[0]
        assertEquals("Bins out", bins.title)
        assertEquals("due_today", bins.dueStatus)
        assertTrue(bins.isMine)
        assertEquals("Alex", bins.nextAssigneeName)
        assertEquals(Rfc3339.parseMillis("2026-10-02T18:00:00Z"), bins.dueAt)
        assertNull(flat.chores[1].nextAssigneeName)

        assertEquals("Lasagne", flat.tonightMeal?.title)
        assertEquals("dinner", flat.tonightMeal?.slot)
        val balance = flat.balance!!
        assertEquals("EUR", balance.currency)
        assertEquals(-1200L, balance.netCents)
        assertEquals("Sam", balance.settleWithName)
        assertEquals(1200L, balance.settleCents)

        val parents = s.households[1]
        assertEquals("Mum & Dad", parents.name)
        assertTrue(parents.lists.isEmpty() && parents.chores.isEmpty())
        assertNull(parents.tonightMeal)
        assertNull(parents.balance)
    }

    @Test
    fun ignoresUnknownAndMissingFields() {
        val s = WidgetSnapshot.parse("""{"version":1,"future_field":{"x":1},"households":[{"id":"h","name":"H","lists":[{"id":"l","name":"L","items":[{"id":"i","name":"I","quantity":null}]}]}]}""")
        assertEquals(1, s.households.size)
        assertNull(s.generatedAt)
        assertNull(s.defaults.householdId)
        assertNull(s.households[0].lists[0].items[0].quantity)
        assertEquals("server", s.source)
    }

    @Test
    fun resolvesConfiguredThenDefaultHouseholdAndList() {
        val s = Fixtures.snapshot()
        assertEquals("Flat 3B", s.resolveHousehold(null)?.name)
        assertEquals("Mum & Dad", s.resolveHousehold("66666666-6666-4666-8666-666666666666")?.name)
        // A household that no longer exists falls back to the default.
        assertEquals("Flat 3B", s.resolveHousehold("gone")?.name)
        assertEquals("Groceries", s.resolveList(null, null)?.second?.name)
        assertEquals("Weekend jobs", s.resolveList(null, "22222222-2222-4222-8222-222222222223")?.second?.name)
        // A household with no lists has nothing to show.
        assertNull(s.resolveList("66666666-6666-4666-8666-666666666666", null))
    }

    @Test
    fun parsesEveryOpOfTheQueueFixture() {
        val ops = Fixtures.ops()
        assertEquals(5, ops.size)
        assertEquals(
            listOf(PendingOp.TYPE_CHECK, PendingOp.TYPE_ADD, PendingOp.TYPE_ADD, PendingOp.TYPE_COMPLETE_CHORE, PendingOp.TYPE_CHECK),
            ops.map { it.type },
        )
        assertEquals(
            listOf(OpState.PENDING, OpState.PENDING, OpState.DELIVERED, OpState.PENDING, OpState.FAILED),
            ops.map { it.state },
        )
        val check = ops[0]
        assertEquals("PATCH", check.method)
        assertEquals("/lists/22222222-2222-4222-8222-222222222222/items/33333333-3333-4333-8333-333333333331", check.path)
        assertEquals("{\"checked\":true}", check.body)
        assertEquals("33333333-3333-4333-8333-333333333331", check.itemId)
        assertEquals(1, check.attempts)
        assertEquals("offline", check.lastError)
        assertEquals("{\"name\":\"Butter\"}", ops[1].body)
        assertEquals("Butter", ops[1].name)
        assertEquals("android_quick_add", ops[1].source)
        val delivered = ops[2]
        assertNotNull(delivered.response)
        assertEquals(Rfc3339.parseMillis("2026-10-02T09:03:01Z"), delivered.deliveredAt)
        assertEquals("{}", ops[3].body)
        assertEquals("44444444-4444-4444-8444-444444444441", ops[3].choreId)
        assertEquals("404", ops[4].lastError)
    }

    @Test
    fun rejectsBlankAndMalformedLines() {
        assertNull(PendingOp.parse(""))
        assertNull(PendingOp.parse("not json"))
        assertNull(PendingOp.parse("""{"type":"list_item.check"}"""))
    }

    @Test
    fun keepsUnknownFieldsThroughAStateChange() {
        val line = """{"op_id":"x","created_at":"2026-10-02T09:00:00Z","type":"chore.complete","method":"POST","path":"/chores/c/complete","body":"{}","state":"pending","attempts":0,"from_the_future":42}"""
        val op = PendingOp.parse(line)!!.delivered(0L, "{\"ok\":true}")
        val json = JSONObject(op.toLine())
        assertEquals(42, json.getInt("from_the_future"))
        assertEquals("delivered", json.getString("state"))
        assertEquals("{}", json.getString("body"))
    }
}
