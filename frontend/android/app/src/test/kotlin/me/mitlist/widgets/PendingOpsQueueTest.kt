package me.mitlist.widgets

import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files
import kotlin.concurrent.thread

class PendingOpsQueueTest {
    private val dir: File = Files.createTempDirectory("widgets").toFile()
    private val queue = PendingOpsQueue(dir)
    private val now = Rfc3339.parseMillis("2026-10-02T12:00:00Z")!!

    @After
    fun cleanUp() {
        dir.deleteRecursively()
    }

    @Test
    fun appendsReplacesAndRemovesInOrder() {
        val a = PendingOp.checkItem("h", "l", "i1", now)
        val b = PendingOp.addItem("h", "l", "Milk", now, PendingOp.SOURCE_QUICK_ADD)
        val c = PendingOp.completeChore("h", "c1", now)
        queue.append(a)
        queue.append(b)
        queue.append(c)
        assertEquals(listOf(a.opId, b.opId, c.opId), queue.readAll().map { it.opId })

        queue.replace(b.delivered(now, "{\"id\":\"srv\"}"))
        assertEquals(OpState.DELIVERED, queue.readAll()[1].state)

        queue.remove(listOf(a.opId, c.opId))
        assertEquals(listOf(b.opId), queue.readAll().map { it.opId })
        assertEquals(1, queue.readLines().size)
        assertTrue(File(dir, PendingOpsQueue.FILE_NAME).readText().endsWith("\n"))
    }

    @Test
    fun readsTheFixtureFileAsIs() {
        File(dir, PendingOpsQueue.FILE_NAME).writeText(Fixtures.text("pending_ops_v1.jsonl"))
        assertEquals(5, queue.readAll().size)
        assertEquals(5, queue.readLines().size)
    }

    @Test
    fun prunesOpsOlderThanSevenDays() {
        val old = PendingOp.checkItem("h", "l", "old", now - QueuePruning.MAX_AGE_MILLIS - 1)
        val fresh = PendingOp.checkItem("h", "l", "fresh", now - QueuePruning.MAX_AGE_MILLIS + 60_000)
        val oldDelivered = PendingOp.completeChore("h", "c", now - 8L * 86_400_000).delivered(now, null)
        queue.append(old)
        queue.append(fresh)
        queue.append(oldDelivered)
        queue.prune(now)
        assertEquals(listOf(fresh.opId), queue.readAll().map { it.opId })
    }

    @Test
    fun concurrentAppendsAreAllKept() {
        val threads = (0 until 8).map { t ->
            thread {
                repeat(25) { i -> queue.append(PendingOp.checkItem("h", "l", "i$t-$i", now)) }
            }
        }
        threads.forEach { it.join() }
        assertEquals(200, queue.readAll().size)
        assertEquals(200, queue.readAll().map { it.opId }.toSet().size)
    }

    @Test
    fun opFactoriesBuildTheExactRequests() {
        val check = PendingOp.checkItem("h", "l1", "i1", now)
        assertEquals("PATCH", check.method)
        assertEquals("/lists/l1/items/i1", check.path)
        assertEquals("{\"checked\":true}", check.body)
        assertEquals("2026-10-02T12:00:00Z", JSONObject(check.toLine()).getString("created_at"))
        assertEquals(OpState.PENDING, check.state)
        assertEquals(PendingOp.SOURCE_WIDGET, check.source)

        val tricky = "Café \"bio\" / 1½ kg"
        val add = PendingOp.addItem("h", "l1", tricky, now, PendingOp.SOURCE_QUICK_ADD)
        assertEquals("POST", add.method)
        assertEquals("/lists/l1/items", add.path)
        assertEquals(tricky, JSONObject(add.body).getString("name"))
        // The body survives a round trip through the queue line byte for byte.
        assertEquals(add.body, PendingOp.parse(add.toLine())!!.body)

        val done = PendingOp.completeChore("h", "c1", now)
        assertEquals("/chores/c1/complete", done.path)
        assertEquals("{}", done.body)
    }

    @Test
    fun responseBodiesOverTheCapAreNotStored() {
        val op = PendingOp.addItem("h", "l", "x", now, PendingOp.SOURCE_WIDGET)
        val big = "{\"id\":\"" + "a".repeat(PendingOp.MAX_RESPONSE_BYTES) + "\"}"
        assertEquals(null, op.delivered(now, big).response)
        assertEquals("{\"id\":\"s\"}", op.delivered(now, "{\"id\":\"s\"}").response)
    }
}
