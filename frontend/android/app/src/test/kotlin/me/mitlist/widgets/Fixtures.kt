package me.mitlist.widgets

import java.io.File

/** The shared golden fixtures in contracts/widgets (see its README). */
object Fixtures {
    private val dir: File by lazy {
        val configured = System.getProperty("mitlist.contracts.dir")
        val candidates = listOfNotNull(
            configured?.let(::File),
            File("../../contracts/widgets"),
            File("../../../contracts/widgets"),
        )
        candidates.firstOrNull { File(it, "snapshot_v1.json").exists() }
            ?: error("contracts/widgets not found (looked in $candidates)")
    }

    fun text(name: String): String = File(dir, name).readText(Charsets.UTF_8)

    fun snapshot(): WidgetSnapshot = WidgetSnapshot.parse(text("snapshot_v1.json"))

    fun ops(): List<PendingOp> = text("pending_ops_v1.jsonl").lines().mapNotNull(PendingOp::parse)
}
