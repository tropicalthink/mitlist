package me.mitlist.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DeliveryAndTimeTest {
    @Test
    fun mapsStatusesToOutcomes() {
        assertEquals(DeliveryOutcome.DELIVERED, DeliveryOutcome.fromStatus(200))
        assertEquals(DeliveryOutcome.DELIVERED, DeliveryOutcome.fromStatus(201))
        assertEquals(DeliveryOutcome.AUTH_FAILED, DeliveryOutcome.fromStatus(401))
        for (status in listOf(400, 403, 404, 409, 422)) {
            assertEquals("status $status", DeliveryOutcome.FAILED, DeliveryOutcome.fromStatus(status))
        }
        // The idempotency middleware's "still processing" 409 is not a rejection.
        assertEquals(DeliveryOutcome.RETRY, DeliveryOutcome.fromStatus(409, "2"))
        for (status in listOf(408, 429, 500, 502, 503)) {
            assertEquals("status $status", DeliveryOutcome.RETRY, DeliveryOutcome.fromStatus(status))
        }
    }

    @Test
    fun parsesGoTimestamps() {
        val base = Rfc3339.parseMillis("2026-10-02T09:00:00Z")!!
        assertEquals(base + 123, Rfc3339.parseMillis("2026-10-02T09:00:00.123456789Z"))
        assertEquals(base, Rfc3339.parseMillis("2026-10-02T11:00:00+02:00"))
        assertEquals(base, Rfc3339.parseMillis("2026-10-02T04:30:00-04:30"))
        // What the server sent before it normalised to whole-second UTC:
        // microseconds plus a local offset.
        assertEquals(
            Rfc3339.parseMillis("2026-10-03T21:57:45Z")!! + 643,
            Rfc3339.parseMillis("2026-10-03T23:57:45.643731+02:00"),
        )
        assertEquals(base, Rfc3339.parseMillis("2026-10-02T09:00:00.0Z"))
        assertNull(Rfc3339.parseMillis("yesterday"))
        assertEquals("2026-10-02T09:00:00Z", Rfc3339.format(base))
    }
}
