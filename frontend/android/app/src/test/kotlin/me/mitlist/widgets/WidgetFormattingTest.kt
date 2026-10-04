package me.mitlist.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class WidgetFormattingTest {
    @Test
    fun lazyListIdsStayOutOfGlancesReservedRange() {
        // Glance rejects item ids below -2^62 (found on the emulator: a quick-add
        // op id hashed into that range and the list widget failed to render).
        repeat(10_000) {
            val id = stableId(UUID.randomUUID().toString())
            assertTrue(id >= 0)
        }
        assertEquals(stableId("same"), stableId("same"))
    }

    @Test
    fun labelsQuantitiesOnlyWhenTheyAddSomething() {
        assertEquals("Bread", itemLabel(WidgetListItem("1", "Bread", 1.0)))
        assertEquals("Bread", itemLabel(WidgetListItem("1", "Bread", null)))
        assertEquals("Eggs · 6", itemLabel(WidgetListItem("1", "Eggs", 6.0)))
        assertEquals("Oat milk · 2 l", itemLabel(WidgetListItem("1", "Oat milk", 2.0, "l")))
        assertEquals("Flour · 1.5 kg", itemLabel(WidgetListItem("1", "Flour", 1.5, "kg")).replace(',', '.'))
    }
}
