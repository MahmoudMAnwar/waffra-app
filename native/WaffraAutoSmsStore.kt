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
    private const val excludedSendersName = "encrypted_excluded_senders_v1"
    // M509 #440: Sharded AES-GCM records of COMPLETED finance SMS fingerprints.
    // Value is sealed, owner-scoped and contains no raw SMS or bank numbers.
    private const val committedBucketPrefix = "encrypted_committed_sms_v1_"
    // M514 #448: excluded review SMS are not finance commits. Keep independent
    // owner-bound encrypted fingerprints so a historical rescan cannot replay them.
    private const val excludedMessageBucketPrefix = "encrypted_excluded_sms_v1_"
    // No raw SMS body: encrypted, owner-bound sender/time labels make
    // individual excluded messages visible and reversible in Settings.
    private const val excludedMessageInfoBucketPrefix = "encrypted_excluded_sms_info_v1_"
    private const val excludedInfoCleanupAt = "excluded_labels_last_cleanup_v1"
    private const val excludedLabelRetentionMs = 30L * 24 * 60 * 60 * 1000
    private const val excludedCleanupCadenceMs = 24L * 60 * 60 * 1000
    // M516 #455: a completed self-transfer is neither an excluded SMS nor
    // a finance income/expense commit; store its own encrypted anti-replay ID.
    private const val completedTransferBucketPrefix = "encrypted_completed_transfer_sms_v1_"
    private const val activeName = "enabled"
    // Hash of the verified signed-in account. No phone/email is saved here.
    private const val consentedOwnerName = "consented_account_sha256_v1"
    private const val suspendedAfterLogoutName = "suspended_after_logout_v1"
    private const val maxCandidates = 1000
    private const val activationMonth = "sms_activation_month_start"
    private const val historyCursorAt = "sms_history_cursor_at"
    private const val historyCursorId = "sms_history_cursor_id"
    private const val historyComplete = "sms_history_complete"
    // Durable marker: distinguish an unfinished first historical pass from new-only scans.
    private const val historyInitialCompleted = "sms_history_initial_completed_v1"
    private const val historyScannedCount = "sms_history_scanned_count_v1"
    private const val historyAddedCount = "sms_history_added_count_v1"
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
        // The account-backed profile is written only after verified login.
        // Fresh encrypted installs may not carry the legacy onboarding flag.
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
        // Require a stable authenticated owner, not an unrelated onboarding
        // preference. A sign-out removes the profile and fails closed.
        return !user.getString("flutter.waffra_profile", "").isNullOrBlank() &&
            signedInOwnerHash(context) != null
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

    /** Check whether the Android inbox has unseen rows without copying messages
     * into Waffra or doing a full rescan. Executed on the SMS I/O executor.
     */
    private fun hasUnseenInboxRows(context: Context, prefs: android.content.SharedPreferences): Boolean {
        val start = installationMonthStart(context)
        if (start <= 0L) return true
        val cursorAt = prefs.getLong(historyCursorAt, start - 1)
        val cursorId = prefs.getLong(historyCursorId, -1L)
        return try {
            context.contentResolver.query(Uri.parse("content://sms/inbox"),
                arrayOf("_id"),
                "(date > ? OR (date = ? AND _id > ?)) AND date < ?",
                arrayOf(cursorAt.toString(), cursorAt.toString(),
                    cursorId.toString(), (System.currentTimeMillis() + 1).toString()),
                "date ASC, _id ASC")?.use { it.moveToFirst() } ?: true
        } catch (_: Exception) { true }
    }

    /** Read-only progress counters, persisted alongside the resume cursor. */
    fun scanProgress(context: Context): Map<String, Any> = synchronized(mutex) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val waiting = try {
            if (enabled(context)) read(context).length() else -1
        } catch (_: Exception) { -1 }
        mapOf(
            "scanned" to prefs.getLong(historyScannedCount, 0L),
            "added" to prefs.getLong(historyAddedCount, 0L),
            "pending" to waiting,
            "capacity" to maxCandidates,
            "complete" to prefs.getBoolean(historyComplete, false),
            "initialComplete" to prefs.getBoolean(historyInitialCompleted, false),
            "rescanNeeded" to (waiting in 0 until maxCandidates &&
                (!prefs.getBoolean(historyComplete, false) ||
                 hasUnseenInboxRows(context, prefs)))
        )
    }

    // Explicit opt-out must never auto-resume after a future login.
    fun enable(context: Context, allow: Boolean): Boolean = synchronized(mutex) {
        if (allow && !permissionGranted(context)) return@synchronized false
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val previouslyActive = prefs.getBoolean(activeName, false)
        val editor = prefs.edit().putBoolean(activeName, allow)
            .putBoolean(suspendedAfterLogoutName, false)
        if (allow && !previouslyActive) {
            // Repair upgrades from the old sign-out flow, which discarded
            // review ciphertext but left the history cursor at the end.
            // Explicit renewed opt-in must safely replay the install month.
            // Existing confirmed finance hashes are still deduplicated by UI.
            editor.remove(historyCursorAt).remove(historyCursorId)
                .remove(historySourceMonth).remove(historyComplete)
                .remove(historyInitialCompleted).remove(historyScannedCount).remove(historyAddedCount)
        }
        if (allow) {
            val owner = signedInOwnerHash(context)
            val previous = prefs.getString(consentedOwnerName, null)
            if (previous != null && previous != owner) {
                // A different account's encrypted queue and read cursor must
                // never become visible under this explicit new opt-in.
                // A different verified account must never inherit completed
                // message markers from the previous owner.
                for (key in prefs.all.keys) {
                    if (key.startsWith(committedBucketPrefix) ||
                        key.startsWith(excludedMessageBucketPrefix) ||
                        key.startsWith(excludedMessageInfoBucketPrefix) ||
                        key.startsWith(completedTransferBucketPrefix)) editor.remove(key)
                }
                committedCipherCache.clear()
                excludedMessageCipherCache.clear()
                completedTransferCipherCache.clear()
                editor.remove(queueName).remove(excludedSendersName).remove(historyCursorAt)
                    .remove(historyCursorId).remove(historySourceMonth)
                    .remove(historyComplete).remove(historyInitialCompleted)
                    .remove(historyScannedCount).remove(historyAddedCount)
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
        require(bytes.size > 28 && bytes.size < 2000000)
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

    // Split marker ciphertext by first two hexadecimal hash characters:
    // historic inboxes can grow without a single enormous encrypted JSON
    // array, while cached shards make each SMS lookup O(1) in a scan.
    private val committedCipherCache =
        mutableMapOf<String, Pair<String, Set<String>>>()

    private fun committedBucket(context: Context, id: String): Set<String> {
        if (!Regex("^[a-f0-9]{64}$").matches(id))
            throw IllegalArgumentException("Invalid SMS fingerprint")
        val bucket = id.take(2)
        val ciphertext = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(committedBucketPrefix + bucket, "") ?: ""
        val cached = committedCipherCache[bucket]
        if (cached != null && cached.first == ciphertext) return cached.second
        val decoded = open(ciphertext)
        val result = (0 until decoded.length()).map { decoded.getString(it) }.toSet()
        committedCipherCache[bucket] = ciphertext to result
        return result
    }

    private fun isCommittedLocked(context: Context, id: String) =
        committedBucket(context, id).contains(id)

    private val excludedMessageCipherCache =
        mutableMapOf<String, Pair<String, Set<String>>>()

    private fun excludedMessageBucket(context: Context, id: String): Set<String> {
        if (!Regex("^[a-f0-9]{64}$").matches(id))
            throw IllegalArgumentException("Invalid excluded SMS fingerprint")
        val bucket = id.take(2)
        val encrypted = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(excludedMessageBucketPrefix + bucket, "") ?: ""
        val cached = excludedMessageCipherCache[bucket]
        if (cached != null && cached.first == encrypted) return cached.second
        val decoded = open(encrypted)
        val ids = (0 until decoded.length()).map { decoded.getString(it) }.toSet()
        // Invalid stored policy must fail closed, not silently discard it.
        if (ids.any { !Regex("^[a-f0-9]{64}$").matches(it) })
            throw IllegalStateException("Invalid encrypted SMS exclusion record")
        excludedMessageCipherCache[bucket] = encrypted to ids
        return ids
    }

    private fun isExcludedMessageLocked(context: Context, id: String) =
        excludedMessageBucket(context, id).contains(id)

    private fun excludedMessageInfo(context: Context, id: String): Map<String, JSONObject> {
        if (!Regex("^[a-f0-9]{64}$").matches(id))
            throw IllegalArgumentException("Invalid excluded-message lookup")
        val ciphertext = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(excludedMessageInfoBucketPrefix + id.take(2), "") ?: ""
        val array = open(ciphertext)
        val result = mutableMapOf<String, JSONObject>()
        for (i in 0 until array.length()) {
            val record = array.getJSONObject(i)
            val key = record.getString("id")
            val sender = record.getString("sender")
            val receivedAt = record.getLong("receivedAt")
            val excludedAt = record.optLong("excludedAt", 0L)
            if (!Regex("^[a-f0-9]{64}$").matches(key) ||
                key.take(2) != id.take(2) || sender.length > 100 ||
                receivedAt < 0 || excludedAt < 0 ||
                result.put(key, record) != null)
                throw IllegalStateException("Invalid excluded SMS label")
        }
        return result
    }

    /**
     * M616: purge recoverable *labels* 30 days after explicit exclusion, NOT
     * from original bank SMS date. The tiny encrypted denied-ID fingerprints
     * remain permanently owner-scoped to prevent historical SMS replay.
     * Legacy labels are given a fresh retention start rather than guessed
     * from the received date; neither old data nor a malformed record is
     * silently reclassified as eligible.
     */
    private fun pruneExcludedLabelsLocked(context: Context, force: Boolean) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val last = prefs.getLong(excludedInfoCleanupAt, 0L)
        if (!force && last in 1..now &&
            now - last < excludedCleanupCadenceMs) return
        val editor = prefs.edit()
        for (key in prefs.all.keys.filter {
            it.startsWith(excludedMessageInfoBucketPrefix)
        }) {
            val shard = key.removePrefix(excludedMessageInfoBucketPrefix)
            if (!Regex("^[a-f0-9]{2}$").matches(shard))
                throw IllegalStateException("Invalid excluded label shard")
            val labels = excludedMessageInfo(context, shard + "0".repeat(62))
            val active = mutableListOf<JSONObject>()
            for (record in labels.values) {
                val excludedAt = record.optLong("excludedAt", 0L)
                if (excludedAt == 0L) {
                    record.put("excludedAt", now)
                    active.add(record)
                } else if (excludedAt > now ||
                    now - excludedAt < excludedLabelRetentionMs) {
                    active.add(record)
                }
                // All old expired labels are physically erased; the separate
                // encrypted fingerprint denial-list is never removed here.
            }
            if (active.isEmpty()) editor.remove(key)
            else editor.putString(key, seal(JSONArray(active).toString()))
        }
        editor.putLong(excludedInfoCleanupAt, now)
        if (!editor.commit())
            throw IllegalStateException("Could not persist excluded SMS retention")
    }

    /** Shows only excluded SMS identities and safe sender/time labels;
     * pre-M517 encrypted fingerprints without labels remain visible by ID.
     * Every record is still bound to the active owner by enabled().
     */
    fun excludedMessages(context: Context): List<Map<String, Any>> =
        synchronized(mutex) {
            if (!enabled(context)) throw IllegalStateException("SMS intake not active")
            pruneExcludedLabelsLocked(context, force = true)
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val result = mutableListOf<Map<String, Any>>()
            val shards = prefs.all.keys.filter {
                it.startsWith(excludedMessageBucketPrefix)
            }
            for (key in shards) {
                val bucket = key.removePrefix(excludedMessageBucketPrefix)
                if (!Regex("^[a-f0-9]{2}$").matches(bucket))
                    throw IllegalStateException("Invalid excluded SMS shard")
                val exemplar = bucket + "0".repeat(62)
                val labels = excludedMessageInfo(context, exemplar)
                for (id in excludedMessageBucket(context, exemplar)) {
                    // Expired labels remain as opaque rescan-denial fingerprints
                    // only. They are intentionally NOT recoverable in the UI.
                    val info = labels[id] ?: continue
                    result.add(mapOf(
                        "id" to id,
                        "sender" to info.optString("sender"),
                        "receivedAt" to info.optLong("receivedAt", 0L),
                        "excludedAt" to info.optLong("excludedAt", 0L)
                    ))
                }
            }
            result.sortedWith(compareByDescending<Map<String, Any>> {
                (it["receivedAt"] as? Long) ?: 0L
            }.thenBy { it["id"] as String })
        }

    /** Restore just one excluded SMS; a later explicit rescan may offer it.
     * Excluded sender policy, completed transfers and finance are unaffected.
     */
    fun restoreExcludedMessage(context: Context, id: String): Boolean =
        synchronized(mutex) {
            if (!enabled(context) || !Regex("^[a-f0-9]{64}$").matches(id))
                return@synchronized false
            try {
                val current = excludedMessageBucket(context, id)
                if (!current.contains(id)) return@synchronized false
                val savedLabels = excludedMessageInfo(context, id).toMutableMap()
                savedLabels.remove(id)
                val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                val succeeded = prefs.edit()
                    .putString(excludedMessageBucketPrefix + id.take(2),
                        seal(JSONArray(current.filter { it != id }).toString()))
                    .putString(excludedMessageInfoBucketPrefix + id.take(2),
                        seal(JSONArray(savedLabels.values.toList()).toString()))
                    .commit()
                if (succeeded) {
                    excludedMessageCipherCache.clear()
                    Handler(Looper.getMainLooper()).post { onChanged?.invoke() }
                }
                succeeded
            } catch (_: Exception) { false }
        }


    private val completedTransferCipherCache =
        mutableMapOf<String, Pair<String, Set<String>>>()
    private fun completedTransferBucket(context: Context, id: String): Set<String> {
        if (!Regex("^[a-f0-9]{64}$").matches(id))
            throw IllegalArgumentException("Invalid completed transfer SMS fingerprint")
        val bucket = id.take(2)
        val encrypted = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(completedTransferBucketPrefix + bucket, "") ?: ""
        val cached = completedTransferCipherCache[bucket]
        if (cached != null && cached.first == encrypted) return cached.second
        val decoded = open(encrypted)
        val ids = (0 until decoded.length()).map { decoded.getString(it) }.toSet()
        if (ids.any { !Regex("^[a-f0-9]{64}$").matches(it) })
            throw IllegalStateException("Invalid completed transfer SMS marker")
        completedTransferCipherCache[bucket] = encrypted to ids
        return ids
    }

    private fun isCompletedTransferLocked(context: Context, id: String) =
        completedTransferBucket(context, id).contains(id)

    // Explicit user sender exclusion is encrypted and bound to this authenticated
    // owner. Do not reuse a removed sender as an automatic learned rule.
    // Parsed plaintext stays only in this process memory and is invalidated
    // whenever the sealed prefs value changes. Fast for a 500-SMS import.
    private var excludedCipherCache: String? = null
    private var excludedArrayCache = JSONArray()
    private fun readExcluded(context: Context): JSONArray {
        val encrypted = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            .getString(excludedSendersName, "") ?: ""
        if (encrypted == excludedCipherCache) return excludedArrayCache
        val decoded = open(encrypted) // Corruption must fail closed.
        excludedCipherCache = encrypted
        excludedArrayCache = decoded
        return decoded
    }

    private fun normalizedSender(sender: String) =
        sender.trim().lowercase(java.util.Locale.ROOT)

    private fun isExcludedLocked(context: Context, sender: String): Boolean {
        val normalized = normalizedSender(sender)
        val entries = readExcluded(context)
        for (i in 0 until entries.length()) {
            if (normalizedSender(entries.getString(i)) == normalized) return true
        }
        return false
    }

    fun excludedSenders(context: Context): List<String> = synchronized(mutex) {
        if (!enabled(context)) throw IllegalStateException("SMS intake not active")
        val entries = readExcluded(context)
        (0 until entries.length()).map { entries.getString(it) }
    }

    /** Owner-confirmed sender exclusion. Queue removal and denial-list update
     * are one preferences commit; existing saved finance and phone SMS remain.
     */
    fun excludeSender(context: Context, sender: String): Boolean =
        excludeSenders(context, listOf(sender))

    /** Only encrypted blocked sender names survive this atomic operation.
     * Queue SMS and old labelled per-message excluded fingerprints are purged.
     * Completed financial/transfer receipt hashes and Android SMS are untouched.
     */
    fun excludeSenders(context: Context, senders: List<String>): Boolean = synchronized(mutex) {
        val requested = senders.map { normalizedSender(it) }.toSet()
        if (!enabled(context) || requested.isEmpty() || requested.size > 1000 ||
            senders.any { it.isBlank() || it.trim().length > 100 })
            return@synchronized false
        try {
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val previous = readExcluded(context)
            val entries = JSONArray()
            val known = HashSet<String>()
            for (i in 0 until previous.length()) {
                val name = previous.getString(i)
                entries.put(name)
                known.add(normalizedSender(name))
            }
            for (sender in senders) {
                val clean = sender.trim()
                if (known.add(normalizedSender(clean))) entries.put(clean)
            }
            val current = read(context)
            val remaining = JSONArray()
            for (i in 0 until current.length()) {
                val row = current.getJSONObject(i)
                if (normalizedSender(row.optString("sender")) !in requested)
                    remaining.put(row)
            }
            val editor = prefs.edit()
                .putString(excludedSendersName, seal(entries.toString()))
                .putString(queueName, seal(remaining.toString()))
            // Sender policy supersedes individual exclusions. Old records
            // lacking sender labels cannot be safely attributed and remain.
            for (key in prefs.all.keys.filter {
                it.startsWith(excludedMessageInfoBucketPrefix)
            }) {
                val shard = key.removePrefix(excludedMessageInfoBucketPrefix)
                if (!Regex("^[a-f0-9]{2}$").matches(shard))
                    throw IllegalStateException("Invalid excluded SMS shard")
                val sampleId = shard + "0".repeat(62)
                val labels = excludedMessageInfo(context, sampleId)
                val discarded = labels.values.filter {
                    normalizedSender(it.getString("sender")) in requested
                }.map { it.getString("id") }.toSet()
                if (discarded.isEmpty()) continue
                val oldIds = excludedMessageBucket(context, sampleId)
                if (!oldIds.containsAll(discarded))
                    throw IllegalStateException("Excluded receipt mismatch")
                val keptIds = oldIds.filterNot { it in discarded }
                val keptLabels = labels.values.filterNot {
                    it.getString("id") in discarded
                }
                if (keptIds.isEmpty())
                    editor.remove(excludedMessageBucketPrefix + shard)
                else editor.putString(excludedMessageBucketPrefix + shard,
                    seal(JSONArray(keptIds).toString()))
                if (keptLabels.isEmpty()) editor.remove(key)
                else editor.putString(key, seal(JSONArray(keptLabels).toString()))
            }
            val saved = editor.commit()
            if (saved) {
                excludedMessageCipherCache.clear()
                Handler(Looper.getMainLooper()).post { onChanged?.invoke() }
            }
            saved
        } catch (_: Exception) { false }
    }

    fun restoreExcludedSender(context: Context, sender: String): Boolean =
        synchronized(mutex) {
            if (!enabled(context) || sender.isBlank() || sender.trim().length > 100)
                return@synchronized false
            try {
                val old = readExcluded(context)
                val updated = JSONArray()
                var found = false
                for (i in 0 until old.length()) {
                    val existing = old.getString(i)
                    if (normalizedSender(existing) == normalizedSender(sender)) found = true
                    else updated.put(existing)
                }
                if (!found) return@synchronized false
                context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                    .edit().putString(excludedSendersName, seal(updated.toString()))
                    .commit()
            } catch (_: Exception) { false }
        }

    private val otp = Regex(
        "(?:\\botp\\b|one.?time.?password|verification.?code|security.?code|" +
        "رمز\\s*(?:التحقق|التفعيل|الدخول|المرور)|كود\\s*(?:التحقق|الدخول)|" +
        "password|login.?code|authentication.?code|رمزك\\s*السري)",
        RegexOption.IGNORE_CASE)
    private val action = Regex(
        "(?:شراء|خصم|سحب|حوالة|تحويل|إيداع|ايداع|راتب|استرداد|سداد|شحن|دفع|" +
        "\\bpurchase\\b|\\bdebited\\b|\\bcredited\\b|\\btransfer\\b|" +
        "\\bwithdrawal\\b|\\bpayment\\b|\\bsalary\\b|\\brefund\\b|" +
        "\\bdeposit\\b)", RegexOption.IGNORE_CASE)
    private val money = Regex(
        "(?:\\b(?:SAR|SR|AED|JOD|EGP|KWD|BHD|OMR|QAR|USD|EUR|GBP)(?=\\b|[0-9٠-٩۰-۹])|" +
        "ر\\.?\\s*س|ريال|درهم|دينار|جنيه|دولار|يورو)", RegexOption.IGNORE_CASE)
    private val digits = Regex("[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.]{0,14}")
    // M509: any branded sender can contain a financial notice, even if
    // its sender name is not on our fixed bank list. Numeric phone senders
    // require independent strong completed-event evidence before review.
    private val senderName = Regex("^[\\p{L}][\\p{L}0-9 _.-]{2,63}$")
    private val numericSender = Regex("^\\+?[0-9]{7,15}$")
    private val completedFinancialAction = Regex(
        "(?:تم\\s+(?:الخصم|خصم|السحب|سحب|الإيداع|ايداع|إيداع|الشراء|شراء|الدفع|دفع)|" +
        "عملية\\s+(?:شراء|خصم|سحب|إيداع|ايداع)|" +
        "\\b(?:card\\s+purchase|purchase\\s+approved|salary\\s+credited|" +
        "account\\s+credited|amount\\s+debited|transfer\\s+received|" +
        "payment\\s+completed|withdrawal\\s+completed)\\b)",
        RegexOption.IGNORE_CASE)
    private val brand = Regex(
        "(?:bank|alinma|inma|rajhi|snb|sabb|riyad|bilad|anb|saib|" +
        "aljazira|jazeera|alahli|stcpay|stc.?bank|urpay|mobily.?pay|" +
        "alrajhi|albilad|الراجحي|الإنماء|الانماء|الأهلي|الاهلي|الرياض|البلاد)", RegexOption.IGNORE_CASE)

    /** Any SMS inbox sender may enter review. This is NOT finance authority.
     * Keep bounded ciphertext and mask OTP digits before it is persisted.
     */
    fun reviewEligible(sender: String, body: String): Boolean =
        sender.isNotBlank() && sender.trim().length <= 100 &&
        body.isNotBlank() && body.length <= 1600

    fun qualifies(sender: String, body: String): Boolean {
        val safe = body.trim()
        if (safe.length < 10 || safe.length > 1600) return false
        val named = senderName.matches(sender.trim())
        val phoneLike = numericSender.matches(sender.trim())
        if (!named && !phoneLike) return false
        // Personal/phone-number senders cannot qualify based on a price
        // alone. Direction, currency, completed-event wording and amount
        // must all be present. This still never authorizes a financial account.
        if (phoneLike) return safe.length >= 18 &&
            !otp.containsMatchIn(safe) &&
            completedFinancialAction.containsMatchIn(safe) &&
            action.containsMatchIn(safe) && money.containsMatchIn(safe) &&
            digits.containsMatchIn(safe)
        // Non-financial verification notices are reviewable as EXCLUDED,
        // never processed as money. No original verification digits are kept.
        if (otp.containsMatchIn(safe)) return true
        // Read-only bank notifications (balance, debt, billing) may be
        // classified as Excluded on first review; they are never money.
        if (institutionalSender.containsMatchIn(sender) &&
            (otherFinanceNotice.containsMatchIn(safe) ||
             debtNotice.containsMatchIn(safe))) return true
        if (safe.length < 18) return false
        // A trusted institution may send a financial amount without the
        // small v1 action-word set. Keep it in encrypted REVIEW; never post.
        if (institutionalSender.containsMatchIn(sender) &&
            money.containsMatchIn(safe) && digits.containsMatchIn(safe)) return true
        if (!action.containsMatchIn(safe) || !money.containsMatchIn(safe) ||
            !digits.containsMatchIn(safe)) return false
        // M509: do not reject legitimate messages merely because their
        // sender does not contain a hard-coded bank alias or exceeds 20 chars.
        // Dart classifies candidates with the M508 Arabic/English catalog
        // and independently verifies direction, amount and account.
        return named
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
        "stc.?bank|urpay|mobily.?pay|الراجحي|الإنماء|الانماء|" +
        "الأهلي|الاهلي|الرياض|البلاد)",
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
        context: Context, maxRead: Int = 5000, maxResults: Int = 500
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
                // Read-only unknown-notice scan must obey the same exclusions.
                if (synchronized(mutex) { isExcludedLocked(context, sender) }) continue
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
              historical: Boolean = false, receivedAt: Long = at): Boolean {
        if (!enabled(context)) return false
        // Ignore excluded senders before even local financial parsing.
        try {
            if (synchronized(mutex) { isExcludedLocked(context, sender) }) return false
        } catch (_: Exception) { return false }
        if (!reviewEligible(sender, body)) return false
        val result = synchronized(mutex) {
            try {
                // Recheck after entering the lock: logout may race the
                // receiver between its first permission check and this read.
                if (!enabled(context) || isExcludedLocked(context, sender))
                    return@synchronized false
                val queue = read(context)
                val fingerprint = id(sender, body, at)
                // Verified financial SMS is never offered again after
                // rescan, reinstall-preserving update or OS resume.
                if (isCommittedLocked(context, fingerprint) ||
                    isExcludedMessageLocked(context, fingerprint) ||
                    isCompletedTransferLocked(context, fingerprint))
                    return@synchronized false
                for (i in 0 until queue.length()) {
                    if (queue.getJSONObject(i).optString("id") == fingerprint)
                        return@synchronized false
                }
                if (queue.length() >= maxCandidates) return@synchronized false
                val sensitive = otp.containsMatchIn(body)
                // Mask every contiguous run of digits in OTP notices,
                // including localized digit variants, before encryption.
                // The original is used only to derive the dedupe hash;
                // it is never put in the review queue or cloud payload.
                val masked = if (sensitive) body.trim().replace(
                    Regex("[0-9٠-٩۰-۹]+"), "••••") else body.trim()
                queue.put(JSONObject().put("id", fingerprint)
                    .put("sender", sender.trim()).put("body", masked)
                    .put("sensitiveOtp", sensitive)
                    .put("receivedAt", receivedAt)
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
                    "receivedAt" to row.getLong("receivedAt"),
                    "sensitiveOtp" to row.optBoolean("sensitiveOtp", false))
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

    /** A single already-known SMS for a tapped notification.
     * This avoids marshalling all 1000 encrypted review items across the
     * platform channel on every item tap. It never posts or ACKs anything.
     */
    fun pendingById(context: Context, id: String): Map<String, Any>? =
        synchronized(mutex) {
            if (!enabled(context) || !Regex("^[a-f0-9]{64}$").matches(id))
                return@synchronized null
            try {
                val queue = read(context)
                for (index in 0 until queue.length()) {
                    val row = queue.getJSONObject(index)
                    if (row.optString("id") != id) continue
                    val fields = mutableMapOf<String, Any>(
                        "id" to row.getString("id"),
                        "sender" to row.getString("sender"),
                        "body" to row.getString("body"),
                        "receivedAt" to row.getLong("receivedAt"),
                        "sensitiveOtp" to row.optBoolean("sensitiveOtp", false))
                    row.optJSONObject("cloud")?.let { proof ->
                        val analysis = mutableMapOf<String, Any>()
                        for (key in arrayOf("kind", "currency", "merchant")) {
                            if (!proof.isNull(key)) analysis[key] = proof.optString(key)
                        }
                        for (key in arrayOf("amount", "fee")) {
                            if (!proof.isNull(key)) analysis[key] = proof.optDouble(key)
                        }
                        analysis["requiresReview"] =
                            proof.optBoolean("requiresReview", true)
                        fields["cloud"] = analysis
                    }
                    return@synchronized fields
                }
                null
            } catch (failure: Exception) {
                throw IllegalStateException(
                    "Encrypted SMS review queue unreadable", failure)
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
                    if (row.optBoolean("sensitiveOtp", false))
                        return@synchronized false
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
            if (!enabled(context) || ids.isEmpty() || ids.size > maxCandidates)
                return@synchronized false
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

    /**
     * M514 #448: A user-excluded SMS must stay excluded on historical rescan.
     * Unlike acknowledgeCommitted this does NOT mark any financial hash.
     * One encrypted preferences commit persists BOTH the exact SMS IDs and
     * their removal from the encrypted review queue. No whole-sender block.
     */
    fun excludeMessages(context: Context, ids: Set<String>): Boolean =
        synchronized(mutex) {
            if (!enabled(context) || ids.isEmpty() || ids.size > 100 ||
                ids.any { !Regex("^[a-f0-9]{64}$").matches(it) })
                return@synchronized false
            try {
                val queue = read(context)
                val remaining = JSONArray()
                val matched = mutableSetOf<String>()
                val labels = mutableMapOf<String, JSONObject>()
                for (i in 0 until queue.length()) {
                    val row = queue.getJSONObject(i)
                    val fingerprint = row.getString("id")
                    if (ids.contains(fingerprint)) {
                        matched.add(fingerprint)
                        labels[fingerprint] = JSONObject()
                            .put("id", fingerprint)
                            .put("sender", row.optString("sender").take(100))
                            .put("receivedAt", row.optLong("receivedAt", 0L))
                            .put("excludedAt", System.currentTimeMillis())
                    } else remaining.put(row)
                }
                // Fail closed if a selected SMS was neither queued nor
                // previously excluded; a wrong-owner ID never gets marked.
                if (ids.any { !matched.contains(it) &&
                        !isExcludedMessageLocked(context, it) })
                    return@synchronized false
                val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                val editor = prefs.edit()
                    .putString(queueName, seal(remaining.toString()))
                for ((bucket, additions) in matched.groupBy { it.take(2) }) {
                    val updated = excludedMessageBucket(context,
                        additions.first()).toMutableSet()
                    updated.addAll(additions)
                    editor.putString(excludedMessageBucketPrefix + bucket,
                        seal(JSONArray(updated.toList()).toString()))
                    val details = excludedMessageInfo(context, additions.first())
                        .toMutableMap()
                    for (item in additions) details[item] = labels.getValue(item)
                    editor.putString(excludedMessageInfoBucketPrefix + bucket,
                        seal(JSONArray(details.values.toList()).toString()))
                }
                val success = editor.commit()
                if (success) {
                    excludedMessageCipherCache.clear()
                    Handler(Looper.getMainLooper()).post { onChanged?.invoke() }
                }
                success
            } catch (_: Exception) { false }
        }

    /**
     * M516 #455: confirmed account-to-account SMS transfer completion.
     * A successful verified transfer occurs in SQLCipher BEFORE this ACK.
     * This encrypted, owner-bound marker is NOT a user exclusion and does
     * NOT claim a bank SMS was booked as an income/expense journal entry.
     * Marker and queue removal use ONE synchronous preferences commit.
     */
    fun acknowledgeCompletedTransfer(context: Context, ids: Set<String>): Boolean =
        synchronized(mutex) {
            if (!enabled(context) || ids.isEmpty() || ids.size > 100 ||
                ids.any { !Regex("^[a-f0-9]{64}$").matches(it) })
                return@synchronized false
            try {
                val queue = read(context)
                val remaining = JSONArray()
                val matched = mutableSetOf<String>()
                for (i in 0 until queue.length()) {
                    val row = queue.getJSONObject(i)
                    val fingerprint = row.getString("id")
                    if (ids.contains(fingerprint)) matched.add(fingerprint)
                    else remaining.put(row)
                }
                if (ids.any { !matched.contains(it) &&
                        !isCompletedTransferLocked(context, it) })
                    return@synchronized false
                val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                val editor = prefs.edit().putString(queueName, seal(remaining.toString()))
                for ((bucket, additions) in matched.groupBy { it.take(2) }) {
                    val updated = completedTransferBucket(context, additions.first())
                        .toMutableSet()
                    updated.addAll(additions)
                    editor.putString(completedTransferBucketPrefix + bucket,
                        seal(JSONArray(updated.toList()).toString()))
                }
                val saved = editor.commit()
                if (saved) {
                    completedTransferCipherCache.clear()
                    Handler(Looper.getMainLooper()).post { onChanged?.invoke() }
                }
                saved
            } catch (_: Exception) { false }
        }

    /**
     * Called ONLY after Flutter independently proves the exact bank SMS hash
     * exists in the authoritative encrypted financial ledger. An ordinary
     * exclude/reject/transfer ACK is NOT a financial commit and must never
     * poison this permanent fingerprint set.
     *
     * One SharedPreferences editor commits both the cleared queue and all
     * affected encrypted fingerprint shards atomically. On any failure the
     * pending message is preserved for another verified reconciliation.
     */
    fun acknowledgeCommitted(context: Context, ids: Set<String>): Boolean =
        synchronized(mutex) {
            if (!enabled(context) || ids.isEmpty() || ids.size > 100 ||
                ids.any { !Regex("^[a-f0-9]{64}$").matches(it) })
                return@synchronized false
            try {
                val data = read(context)
                val remaining = JSONArray()
                val present = mutableSetOf<String>()
                for (i in 0 until data.length()) {
                    val row = data.getJSONObject(i)
                    val fingerprint = row.getString("id")
                    if (ids.contains(fingerprint)) present.add(fingerprint)
                    else remaining.put(row)
                }
                // Never accept an arbitrary ID as a "completed" bank SMS.
                if (ids.any { !present.contains(it) &&
                        !isCommittedLocked(context, it) }) return@synchronized false
                val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                val changed = present.groupBy { it.take(2) }
                val editor = prefs.edit()
                    .putString(queueName, seal(remaining.toString()))
                for ((bucket, additions) in changed) {
                    val merged = committedBucket(context, additions.first()).toMutableSet()
                    merged.addAll(additions)
                    editor.putString(committedBucketPrefix + bucket,
                        seal(JSONArray(merged.toList()).toString()))
                }
                val succeeded = editor.commit()
                if (succeeded) committedCipherCache.clear()
                succeeded
            } catch (_: Exception) { false }
        }

    /**
     * M547: a completed historical pass is a durable high-water mark.
     * Never rewind to the first day of installation on a normal rescan:
     * committed and excluded SMS must stay invisible and the user should
     * see the number of *new* provider rows actually examined.
     */
    fun restartCompletedHistory(context: Context): Boolean = synchronized(mutex) {
        // Compatibility entry point for older Flutter callers. It is
        // intentionally non-destructive: no cursor or owner data is erased.
        enabled(context) &&
            context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                .getBoolean(historyComplete, false)
    }

    private data class HistoricalSmsRow(
        val rowId: Long,
        val receivedAt: Long,
        val identityAt: Long,
        val sender: String,
        val body: String
    )

    /**
     * Read a bounded cursor page and persist all candidates plus the cursor
     * together in ONE encrypted preferences commit. The former per-row
     * offer() read+decrypt+linear-search+encrypt+fsync path was quadratic.
     * Live SMS broadcasts still use offer() for crash-safe single intake.
     *
     * If the queue fills, only rows actually inspected advance the cursor.
     * On commit failure neither the queue nor cursor is advanced, allowing
     * a safe replay without duplicate financial posting.
     */
    fun importConsentMonth(context: Context, maxRead: Int = 500): Int {
        if (maxRead <= 0 || !enabled(context)) return 0
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val start = installationMonthStart(context)
        if (start <= 0L) return 0
        val ownerAtStart = signedInOwnerHash(context) ?: return 0
        val end = System.currentTimeMillis() + 1
        val originalCursor = synchronized(mutex) {
            if (!enabled(context)) return 0
            val currentSize = try { read(context).length() }
                catch (_: Exception) { return 0 }
            if (currentSize >= maxCandidates) return 0
            val sameSource = prefs.getLong(historySourceMonth, 0L) == start
            Pair(
                if (sameSource) prefs.getLong(historyCursorAt, start - 1) else start - 1,
                if (sameSource) prefs.getLong(historyCursorId, -1L) else -1L
            )
        }

        val projection = arrayOf("_id", "address", "body", "date", "date_sent")
        val providerCursor = try {
            context.contentResolver.query(Uri.parse("content://sms/inbox"),
                projection, "(date > ? OR (date = ? AND _id > ?)) AND date < ?",
                arrayOf(originalCursor.first.toString(),
                    originalCursor.first.toString(),
                    originalCursor.second.toString(), end.toString()),
                "date ASC, _id ASC")
        } catch (_: Exception) { null } ?: return 0

        // The extra row determines whether more history remains without
        // guessing from the size of the last page.
        val rows = ArrayList<HistoricalSmsRow>(maxRead.coerceAtMost(1000) + 1)
        providerCursor.use {
            val rowCol = it.getColumnIndex("_id")
            val senderCol = it.getColumnIndex("address")
            val bodyCol = it.getColumnIndex("body")
            val dateCol = it.getColumnIndex("date")
            val sentCol = it.getColumnIndex("date_sent")
            if (rowCol < 0 || senderCol < 0 || bodyCol < 0 || dateCol < 0)
                return 0
            while (rows.size <= maxRead && it.moveToNext()) {
                val at = it.getLong(dateCol)
                val rowId = it.getLong(rowCol)
                if (at < originalCursor.first ||
                    (at == originalCursor.first && rowId <= originalCursor.second))
                    continue
                val senderTime = if (sentCol >= 0 && !it.isNull(sentCol))
                    it.getLong(sentCol) else 0L
                val identityAt = if (senderTime > 946684800000L &&
                    senderTime <= end + 300000L) senderTime else at
                rows.add(HistoricalSmsRow(rowId, at, identityAt,
                    it.getString(senderCol) ?: "", it.getString(bodyCol) ?: ""))
            }
        }

        return synchronized(mutex) {
            // A logout, new account or overlapping scan must not commit an
            // old owner's candidate rows or leapfrog another cursor writer.
            if (!enabled(context) ||
                ownerAtStart != signedInOwnerHash(context)) return@synchronized 0
            val stillSameMonth = prefs.getLong(historySourceMonth, 0L) == start
            val currentAt = if (stillSameMonth)
                prefs.getLong(historyCursorAt, start - 1) else start - 1
            val currentId = if (stillSameMonth)
                prefs.getLong(historyCursorId, -1L) else -1L
            if (Pair(currentAt, currentId) != originalCursor)
                return@synchronized 0
            try {
                val queue = read(context)
                // Decrypt the excluded-sender list once per historical page.
                val excluded = readExcluded(context)
                val excludedNames = HashSet<String>(excluded.length() * 2 + 1)
                for (i in 0 until excluded.length()) {
                    excludedNames.add(normalizedSender(excluded.getString(i)))
                }
                val existingIds = HashSet<String>(queue.length() * 2 + 1)
                for (i in 0 until queue.length()) {
                    existingIds.add(queue.getJSONObject(i).getString("id"))
                }
                var examined = 0
                var accepted = 0
                var stoppedForCapacity = false
                var nextAt = originalCursor.first
                var nextId = originalCursor.second
                for (row in rows.take(maxRead)) {
                    if (queue.length() >= maxCandidates) {
                        stoppedForCapacity = true
                        break
                    }
                    if (!excludedNames.contains(normalizedSender(row.sender)) &&
                        reviewEligible(row.sender, row.body)) {
                        val fingerprint = id(row.sender, row.body, row.identityAt)
                        if (!existingIds.contains(fingerprint) &&
                            !isCommittedLocked(context, fingerprint) &&
                            !isExcludedMessageLocked(context, fingerprint) &&
                            !isCompletedTransferLocked(context, fingerprint)) {
                            val sensitive = otp.containsMatchIn(row.body)
                            val masked = if (sensitive)
                                row.body.trim().replace(Regex("[0-9٠-٩۰-۹]+"), "••••")
                                else row.body.trim()
                            queue.put(JSONObject().put("id", fingerprint)
                                .put("sender", row.sender.trim()).put("body", masked)
                                .put("sensitiveOtp", sensitive)
                                .put("receivedAt", row.receivedAt)
                                .put("reviewNotified", true))
                            existingIds.add(fingerprint)
                            accepted++
                        }
                    }
                    examined++
                    nextAt = row.receivedAt
                    nextId = row.rowId
                }
                val complete = !stoppedForCapacity &&
                    rows.size <= maxRead && examined == rows.size
                val previousExamined = if (stillSameMonth)
                    prefs.getLong(historyScannedCount, 0L) else 0L
                val previousAdded = if (stillSameMonth)
                    prefs.getLong(historyAddedCount, 0L) else 0L
                val editor = prefs.edit()
                    .putLong(historyCursorAt, nextAt)
                    .putLong(historyCursorId, nextId)
                    .putLong(historySourceMonth, start)
                    .putLong(historyScannedCount, previousExamined + examined)
                    .putLong(historyAddedCount, previousAdded + accepted)
                    .putBoolean(historyComplete, complete)
                if (complete) editor.putBoolean(historyInitialCompleted, true)
                if (accepted > 0)
                    editor.putString(queueName, seal(queue.toString()))
                if (!editor.commit()) return@synchronized 0
                accepted
            } catch (_: Exception) {
                // Never overwrite earlier ciphertext or advance a failed scan.
                0
            }
        }
    }

    /** Claim each review notification once; history never floods the shade. */
    fun claimReviewNotification(context: Context, fingerprint: String): Boolean =
        synchronized(mutex) {
            if (!enabled(context)) return@synchronized false
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
