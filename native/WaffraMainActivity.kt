package com.waffra.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.app.Activity
import java.io.ByteArrayOutputStream
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.auth.FirebaseAuth
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import javax.crypto.Mac
import javax.crypto.SecretKey
import org.json.JSONArray

// Share only SMS text explicitly selected by the user. Waffra does not read
// the SMS inbox or request READ_SMS, RECEIVE_SMS or bank account access.
class MainActivity : FlutterFragmentActivity() {
    private val privacyChannel = "waffra/privacy"
    private val messagesChannel = "waffra/messages"
    // History scans/decryption must never run on the Android UI thread.
    private val smsHistoryExecutor = Executors.newSingleThreadExecutor()
    // Native PBKDF2 runs independently of SMS I/O and the Android UI thread.
    private val passwordKdfExecutor = Executors.newSingleThreadExecutor()
    private var nativePasswordKdfParityVerified = false

    // Deterministic public vector, not user data. Reject Android providers
    // with different UTF-8/emoji PBKDF2 semantics; Dart performs the original
    // full-strength Isolate fallback instead of rejecting valid passwords.
    private fun assertNativePasswordKdfParity() {
        if (nativePasswordKdfParityVerified) return
        val salt = ByteArray(32) { it.toByte() }
        val chars = "اختبار🟢Waffra".toCharArray()
        val spec = PBEKeySpec(chars, salt, 1000, 256)
        try {
            val actual = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(spec).encoded
            val expected = "25c045b0f0158c986f57d1e4f260b73009c8ce9cf40a8b2fb4d44cd4e7cb9cd2"
                .chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            if (!java.security.MessageDigest.isEqual(actual, expected)) {
                throw IllegalStateException("Native PBKDF2 encoding mismatch")
            }
            nativePasswordKdfParityVerified = true
        } finally {
            spec.clearPassword()
            chars.fill('\u0000')
            salt.fill(0)
        }
    }
    private val autoSmsRequestCode = 7712
    private var pendingSmsPermissionResult: MethodChannel.Result? = null
    private val autoSmsNotificationRequestCode = 7713
    private var pendingNotificationResult: MethodChannel.Result? = null
    private val widgetChannelName = "waffra/widget"
    private val backupChannelName = "waffra/backup_files"
    // M219: read-only access to an independently provisioned Android Keystore
    // HMAC key. This activity NEVER creates, exports or replaces owner keys.
    private val ownerProofChannelName = "waffra/account_owner"
    private val ownerKeyAlias = "waffra_profile_owner_hmac_v1"
    private val backupWriteRequest = 7811
    private val backupReadRequest = 7812
    private val backupMaxBytes = 8 * 1024 * 1024
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupBytes: ByteArray? = null
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null
    private var messageChannel: MethodChannel? = null
    private var pendingShare: String? = null
    // M621: only opaque source IDs are staged until verified Flutter Home.
    // No SMS text, bank account or monetary detail crosses the launch intent.
    private var pendingFinanceNotification: Map<String, String>? = null

    private fun receiveFinanceNotification(received: Intent?) {
        if (received?.action != WaffraAutoSmsNotifications.OPEN_ACTION) return
        val destination = received.getStringExtra(
            WaffraAutoSmsNotifications.EXTRA_DESTINATION) ?: return
        val id = received.getStringExtra(
            WaffraAutoSmsNotifications.EXTRA_SMS_ID) ?: return
        if (destination != "review" && destination != "saved") return
        if (!Regex("^[a-f0-9]{64}$").matches(id)) return
        val payload = mutableMapOf("destination" to destination, "id" to id)
        if (destination == "saved") {
            val entry = received.getStringExtra(
                WaffraAutoSmsNotifications.EXTRA_ENTRY_ID) ?: return
            if (entry.isBlank() || entry.length > 200 ||
                entry.any { it.isISOControl() }) return
            payload["entryId"] = entry
        }
        pendingFinanceNotification = payload
        messageChannel?.invokeMethod("financeNotificationTap", payload)
    }
    private var screenshotsAllowed: Boolean = true
    private var protectRecents: Boolean = true

    private fun signExistingAccountOwnerChallenge(challenge: ByteArray?): String? {
        // Do not sign arbitrary UI input or secrets with the account owner key.
        if (challenge == null || challenge.isEmpty() || challenge.size > 2048) {
            return null
        }
        val ownerEnvelope = try {
            JSONArray(String(challenge, Charsets.UTF_8))
        } catch (_: Exception) {
            return null
        }
        if (ownerEnvelope.length() != 4 ||
            ownerEnvelope.optString(0) != "waffra-profile-owner-v1" ||
            ownerEnvelope.optString(1).isBlank() ||
            !Regex("[a-fA-F0-9]{64}").matches(ownerEnvelope.optString(2)) ||
            ownerEnvelope.optString(3).isBlank()) {
            return null
        }
        // The native Firebase SDK independently validates which principal
        // owns the session. Do not sign arbitrary supplied account UIDs.
        val authenticatedUser = FirebaseAuth.getInstance().currentUser
            ?: return null
        if (authenticatedUser.isAnonymous ||
            authenticatedUser.uid != ownerEnvelope.optString(3)) {
            return null
        }
        // No key creation, key export, recoverable fallback or PIN-based key.
        val keystore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val key = keystore.getKey(ownerKeyAlias, null) as? SecretKey
            ?: return null
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(key)
        return mac.doFinal(challenge).joinToString("") { byte ->
            "%02x".format(byte.toInt() and 0xff)
        }
    }

    private fun applyScreenshotSetting(allowed: Boolean) {
        screenshotsAllowed = allowed
        if (allowed) window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    // Android's Recent Apps thumbnail is captured while leaving the foreground.
    // Do not block normal foreground screenshots unless requested separately.
    override fun onStart() {
        super.onStart()
        WaffraAutoSmsWorker.setForegroundUiActive(true)
    }

    override fun onStop() {
        WaffraAutoSmsWorker.setForegroundUiActive(false)
        super.onStop()
    }

    override fun onPause() {
        if (protectRecents) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        applyScreenshotSetting(screenshotsAllowed)
        // A receiver can enqueue a bank candidate while Waffra is backgrounded.
        // A damaged encrypted queue must be reported by the Flutter review
        // screen, not crash Activity.onResume or be treated as zero pending.
        // Keystore decrypt and 500-item JSON decode can stall the Android UI
        // on return from Messages/Camera. Serialize this work off the main
        // thread with the existing dedicated SMS executor.
        val app = applicationContext
        smsHistoryExecutor.execute {
            val hasReview = try {
                WaffraAutoSmsStore.enabled(app) &&
                    WaffraAutoSmsStore.pending(app).isNotEmpty()
            } catch (_: Exception) {
                true // Flutter review reports the actual queue error.
            }
            if (hasReview) runOnUiThread {
                messageChannel?.invokeMethod("autoSmsAvailable", null)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int,
        permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == autoSmsNotificationRequestCode) {
            val callback = pendingNotificationResult
            pendingNotificationResult = null
            callback?.success(WaffraAutoSmsNotifications.canNotify(this))
            return
        }
        if (requestCode != autoSmsRequestCode) return
        val callback = pendingSmsPermissionResult
        pendingSmsPermissionResult = null
        callback?.success(WaffraAutoSmsStore.permissionGranted(this))
    }


    private fun receiveSharedText(received: Intent?) {
        if (received?.action != Intent.ACTION_SEND ||
            received.type?.startsWith("text/") != true) return
        val raw = received.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
        if (!raw.isNullOrEmpty()) {
            pendingShare = raw
            messageChannel?.invokeMethod("sharedText", raw)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        protectRecents = prefs.getBoolean("flutter.waffra_protect_recents_v1", true)
        applyScreenshotSetting(prefs.getBoolean("flutter.waffra_allow_screenshots", true))
        receiveSharedText(intent)
        receiveWidgetAction(intent)
        receiveFinanceNotification(intent)
    }

    private fun receiveWidgetAction(intent: Intent?) {
        if (intent?.action == "waffra.ADD_TRANSACTION") {
            pendingWidgetAction = "add"
            widgetChannel?.invokeMethod("quickAdd", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSharedText(intent)
        receiveWidgetAction(intent)
        receiveFinanceNotification(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Same on-device 600000-round PBKDF2-HMAC-SHA256 verifier bytes as Dart,
        // calculated by Android's native crypto provider off the UI isolate.
        // Do not persist or log the supplied password or derived key.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "waffra/password_kdf")
            .setMethodCallHandler { call, result ->
                if (call.method != "derivePbkdf2Sha256") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val password = call.argument<String>("password")
                val salt = call.argument<ByteArray>("salt")
                if (password == null || salt == null || salt.size != 32) {
                    result.error("PASSWORD_KDF_INVALID", "Invalid password KDF input", null)
                    return@setMethodCallHandler
                }
                passwordKdfExecutor.execute {
                    val chars = password.toCharArray()
                    val spec = PBEKeySpec(chars, salt, 600000, 256)
                    try {
                        assertNativePasswordKdfParity()
                        val secret = SecretKeyFactory
                            .getInstance("PBKDF2WithHmacSHA256")
                            .generateSecret(spec).encoded
                        if (secret.size != 32) throw IllegalStateException("KDF length")
                        // MethodChannel.Result supports background-thread replies.
                        result.success(secret)
                    } catch (_: Exception) {
                        result.error("PASSWORD_KDF_UNAVAILABLE", "Native password verification unavailable", null)
                    } finally {
                        spec.clearPassword()
                        chars.fill('\u0000')
                        salt.fill(0)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, privacyChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "setScreenshotsAllowed") {
                    val allowed = call.arguments as? Boolean ?: false
                    applyScreenshotSetting(allowed)
                    result.success(null)
                } else if (call.method == "setProtectRecents") {
                    protectRecents = call.arguments as? Boolean ?: true
                    result.success(null)
                } else result.notImplemented()
            }

        // Candidate-only: the missing key remains missing. Do not auto-enroll
        // an OS key from a profile, UI flag, Firebase UID or a migration test.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ownerProofChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "signExistingOwnerChallenge") {
                    result.notImplemented()
                } else {
                    try {
                        val proof = signExistingAccountOwnerChallenge(
                            call.argument<ByteArray>("challenge")
                        )
                        if (proof == null) {
                            result.error("OWNER_PROOF_UNAVAILABLE",
                                "An enrolled Android owner key and verified challenge are required.",
                                null)
                        } else {
                            result.success(proof)
                        }
                    } catch (_: Exception) {
                        // Never log keystore failures, account identifiers,
                        // signature values or exception details.
                        result.error("OWNER_PROOF_UNAVAILABLE",
                            "Device owner proof could not be verified.", null)
                    }
                }
            }

        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannelName)
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeWidgetAction" -> {
                    val value = pendingWidgetAction
                    pendingWidgetAction = null
                    result.success(value)
                }
                "updateSummary" -> {
                    val args = call.arguments as? Map<*, *>
                    val balance = args?.get("balance") as? String ?: "0.00"
                    val currency = args?.get("currency") as? String ?: "ريال"
                    val negative = args?.get("negative") as? Boolean ?: false
                    val hidden = args?.get("hidden") as? Boolean ?: false
                    getSharedPreferences("waffra_widget", MODE_PRIVATE).edit()
                        .putString("balance", balance)
                        .putString("currency", currency)
                        .putBoolean("negative", negative)
                        .putBoolean("hidden", hidden)
                        .apply()
                    WaffraWidget.updateAll(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, backupChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveEncryptedFile" -> createEncryptedBackupFile(
                        call.argument<String>("fileName") ?: "Waffra_Backup.waffra",
                        call.argument<String>("encryptedPayload") ?: "",
                        result
                    )
                    "openEncryptedFile" -> selectEncryptedBackupFile(result)
                    else -> result.notImplemented()
                }
            }
        messageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, messagesChannel)
        WaffraAutoSmsStore.onChanged = {
            messageChannel?.invokeMethod("autoSmsAvailable", null)
        }
        messageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeSharedText" -> {
                    val text = pendingShare
                    pendingShare = null
                    result.success(text)
                }
                "takeFinanceNotificationTap" -> {
                    val target = pendingFinanceNotification
                    pendingFinanceNotification = null
                    result.success(target)
                }
                "autoSmsPermissionState" -> result.success(WaffraAutoSmsStore.permissionGranted(this))
                // Encrypted queue counters and authenticated owner checks
                // can contend with the historical SMS scan's shared mutex.
                // Never synchronously read/decrypt the queue on Android UI.
                "autoSmsEnabled", "autoSmsTrackingStatus", "autoSmsScanProgress" -> {
                    val app = applicationContext
                    val request = call.method
                    smsHistoryExecutor.execute {
                        try {
                            val response: Any = when (request) {
                                "autoSmsEnabled" -> WaffraAutoSmsStore.enabled(app)
                                "autoSmsTrackingStatus" -> WaffraAutoSmsStore.trackingStatus(app)
                                else -> WaffraAutoSmsStore.scanProgress(app)
                            }
                            runOnUiThread { result.success(response) }
                        } catch (_: Exception) {
                            // Never put SMS, owner details or vault exceptions
                            // in platform errors or performance diagnostics.
                            runOnUiThread {
                                result.error("SMS_READ_UNAVAILABLE",
                                    "Unable to read bank SMS state", null)
                            }
                        }
                    }
                }
                "pauseAutoSmsForSignOut" -> {
                    // The encrypted queue mutex and SharedPreferences commit can
                    // block Android's main thread and freeze the sign-out spinner.
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val paused = WaffraAutoSmsStore.suspendForSignOut(app)
                            runOnUiThread { result.success(paused) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_SIGNOUT_UNAVAILABLE",
                                "Could not safely suspend SMS capture", null) }
                        }
                    }
                }
                "resumeAutoSmsAfterSignIn" -> {
                    // M547 PERF-04: never wait for the encrypted history
                    // queue's mutex or synchronous preferences commits on
                    // Android's main thread during verified login.
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val resumed = WaffraAutoSmsStore.resumeForSameSignedInOwner(app)
                            // Visible Home owns this queue; do not spin up a
                            // competing background FlutterEngine on relogin.
                            runOnUiThread { result.success(resumed) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_RESUME_UNAVAILABLE",
                                "Unable to restore bank SMS consent", null) }
                        }
                    }
                }
                "autoSmsNotificationsEnabled" ->
                    result.success(WaffraAutoSmsNotifications.canNotify(this))
                "requestAutoSmsNotifications" -> {
                    if (WaffraAutoSmsNotifications.canNotify(this)) result.success(true)
                    else if (pendingNotificationResult != null) result.error(
                        "NOTIFICATION_PERMISSION_BUSY", "Permission request pending", null)
                    else if (Build.VERSION.SDK_INT >= 33) {
                        pendingNotificationResult = result
                        requestPermissions(arrayOf(
                            Manifest.permission.POST_NOTIFICATIONS),
                            autoSmsNotificationRequestCode)
                    } else result.success(true)
                }
                "notifyAutoSmsSaved" -> {
                    val args = call.arguments as? Map<*, *>
                    val id = args?.get("hash") as? String ?: ""
                    val amount = args?.get("amount") as? String ?: ""
                    val income = args?.get("income") as? Boolean ?: false
                    val linked = args?.get("linkedBudget") as? Boolean ?: false
                    val entryId = args?.get("entryId") as? String ?: ""
                    result.success(WaffraAutoSmsNotifications.notifySaved(
                        this, id, income, amount, linked, entryId))
                }
                "notifyAutoSmsNeedsReview" -> {
                    val args = call.arguments as? Map<*, *>
                    val id = args?.get("hash") as? String
                        ?: call.arguments as? String ?: ""
                    val kind = args?.get("kind") as? String ?: "uncertain"
                    result.success(WaffraAutoSmsNotifications.notifyReview(this, id, kind))
                }
                "requestAutoSmsPermission" -> {
                    if (WaffraAutoSmsStore.permissionGranted(this)) result.success(true)
                    else if (pendingSmsPermissionResult != null) result.error(
                        "SMS_PERMISSION_BUSY", "Another permission dialog is active", null)
                    else {
                        pendingSmsPermissionResult = result
                        requestPermissions(arrayOf(Manifest.permission.READ_SMS,
                            Manifest.permission.RECEIVE_SMS), autoSmsRequestCode)
                    }
                }
                "setAutoSmsEnabled" -> {
                    // First-run permissions must not freeze biometric/Home
                    // animations while AES or SharedPreferences takes a lock.
                    val allow = call.arguments as? Boolean ?: false
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val saved = WaffraAutoSmsStore.enable(app, allow)
                            // First-run consent is followed by biometric/Home.
                            // The foreground scan will consume pending review.
                            runOnUiThread { result.success(saved) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_CONSENT_UNAVAILABLE",
                                "Unable to update bank SMS consent", null) }
                        }
                    }
                }
                "restartCompletedSmsHistory" -> {
                    // Legacy compatibility method. New-only Rescan no longer
                    // resets a completed or incomplete history cursor.
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val restarted = WaffraAutoSmsStore.restartCompletedHistory(app)
                            runOnUiThread { result.success(restarted) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_RESCAN_RESTART_FAILED",
                                "Could not safely restart SMS history", null) }
                        }
                    }
                }
                "importConsentMonthBankSms" -> {
                    // Provider scans and encrypted queue writes are blocking IO.
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val imported = WaffraAutoSmsStore.importConsentMonth(app)
                            runOnUiThread { result.success(imported) }
                        } catch (_: Exception) {
                            runOnUiThread {
                                result.error("SMS_HISTORY_IMPORT_FAILED",
                                    "Could not complete bank SMS history scan", null)
                            }
                        }
                    }
                }
                "scanUnknownFinancialSms" -> {
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val found = WaffraAutoSmsStore.scanUnknownFinancialSms(app)
                            runOnUiThread { result.success(found) }
                        } catch (_: Exception) {
                            runOnUiThread {
                                result.error("SMS_HISTORY_REVIEW_FAILED",
                                    "Could not scan unknown financial SMS", null)
                            }
                        }
                    }
                }
                "excludedAutoSmsSenders" -> {
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val senders = WaffraAutoSmsStore.excludedSenders(app)
                            runOnUiThread { result.success(senders) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_EXCLUSION_READ_FAILED",
                                "Could not verify excluded senders", null) }
                        }
                    }
                }
                "excludedAutoSmsMessages" -> {
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val items = WaffraAutoSmsStore.excludedMessages(app)
                            runOnUiThread { result.success(items) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_EXCLUDED_MESSAGES_READ_FAILED",
                                "Could not verify excluded message policy", null) }
                        }
                    }
                }
                "restoreExcludedAutoSmsMessage" -> {
                    val id = call.arguments as? String ?: ""
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val restored = WaffraAutoSmsStore.restoreExcludedMessage(app, id)
                        runOnUiThread { result.success(restored) }
                    }
                }
                "excludeAutoSmsSender" -> {
                    val sender = call.arguments as? String ?: ""
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val excluded = WaffraAutoSmsStore.excludeSender(app, sender)
                        runOnUiThread { result.success(excluded) }
                    }
                }
                "excludeAutoSmsSenders" -> {
                    val names = (call.arguments as? List<*>)
                        ?.filterIsInstance<String>() ?: emptyList()
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val excluded = WaffraAutoSmsStore.excludeSenders(app, names)
                        runOnUiThread { result.success(excluded) }
                    }
                }
                "restoreExcludedAutoSmsSender" -> {
                    val sender = call.arguments as? String ?: ""
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val restored = WaffraAutoSmsStore.restoreExcludedSender(app, sender)
                        runOnUiThread { result.success(restored) }
                    }
                }
                "pendingAutoBankSms" -> {
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val pending = WaffraAutoSmsStore.pending(app)
                            // Serialize large decrypted SMS lists off Android UI.
                            // Result callbacks are thread-safe; Flutter receives
                            // its reply asynchronously on its own platform channel.
                            result.success(pending)
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_REVIEW_READ_FAILED",
                                "Could not verify encrypted SMS queue", null) }
                        }
                    }
                }
                "pendingAutoBankSmsById" -> {
                    val id = call.arguments as? String ?: ""
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        try {
                            val selected = WaffraAutoSmsStore.pendingById(app, id)
                            runOnUiThread { result.success(selected) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("SMS_REVIEW_READ_FAILED",
                                "Could not verify selected encrypted SMS", null) }
                        }
                    }
                }
                "claimAutoBankSmsCloudAttempt" -> result.success(
                    WaffraAutoSmsStore.claimCloudAttempt(this, call.arguments as? String ?: ""))
                "stageAutoBankSmsCloudAnalysis" -> {
                    val args = call.arguments as? Map<*, *>
                    val id = args?.get("id") as? String ?: ""
                    val values = args?.get("analysis") as? Map<*, *> ?: emptyMap<Any, Any>()
                    result.success(WaffraAutoSmsStore.stageCloudAnalysis(this, id, values))
                }
                "ackAutoBankSms" -> {
                    val values = call.arguments as? List<*>
                    val ids = values?.filterIsInstance<String>()?.toSet() ?: emptySet()
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val acknowledged = WaffraAutoSmsStore.acknowledge(app, ids)
                        runOnUiThread { result.success(acknowledged) }
                    }
                }
                "excludeAutoBankSms" -> {
                    // M514 #448: unlike a reviewed financial commit, an
                    // excluded message is sealed against rescan in its OWN
                    // owner-scoped policy, never in the finance fingerprint.
                    val values = call.arguments as? List<*>
                    val ids = values?.filterIsInstance<String>()?.toSet() ?: emptySet()
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val excluded = WaffraAutoSmsStore.excludeMessages(app, ids)
                        runOnUiThread { result.success(excluded) }
                    }
                }
                "ackCompletedTransferAutoBankSms" -> {
                    // M516 #455: only invoked after verified SQLCipher transfer;
                    // a distinct encrypted fingerprint prevents future rescans.
                    val values = call.arguments as? List<*>
                    val ids = values?.filterIsInstance<String>()?.toSet() ?: emptySet()
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val completed = WaffraAutoSmsStore.acknowledgeCompletedTransfer(app, ids)
                        runOnUiThread { result.success(completed) }
                    }
                }
                "ackCommittedAutoBankSms" -> {
                    // Called ONLY after verified SQLCipher ledger hash presence.
                    // An excluded or cancelled message uses ordinary ACK.
                    val values = call.arguments as? List<*>
                    val ids = values?.filterIsInstance<String>()?.toSet() ?: emptySet()
                    val app = applicationContext
                    smsHistoryExecutor.execute {
                        val committed = WaffraAutoSmsStore.acknowledgeCommitted(app, ids)
                        runOnUiThread { result.success(committed) }
                    }
                }
                "openMessages" -> {
                    try {
                        val mainIntent = Intent(Intent.ACTION_MAIN)
                            .addCategory(Intent.CATEGORY_APP_MESSAGING)
                        startActivity(mainIntent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("sms:")))
                            result.success(true)
                        } catch (failure: ActivityNotFoundException) {
                            result.success(false)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }


    // Android Storage Access Framework: the user chooses the file provider
    // (local files or Google Drive). No storage permissions or clipboard used.
    private fun clearPendingBackup() {
        pendingBackupBytes?.fill(0)
        pendingBackupBytes = null
        pendingBackupResult = null
    }

    private fun createEncryptedBackupFile(fileName: String, payload: String, result: MethodChannel.Result) {
        if (pendingBackupResult != null) {
            result.error("BACKUP_BUSY", "A file selection is already active", null)
            return
        }
        val bytes = payload.toByteArray(Charsets.UTF_8)
        if (bytes.isEmpty() || bytes.size > backupMaxBytes) {
            bytes.fill(0)
            result.error("BACKUP_TOO_LARGE", "Invalid or oversized encrypted backup", null)
            return
        }
        // Refuse export of unencrypted data even if the Flutter UI regresses.
        if (!payload.contains("\"format\":\"waffra-secure-backup\"")) {
            bytes.fill(0)
            result.error("BACKUP_NOT_ENCRYPTED", "Only encrypted backups can be exported", null)
            return
        }
        val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(100).let { if (it.endsWith(".waffra")) it else "$it.waffra" }
        pendingBackupResult = result
        pendingBackupBytes = bytes
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("application/octet-stream")
                .putExtra(Intent.EXTRA_TITLE, safeName)
                .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            startActivityForResult(intent, backupWriteRequest)
        } catch (_: Exception) {
            clearPendingBackup()
            result.error("BACKUP_PICKER_UNAVAILABLE", "Unable to open the document picker", null)
        }
    }

    private fun selectEncryptedBackupFile(result: MethodChannel.Result) {
        if (pendingBackupResult != null) {
            result.error("BACKUP_BUSY", "A file selection is already active", null)
            return
        }
        pendingBackupResult = result
        try {
            // Any MIME type supports previously exported .json/.txt and new
            // .waffra archives. The Dart decryptor authenticates the content.
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("*/*")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivityForResult(intent, backupReadRequest)
        } catch (_: Exception) {
            clearPendingBackup()
            result.error("BACKUP_PICKER_UNAVAILABLE", "Unable to open the document picker", null)
        }
    }

    @Deprecated("Using Activity result to support FlutterFragmentActivity without extra dependencies")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != backupWriteRequest && requestCode != backupReadRequest) return
        val callback = pendingBackupResult
        try {
            if (callback == null) return
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(if (requestCode == backupWriteRequest) false else null)
                return
            }
            val uri = data.data!!
            if (uri.scheme != "content") {
                callback.error("BACKUP_INVALID_LOCATION", "Unsupported document provider", null)
                return
            }
            if (requestCode == backupWriteRequest) {
                val bytes = pendingBackupBytes ?: throw IllegalStateException("Missing encrypted backup")
                val stream = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("Unable to open backup destination")
                stream.use {
                    it.write(bytes)
                    it.flush()
                }
                callback.success(true)
            } else {
                val stream = contentResolver.openInputStream(uri)
                    ?: throw IllegalStateException("Unable to open selected backup")
                val output = ByteArrayOutputStream()
                stream.use {
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = it.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > backupMaxBytes) {
                            throw IllegalArgumentException("BACKUP_TOO_LARGE")
                        }
                        output.write(buffer, 0, count)
                    }
                }
                callback.success(output.toString(Charsets.UTF_8.name()))
            }
        } catch (e: IllegalArgumentException) {
            callback?.error("BACKUP_TOO_LARGE", "Backup exceeds the 8 MB import limit", null)
        } catch (_: Exception) {
            // Never log file content, encryption secrets, or document provider URI.
            callback?.error("BACKUP_FILE_IO", "Unable to read or write the backup document", null)
        } finally {
            clearPendingBackup()
        }
    }

    override fun onDestroy() {
        WaffraAutoSmsWorker.setForegroundUiActive(false)
        smsHistoryExecutor.shutdown()
        passwordKdfExecutor.shutdown()
        WaffraAutoSmsStore.onChanged = null
        pendingSmsPermissionResult?.error("SMS_PERMISSION_CANCELLED", "Activity closed", null)
        pendingSmsPermissionResult = null
        pendingNotificationResult?.error("NOTIFICATION_PERMISSION_CANCELLED", "Activity closed", null)
        pendingNotificationResult = null
        messageChannel = null
        widgetChannel = null
        super.onDestroy()
    }
}
