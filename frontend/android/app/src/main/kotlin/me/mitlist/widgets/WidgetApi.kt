package me.mitlist.widgets

import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/** A finished HTTP exchange. */
data class HttpResult(val status: Int, val body: String?, val retryAfter: String?)

/**
 * Talks to the API with the widget credential (contract C4, "Native
 * delivery"). Requests carry the op's stored method, path and body bytes
 * unchanged, so the app's later replay hashes the same.
 */
class WidgetApi(private val credential: WidgetCredential) {
    /** Sends a queued op. Throws [IOException] when the server was not reached. */
    @Throws(IOException::class)
    fun send(op: PendingOp): HttpResult {
        val connection = open(credential.apiBaseUrl + op.path, op.method)
        connection.setRequestProperty("X-Mitlist-Group-ID", op.householdId)
        connection.setRequestProperty("Idempotency-Key", op.opId)
        connection.setRequestProperty("Content-Type", "application/json")
        val bytes = op.body.toByteArray(Charsets.UTF_8)
        connection.doOutput = true
        connection.setFixedLengthStreamingMode(bytes.size)
        return try {
            connection.outputStream.use { it.write(bytes) }
            read(connection)
        } finally {
            connection.disconnect()
        }
    }

    /** `GET /widget/snapshot`. Throws [IOException] when the server was not reached. */
    @Throws(IOException::class)
    fun fetchSnapshot(): HttpResult {
        val connection = open(credential.apiBaseUrl + "/widget/snapshot", "GET")
        return try {
            read(connection)
        } finally {
            connection.disconnect()
        }
    }

    private fun open(url: String, method: String): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        // Android's HttpURLConnection accepts PATCH (unlike the JDK's).
        connection.requestMethod = method
        connection.connectTimeout = CONNECT_TIMEOUT_MS
        connection.readTimeout = READ_TIMEOUT_MS
        connection.useCaches = false
        connection.instanceFollowRedirects = false
        connection.setRequestProperty("Authorization", "Bearer ${credential.token}")
        connection.setRequestProperty("Accept", "application/json")
        return connection
    }

    private fun read(connection: HttpURLConnection): HttpResult {
        val status = connection.responseCode
        val stream: InputStream? = if (status >= 400) connection.errorStream else connection.inputStream
        val body = stream?.use { it.readBytes().toString(Charsets.UTF_8) }
        return HttpResult(status, body, connection.getHeaderField("Retry-After"))
    }

    companion object {
        private const val CONNECT_TIMEOUT_MS = 10_000
        private const val READ_TIMEOUT_MS = 15_000
    }
}
