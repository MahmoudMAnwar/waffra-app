package com.waffra.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Device-local encrypted intake queue; deliberately separate from the finance
 * ledger. The receiver has no credentials and cannot commit transactions.
 *
 * Never store rejected/non-financial messages, plaintext inbox contents,
 * authentication messages or full account/card numbers in analytics/logs.
 * No network calls or AI providers in this class.
 */
object WaffraAutoSmsStore {
    private const val prefsName = "waffra_auto_sms_intake_v1"
    private const val keyAlias = "waffra_sms_intake_aes_v1"
    private const val queueName = "encrypted_candidates"
    private const val activeName = "enabled"
    private const val maxCandidates = 100
    private val mutex = Any()
    @Volatile var onChanged: (() -> Unit)? = null

    fun permissionGranted(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED &&
        context.checkSelfPermission(Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun enabled(context: Context): Boolean = permissionGranted(context) &&
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getBoolean(activeName, false)

    fun enable(context: Context, allow: Boolean): Boolean = synchronized(mutex) {
        if (allow && !permissionGranted(context)) return@synchronized false
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .edit().putBoolean(activeName, allow).commit()
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(keyAlias, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(keyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(false).build())
        return generator.generateKey()
    }

    private fun seal(text: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.doFinal(text.toByteArray(StandardCharsets.UTF_8))
        return Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP)
    }

    private fun open(encrypted: String): JSONArray {
        if (encrypted.isBlank()) return JSONArray()
        val bytes = Base64.decode(encrypted, Base64.NO_WRAP)
        require(bytes.size > 28 && bytes.size < 250000)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128,
            bytes.copyOfRange(0, 12)))
        return JSONArray(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)),
            StandardCharsets.UTF_8))
    }

    private fun read(context: Context): JSONArray {
        val data = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(queueName, "") ?: ""
        // Corrupt or missing keys fail closed. Do NOT overwrite old ciphertext.
        return open(data)
    }

    private fun save(context: Context, content: JSONArray): Boolean =
        context.getSharedPreferences(prefsName, Context.MODE_PRIVATE).edit()
            .putString(queueName, seal(content.toString())).commit()

    private val otp = Regex(
        "(?:\\botp\\b|one.?time.?password|verification.?code|security.?code|" +
        "رمز\\s*(?:التحقق|التفعيل|الدخول|المرور)|كود\\s*(?:التحقق|الدخول)|" +
        "password|login.?code|authentication.?code|رمزك\\s*السري)",
        RegexOption.IGNORE_CASE)
    private val action = Regex(
        "(?:شراء|خصم|سحب|حوالة|تحويل|إيداع|ايداع|راتب|استرداد|سداد|" +
        "\\bpurchase\\b|\\bdebited\\b|\\bcredited\\b|\\btransfer\\b|" +
        "\\bwithdrawal\\b|\\bpayment\\b|\\bsalary\\b|\\brefund\\b|" +
        "\\bdeposit\\b)", RegexOption.IGNORE_CASE)
    private val money = Regex(
        "(?:\\bSAR\\b|\\bSR\\b|ر\\.?\\s*س|ريال)", RegexOption.IGNORE_CASE)
    private val digits = Regex("[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.]{0,14}")
    private val senderName = Regex("^[A-Za-z][A-Za-z0-9 _-]{2,24}$")
    private val brand = Regex(
        "(?:bank|alinma|inma|rajhi|snb|sabb|riyad|bilad|anb|saib|" +
        "aljazira|jazeera|alahli|stcpay|stc.?bank|urpay|mobily.?pay|" +
        "alrajhi|albilad)", RegexOption.IGNORE_CASE)

    fun qualifies(sender: String, body: String): Boolean {
        val safe = body.trim()
        if (safe.length < 18 || safe.length > 1600 || otp.containsMatchIn(safe))
            return false
        if (!senderName.matches(sender.trim())) return false
        if (!action.containsMatchIn(safe) || !money.containsMatchIn(safe) ||
            !digits.containsMatchIn(safe)) return false
        // Unknown financial senders can be reviewed, but a phone number or
        // personal sender must never become a financial account automatically.
        val hasFinancialSender = brand.containsMatchIn(sender) ||
            (sender.length <= 20 && action.containsMatchIn(safe))
        return hasFinancialSender
    }

    private fun id(sender: String, body: String, at: Long): String {
        val input = "$sender\u0000$body\u0000$at"
        return MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
    }

    fun offer(context: Context, sender: String, body: String, at: Long): Boolean {
        if (!enabled(context) || !qualifies(sender, body)) return false
        val result = synchronized(mutex) {
            try {
                val queue = read(context)
                val fingerprint = id(sender, body, at)
                for (i in 0 until queue.length()) {
                    if (queue.getJSONObject(i).optString("id") == fingerprint)
                        return@synchronized false
                }
                if (queue.length() >= maxCandidates) return@synchronized false
                queue.put(JSONObject().put("id", fingerprint)
                    .put("sender", sender.trim()).put("body", body.trim())
                    .put("receivedAt", at))
                save(context, queue)
            } catch (_: Exception) { false }
        }
        if (result) Handler(Looper.getMainLooper()).post { onChanged?.invoke() }
        return result
    }

    fun pending(context: Context): List<Map<String, Any>> = synchronized(mutex) {
        if (!enabled(context)) return@synchronized emptyList()
        try {
            val data = read(context)
            (0 until data.length()).map { index ->
                val row = data.getJSONObject(index)
                mapOf<String, Any>(
                    "id" to row.getString("id"),
                    "sender" to row.getString("sender"),
                    "body" to row.getString("body"),
                    "receivedAt" to row.getLong("receivedAt"))
            }
        } catch (_: Exception) { emptyList() }
    }

    fun acknowledge(context: Context, ids: Set<String>): Boolean =
        synchronized(mutex) {
            if (ids.isEmpty() || ids.size > maxCandidates) return@synchronized false
            try {
                val data = read(context)
                val remaining = JSONArray()
                for (i in 0 until data.length()) {
                    val row = data.getJSONObject(i)
                    if (!ids.contains(row.getString("id"))) remaining.put(row)
                }
                save(context, remaining)
            } catch (_: Exception) { false }
        }

    fun importRecent(context: Context, maxRead: Int = 500): Int {
        if (!enabled(context)) return 0
        var accepted = 0
        // One-off history import is opt-in. Never send a non-matching SMS to
        // Flutter and do not retain it. Android may deny inbox access.
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("_id", "address", "body", "date")
        val cursor = try {
            context.contentResolver.query(uri, projection, null, null, "date DESC")
        } catch (_: Exception) { null } ?: return 0
        cursor.use {
            val senderCol = it.getColumnIndex("address")
            val bodyCol = it.getColumnIndex("body")
            val dateCol = it.getColumnIndex("date")
            if (senderCol < 0 || bodyCol < 0 || dateCol < 0) return 0
            var scanned = 0
            while (it.moveToNext() && scanned < maxRead && accepted < maxCandidates) {
                scanned++
                val sender = it.getString(senderCol) ?: continue
                val body = it.getString(bodyCol) ?: continue
                val date = it.getLong(dateCol)
                if (offer(context, sender, body, date)) accepted++
            }
        }
        return accepted
    }
}
