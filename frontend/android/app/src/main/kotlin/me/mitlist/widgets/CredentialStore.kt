package me.mitlist.widgets

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The widget credential (contract C4): an `ml_int_…` token scoped to the four
 * widget routes, never the app's login tokens. Dart hands it over through the
 * channel while the app is in the foreground.
 */
data class WidgetCredential(
    val token: String,
    val expiresAt: String?,
    /** The app's Dio base URL, `…/api/v1`, so replayed requests hit the same URI. */
    val apiBaseUrl: String,
    val userId: String?,
    val deviceId: String?,
) {
    fun toJson(): String = JSONObject()
        .put("token", token)
        .put("expires_at", expiresAt)
        .put("api_base_url", apiBaseUrl)
        .put("user_id", userId)
        .put("device_id", deviceId)
        .toString()

    companion object {
        fun fromJson(json: String): WidgetCredential? = fromJson(JSONObject(json))

        fun fromJson(o: JSONObject): WidgetCredential? {
            val token = o.str("token")?.takeIf { it.isNotEmpty() } ?: return null
            val base = o.str("api_base_url")?.takeIf { it.isNotEmpty() } ?: return null
            return WidgetCredential(
                token = token,
                expiresAt = o.str("expires_at"),
                apiBaseUrl = base.trimEnd('/'),
                userId = o.str("user_id"),
                deviceId = o.str("device_id"),
            )
        }

        fun fromMap(map: Map<*, *>): WidgetCredential? {
            val o = JSONObject()
            for ((k, v) in map) if (k is String && v != null) o.put(k, v.toString())
            return fromJson(o)
        }
    }
}

/**
 * Keeps the credential encrypted with an AES-256-GCM key held in the Android
 * Keystore (prefs `mitlist_widget_credential`, excluded from backup). A
 * ciphertext the key cannot open, e.g. after a restore to another device,
 * reads as "no credential".
 */
object CredentialStore {
    private const val PREFS = "mitlist_widget_credential"
    private const val KEY_ALIAS = "mitlist_widget_credential"
    private const val KEY_IV = "iv"
    private const val KEY_CIPHERTEXT = "ciphertext"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_BITS = 128

    @Volatile
    private var cached: WidgetCredential? = null

    @Synchronized
    fun save(context: Context, credential: WidgetCredential) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key(create = true))
        val ciphertext = cipher.doFinal(credential.toJson().toByteArray(Charsets.UTF_8))
        prefs(context).edit()
            .putString(KEY_IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString(KEY_CIPHERTEXT, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
            .commit()
        cached = credential
    }

    @Synchronized
    fun load(context: Context): WidgetCredential? {
        cached?.let { return it }
        val prefs = prefs(context)
        val iv = prefs.getString(KEY_IV, null) ?: return null
        val ciphertext = prefs.getString(KEY_CIPHERTEXT, null) ?: return null
        return try {
            val key = key(create = false) ?: throw IllegalStateException("key missing")
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, Base64.decode(iv, Base64.NO_WRAP)))
            val plain = cipher.doFinal(Base64.decode(ciphertext, Base64.NO_WRAP))
            WidgetCredential.fromJson(String(plain, Charsets.UTF_8)).also { cached = it }
        } catch (_: Exception) {
            clear(context)
            null
        }
    }

    fun has(context: Context): Boolean = load(context) != null

    /** A stored credential whose expiry has passed (one without an expiry never counts as expired). */
    fun isExpired(credential: WidgetCredential, now: Long = System.currentTimeMillis()): Boolean {
        val expiresAt = credential.expiresAt?.let(Rfc3339::parseMillis) ?: return false
        return expiresAt <= now
    }

    /** Stored and not known to be expired: widget taps can reach the server. */
    fun isUsable(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val credential = load(context) ?: return false
        return !isExpired(credential, now)
    }

    /**
     * The app handed over a new credential: store it and clear the 401 flag
     * under the same lock [markAuthFailedUnlessReplaced] takes, so a sync
     * that got a 401 with the old token cannot raise the flag afterwards.
     */
    @Synchronized
    fun replace(context: Context, credential: WidgetCredential) {
        save(context, credential)
        WidgetStateStore(context).authFailed = false
    }

    /**
     * A request made with [usedToken] got a 401. Raises the auth-failed flag
     * only if that token is still the stored one; returns false when the app
     * has replaced it meanwhile (the weekly renewal revokes the old token at
     * once), so the caller retries with the new one instead.
     */
    @Synchronized
    fun markAuthFailedUnlessReplaced(context: Context, usedToken: String): Boolean {
        val current = load(context)
        if (current != null && current.token != usedToken) return false
        WidgetStateStore(context).authFailed = true
        return true
    }

    /**
     * A stored credential that decrypts and has not expired. The app re-issues
     * when this is false, e.g. after a restore to a new device.
     */
    fun hasValid(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val credential = load(context) ?: return false
        val expiresAt = credential.expiresAt?.let(Rfc3339::parseMillis) ?: return false
        return expiresAt > now
    }

    @Synchronized
    fun clear(context: Context) {
        cached = null
        prefs(context).edit().clear().commit()
        try {
            keyStore().deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {
            // Nothing to delete.
        }
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun keyStore(): KeyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun key(create: Boolean): SecretKey? {
        val store = keyStore()
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        if (!create) return null
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }
}
