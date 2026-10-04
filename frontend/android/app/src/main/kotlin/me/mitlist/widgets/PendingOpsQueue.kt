package me.mitlist.widgets

import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * The pending ops queue file (contract C2): JSON lines, oldest first, every
 * read-modify-write under a process-wide lock plus a file lock, and every
 * write a whole-file atomic replace. Widget callbacks, the quick-add
 * activity, the sync worker and the method channel all use it at once.
 */
class PendingOpsQueue(private val dir: File) {
    private val file get() = File(dir, FILE_NAME)
    private val lockFile get() = File(dir, LOCK_NAME)

    /** Every parseable op, oldest first. */
    fun readAll(): List<PendingOp> = locked { read() }

    /** The raw, non-blank lines, for the app's importer. */
    fun readLines(): List<String> = locked {
        if (!file.exists()) emptyList() else file.readLines(Charsets.UTF_8).filter { it.isNotBlank() }
    }

    fun append(op: PendingOp) = mutate { it.add(op) }

    /** Replaces the op with the same id, if it is still queued. */
    fun replace(op: PendingOp) = mutate { ops ->
        val index = ops.indexOfFirst { it.opId == op.opId }
        if (index >= 0) ops[index] = op
    }

    fun remove(opIds: Collection<String>) {
        if (opIds.isEmpty()) return
        val ids = opIds.toSet()
        mutate { ops -> ops.removeAll { it.opId in ids } }
    }

    fun prune(now: Long) = mutate { ops ->
        val kept = QueuePruning.prune(ops, now)
        if (kept.size != ops.size) {
            ops.clear()
            ops.addAll(kept)
        }
    }

    fun clear() = locked {
        file.delete()
        Unit
    }

    /** Runs [block] on the current ops and writes the result back atomically. */
    fun <T> mutate(block: (MutableList<PendingOp>) -> T): T = locked {
        val ops = read().toMutableList()
        val before = ops.map { it.toLine() }
        val result = block(ops)
        if (ops.map { it.toLine() } != before) write(ops)
        result
    }

    private fun read(): List<PendingOp> {
        if (!file.exists()) return emptyList()
        return file.readLines(Charsets.UTF_8).mapNotNull(PendingOp::parse)
    }

    private fun write(ops: List<PendingOp>) {
        dir.mkdirs()
        val tmp = File(dir, "$FILE_NAME.tmp")
        tmp.writeText(ops.joinToString(separator = "") { it.toLine() + "\n" }, Charsets.UTF_8)
        if (!tmp.renameTo(file)) {
            file.delete()
            if (!tmp.renameTo(file)) error("could not replace $FILE_NAME")
        }
    }

    private fun <T> locked(block: () -> T): T = processLock.withLock {
        dir.mkdirs()
        RandomAccessFile(lockFile, "rw").use { raf ->
            val lock = raf.channel.lock()
            try {
                block()
            } finally {
                lock.release()
            }
        }
    }

    companion object {
        const val FILE_NAME = "pending_ops.jsonl"
        const val LOCK_NAME = "pending_ops.lock"

        // A FileChannel lock is per JVM: a second lock from this process
        // throws OverlappingFileLockException, so threads queue up here first.
        private val processLock = ReentrantLock()
    }
}
