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
import java.util.Calendar
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
    // Hash of the verified signed-in account. No phone/email is saved here.
    private const val consentedOwnerName = "consented_account_sha256_v1"
    private const val suspendedAfterLogoutName = "suspended_after_logout_v1"
    private const val maxCandidates = 100
    private const val activationMonth = "sms_activation_month_start"
    private const val historyCursorAt = "sms_history_cursor_at"
    private const val historyCursorId = "sms_history_cursor_id"
    private const val historyComplete = "sms_history_complete"
    private const val historySourceMonth = "sms_history_source_install_month_v2"
    private fun monthStart() = Calendar.getInstance().apply {
        set(Calendar.DAY_OF_MONTH, 1)
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    // The requested historical boundary is the FIRST day of the calendar
    // month in which this installation was installed (not SMS consent day).
    // PackageInfo.firstInstallTime survives an in-place app update.
    private fun installationMonthStart(context: Context): Long {
        val installedAt = try {
            context.packageManager.getPackageInfo(context.packageName, 0).firstInstallTime
        } catch (_: Exception) { return 0L }
        if (installedAt <= 0L || installedAt > System.currentTimeMillis()) return 0L
        return Calendar.getInstance().apply {
            timeInMillis = installedAt
            set(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
    private val mutex = Any()
    @Volatile var onChanged: (() -> Unit)? = null

    fun permissionGranted(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED &&
        context.checkSelfPermission(Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED

    // Resolve the account from Flutter's existing verified profile without
    // placing phone numbers or email addresses in Android SMS preferences.
    private fun signedInOwnerHash(context: Context): String? {
        val user = context.getSharedPreferences("FlutterSharedPreferences",
            Context.MODE_PRIVATE)
        if (!user.getBoolean("flutter.waffra_onboarding_completed", false))
            return null
        val raw = user.getString("flutter.waffra_profile", "") ?: ""
        val profile = try { JSONObject(raw) } catch (_: Exception) { return null }
        val phone = profile.optString("phone", "").filter { it.isDigit() }
        val email = profile.optString("email", "").trim().lowercase()
        val identity = when {
            phone.length >= 9 -> "phone:$phone"
            email.contains('@') -> "email:$email"
            else -> return null
        }
        return MessageDigest.getInstance("SHA-256")
            .digest(identity.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
    }

    private fun activeProfileReady(context: Context): Boolean {
        val user = context.getSharedPreferences("FlutterSharedPreferences",
            Context.MODE_PRIVATE)
        return user.getBoolean("flutter.waffra_onboarding_completed", false) &&
            !user.getString("flutter.waffra_profile", "").isNullOrBlank()
    }

    fun enabled(context: Context): Boolean = synchronized(mutex) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        if (!permissionGranted(context) || !prefs.getBoolean(activeName, false) ||
            !activeProfileReady(context)) return@synchronized false
        val nowOwner = signedInOwnerHash(context)
        val boundOwner = prefs.getString(consentedOwnerName, null)
        if (boundOwner != null && boundOwner != nowOwner)
            return@synchronized false
        // Bind the first-install consent on first authenticated profile load.
        // Existing profiles without a stable identity can still use their
        // explicit session consent, but never silently resume after logout.
        if (boundOwner == null && nowOwner != null &&
            !prefs.edit().putString(consentedOwnerName, nowOwner).commit())
            return@synchronized false
        true
    }

    fun trackingStatus(context: Context): Map<String, Boolean> {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return mapOf(
            "permissionGranted" to permissionGranted(context),
            "trackingRequested" to prefs.getBoolean(activeName, false),
            "profileReady" to activeProfileReady(context),
            "suspendedAfterLogout" to prefs.getBoolean(suspendedAfterLogoutName, false),
            "historyComplete" to prefs.getBoolean(historyComplete, false),
            "enabled" to enabled(context)
        )
    }

    // Explicit opt-out must never auto-resume after a future login.
    fun enable(context: Context, allow: Boolean): Boolean = synchronized(mutex) {
        if (allow && !permissionGranted(context)) return@synchronized false
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val editor = prefs.edit().putBoolean(activeName, allow)
            .putBoolean(suspendedAfterLogoutName, false)
        if (allow) {
            val owner = signedInOwnerHash(context)
            val previous = prefs.getString(consentedOwnerName, null)
            if (previous != null && previous != owner) {
                // A different account's encrypted queue and read cursor must
                // never become visible under this explicit new opt-in.
                editor.remove(queueName).remove(historyCursorAt)
                    .remove(historyCursorId).remove(historySourceMonth)
                    .remove(historyComplete)
            }
            if (owner != null) editor.putString(consentedOwnerName, owner)
            else editor.remove(consentedOwnerName)
        }
        if (allow && !prefs.contains(activationMonth))
            editor.putLong(activationMonth, monthStart())
        if (!allow) editor.remove(queueName)
        editor.commit()
    }

    // Stop collection immediately on logout. Retain pending ciphertext only
    // when bound to a stable owner, to avoid losing unreviewed bank messages.
    // A new/different account cannot read it; explicit new opt-in purges it.
    fun suspendForSignOut(context: Context): Boolean = synchronized(mutex) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val owner = signedInOwnerHash(context)
        val bound = prefs.getString(consentedOwnerName, null)
        val canResume = prefs.getBoolean(activeName, false) &&
            owner != null && (bound == null || bound == owner)
        val editor = prefs.edit().putBoolean(activeName, false)
            .putBoolean(suspendedAfterLogoutName, canResume)
        if (canResume) editor.putString(consentedOwnerName, owner)
        else editor.remove(queueName)
        editor.commit()
    }

    fun resumeForSameSignedInOwner(context: Context): Boolean = synchronized(mutex) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        if (prefs.getBoolean(activeName, false)) return@synchronized enabled(context)
        val owner = signedInOwnerHash(context)
        if (!permissionGranted(context) || !activeProfileReady(context) ||
            !prefs.getBoolean(suspendedAfterLogoutName, false) ||
            owner == null || owner != prefs.getString(consentedOwnerName, null))
            return@synchronized false
        prefs.edit().putBoolean(activeName, true)
            .putBoolean(suspendedAfterLogoutName, false).commit()
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
        "(?:\\b(?:SAR|SR|AED|JOD|EGP|KWD|BHD|OMR|QAR|USD|EUR|GBP)(?=\\b|[0-9٠-٩۰-۹])|" +
        "ر\\.?\\s*س|ريال|درهم|دينار|جنيه|دولار|يورو)", RegexOption.IGNORE_CASE)
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

    // M437: Unknown-finance lookup is strictly ON-DEMAND, and scans from
    // the first day of the installation month with standing SMS consent.
    // Never treat invoice/debt IDs as a paid transaction or send unknown SMS
    // to OpenRouter. No raw unknown message is saved in Waffra storage.
    private val debtNotice = Regex(
        "(?:مديونية|مستحقة\\s+السداد|صدور\\s+مديونية|مطالبة\\s+مالية|" +
        "استحقاق\\s+سداد|debt\\s+(?:due|issued)|outstanding\\s+debt|" +
        "payment\\s+due|amount\\s+due)",
        RegexOption.IGNORE_CASE)
    private val otherFinanceNotice = Regex(
        "(?:فاتورة|مستحقات|حساب|رصيد|تحويل|خصم|سداد|" +
        "billing|invoice|statement|balance|transfer|debited|credited|" +
        "payment|transaction|refund|purchase)",
        RegexOption.IGNORE_CASE)
    private val institutionalSender = Regex(
        "(?:etimad|اعتماد|bank|alinma|inma|rajhi|snb|sabb|riyad|" +
        "bilad|anb|saib|aljazira|jazeera|alahli|stcpay|" +
        "stc.?bank|urpay|mobily.?pay)",
        RegexOption.IGNORE_CASE)

    fun unknownFinancialKind(sender: String, body: String): String? {
        val name = sender.trim()
        val safe = body.trim()
        // Institution senders may be Arabic (اعتماد) or English (Etimad).
        // Never accept a numeric/personal phone sender as an institution.
        val namedSender = name.length in 3..25 &&
            name.firstOrNull()?.isLetter() == true &&
            name.all { it.isLetterOrDigit() || it == ' ' ||
                it == '_' || it == '-' }
        if (!namedSender || safe.length !in 18..1600 ||
            otp.containsMatchIn(safe) || qualifies(name, safe)) return null
        if (debtNotice.containsMatchIn(safe)) return "debt_notice"
        if (institutionalSender.containsMatchIn(name) &&
            otherFinanceNotice.containsMatchIn(safe)) return "unrecognized_financial"
        return null
    }

    fun scanUnknownFinancialSms(
        context: Context, maxRead: Int = 500, maxResults: Int = 100
    ): List<Map<String, Any>> {
        if (!enabled(context) || maxRead <= 0 || maxResults <= 0)
            return emptyList()
        val start = installationMonthStart(context)
        if (start <= 0L) return emptyList()
        val end = System.currentTimeMillis() + 1
        val cursor = try {
            context.contentResolver.query(Uri.parse("content://sms/inbox"),
                arrayOf("address", "body", "date"),
                "date >= ? AND date < ?",
                arrayOf(start.toString(), end.toString()), "date DESC")
        } catch (_: Exception) { null } ?: return emptyList()
        val found = mutableListOf<Map<String, Any>>()
        cursor.use {
            val senderCol = it.getColumnIndex("address")
            val bodyCol = it.getColumnIndex("body")
            val dateCol = it.getColumnIndex("date")
            if (senderCol < 0 || bodyCol < 0 || dateCol < 0)
                return emptyList()
            var checked = 0
            while (it.moveToNext() && checked < maxRead &&
                found.size < maxResults) {
                checked++
                val sender = it.getString(senderCol) ?: continue
                val body = it.getString(bodyCol) ?: continue
                val date = it.getLong(dateCol)
                val kind = unknownFinancialKind(sender, body) ?: continue
                found.add(mapOf(
                    "id" to id(sender, body, date),
                    "sender" to sender,
                    "body" to body,
                    "receivedAt" to date,
                    "kind" to kind
                ))
            }
        }
        return found
    }

    private fun id(sender: String, body: String, at: Long): String {
        val input = "$sender\u0000$body\u0000$at"
        return MessageDigest.getInstance("SHA-256")
            .digest(input.toByteArray(StandardCharsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 255) }
    }

    fun offer(context: Context, sender: String, body: String, at: Long,
              historical: Boolean = false): Boolean {
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
                    .put("receivedAt", at)
                    .put("reviewNotified", historical))
                save(context, queue)
            } catch (_: Exception) { false }
        }
        if (result && !historical) Handler(Looper.getMainLooper()).post { onChanged?.invoke() }
        return result
    }

    fun pending(context: Context): List<Map<String, Any>> = synchronized(mutex) {
        if (!enabled(context)) return@synchronized emptyList()
        try {
            val data = read(context)
            (0 until data.length()).map { index ->
                val row = data.getJSONObject(index)
                val fields = mutableMapOf<String, Any>(
                    "id" to row.getString("id"),
                    "sender" to row.getString("sender"),
                    "body" to row.getString("body"),
                    "receivedAt" to row.getLong("receivedAt"))
                if (row.has("cloud")) {
                    val proof = row.optJSONObject("cloud")
                    if (proof != null) {
                        val analysis = mutableMapOf<String, Any>()
                        for (key in arrayOf("kind", "currency", "merchant")) {
                            if (!proof.isNull(key)) analysis[key] = proof.optString(key)
                        }
                        for (key in arrayOf("amount", "fee")) {
                            if (!proof.isNull(key)) analysis[key] = proof.optDouble(key)
                        }
                        analysis["requiresReview"] = proof.optBoolean("requiresReview", true)
                        fields["cloud"] = analysis
                    }
                }
                fields
            }
        } catch (failure: Exception) {
            // A broken AndroidKeyStore key or invalid ciphertext is NOT an
            // empty review queue. Report it to Flutter, never wipe or fabricate
            // a zero financial count.
            throw IllegalStateException("Encrypted SMS review queue unreadable", failure)
        }
    }

    /** Atomic per-SMS request claim shared by foreground and WorkManager.
     * A failed cloud request cannot be retried repeatedly on every resume.
     * No financial writer is reachable through this review-only record.
     */
    fun claimCloudAttempt(context: Context, id: String): Boolean =
        synchronized(mutex) {
            if (!enabled(context) || !Regex("^[a-f0-9]{64}$").matches(id))
                return@synchronized false
            try {
                val queue = read(context)
                val now = System.currentTimeMillis()
                for (i in 0 until queue.length()) {
                    val row = queue.getJSONObject(i)
                    if (row.optString("id") != id) continue
                    if (row.has("cloud")) return@synchronized false
                    val previous = row.optLong("cloudAttemptAtMs", 0L)
                    if (previous > now - 86400000L && previous <= now)
                        return@synchronized false
                    row.put("cloudAttemptAtMs", now)
                    return@synchronized save(context, queue)
                }
                false
            } catch (_: Exception) { false }
        }

    /** Persist sanitized LLM suggestions inside the same encrypted queue.
     * No original SMS is transmitted back to Android outside the app.
     * The model may never mark a candidate verified-for-posting.
     */
    fun stageCloudAnalysis(context: Context, id: String,
                           values: Map<*, *>): Boolean = synchronized(mutex) {
        if (!enabled(context) || !Regex("^[a-f0-9]{64}$").matches(id))
            return@synchronized false
        try {
            val allowed = setOf("kind", "currency", "merchant", "amount",
                "fee", "requiresReview")
            if (values.keys.any { it !is String || !allowed.contains(it) })
                return@synchronized false
            val kind = values["kind"] as? String ?: return@synchronized false
            if (!setOf("income", "expense", "transfer", "card_settlement",
                    "uncertain").contains(kind)) return@synchronized false
            val payload = JSONObject().put("kind", kind)
            for (field in arrayOf("currency", "merchant")) {
                val value = values[field] as? String
                if (value != null && value.length <= 90) payload.put(field, value)
            }
            for (field in arrayOf("amount", "fee")) {
                val value = values[field] as? Number
                if (value != null && value.toDouble().isFinite() &&
                    value.toDouble() >= 0 && value.toDouble() <= 100000000)
                    payload.put(field, value.toDouble())
            }
            // The model can express its uncertainty; *only* the local
            // trusted-bank evidence and locked ledger permit posting.
            payload.put("requiresReview", values["requiresReview"] == true)
            val queue = read(context)
            var found = false
            for (i in 0 until queue.length()) {
                val row = queue.getJSONObject(i)
                if (row.optString("id") == id) {
                    row.put("cloud", payload)
                    found = true
                    break
                }
            }
            found && save(context, queue)
        } catch (_: Exception) { false }
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

    /** Resumable history import: from day 1 of installation month through now.
     * This native importer never posts money or contacts a cloud provider.
     * An separately opted-in Flutter worker may stage sanitized cloud hints.
     * The encrypted queue holds up to 100 and resumes after user review.
     */
    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {
        if (!enabled(context)) return 0
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val start = installationMonthStart(context)
        if (start <= 0L) return 0
        // Do not mark the window permanently complete: next month's SMS
        // must also be found by a later on-demand scan.
        val end = System.currentTimeMillis() + 1
        var queued = try { synchronized(mutex) { read(context).length() } }
            catch (_: Exception) { return 0 }
        if (queued >= maxCandidates) return 0
        val projection = arrayOf("_id", "address", "body", "date")
        val cursor = try {
            context.contentResolver.query(Uri.parse("content://sms/inbox"),
                projection, "date >= ? AND date < ?",
                arrayOf(start.toString(), end.toString()), "date ASC, _id ASC")
        } catch (_: Exception) { null } ?: return 0
        // The v1 cursor started on the permission-activation month. On first
        // v2 scan replay from install-month start; queue and finance hashes
        // still protect existing reviewed entries from double posting.
        val sameSource = prefs.getLong(historySourceMonth, 0L) == start
        var lastAt = if (sameSource) prefs.getLong(historyCursorAt, start - 1) else start - 1
        var lastId = if (sameSource) prefs.getLong(historyCursorId, -1) else -1
        var checked = 0
        var accepted = 0
        var complete = true
        cursor.use {
            val rowCol = it.getColumnIndex("_id")
            val senderCol = it.getColumnIndex("address")
            val bodyCol = it.getColumnIndex("body")
            val dateCol = it.getColumnIndex("date")
            if (rowCol < 0 || senderCol < 0 || bodyCol < 0 || dateCol < 0)
                return 0
            while (it.moveToNext()) {
                val at = it.getLong(dateCol)
                val rowId = it.getLong(rowCol)
                if (at < lastAt || (at == lastAt && rowId <= lastId)) continue
                if (queued >= maxCandidates || checked >= maxRead) {
                    complete = false
                    break
                }
                val sender = it.getString(senderCol) ?: ""
                val body = it.getString(bodyCol) ?: ""
                if (qualifies(sender, body) &&
                    offer(context, sender, body, at, historical = true)) {
                    queued++
                    accepted++
                }
                checked++
                lastAt = at
                lastId = rowId
            }
        }
        prefs.edit().putLong(historyCursorAt, lastAt)
            .putLong(historyCursorId, lastId)
            .putLong(historySourceMonth, start)
            .putBoolean(historyComplete, complete).commit()
        return accepted
    }

    /** Claim each review notification once; history never floods the shade. */
    fun claimReviewNotification(context: Context, fingerprint: String): Boolean =
        synchronized(mutex) {
            try {
                val data = read(context)
                for (i in 0 until data.length()) {
                    val row = data.getJSONObject(i)
                    if (row.optString("id") != fingerprint) continue
                    if (row.optBoolean("reviewNotified", false)) return@synchronized false
                    row.put("reviewNotified", true)
                    return@synchronized save(context, data)
                }
                false
            } catch (_: Exception) { false }
        }

}
