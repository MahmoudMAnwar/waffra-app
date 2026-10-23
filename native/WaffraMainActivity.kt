package com.waffra.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.app.Activity
import java.io.ByteArrayOutputStream
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Share only SMS text explicitly selected by the user. Waffra does not read
// the SMS inbox or request READ_SMS, RECEIVE_SMS or bank account access.
class MainActivity : FlutterFragmentActivity() {
    private val privacyChannel = "waffra/privacy"
    private val messagesChannel = "waffra/messages"
    private val widgetChannelName = "waffra/widget"
    private val backupChannelName = "waffra/backup_files"
    private val backupWriteRequest = 7811
    private val backupReadRequest = 7812
    private val backupMaxBytes = 8 * 1024 * 1024
    private var pendingBackupResult: MethodChannel.Result? = null
    private var pendingBackupBytes: ByteArray? = null
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null
    private var messageChannel: MethodChannel? = null
    private var pendingShare: String? = null
    private var screenshotsAllowed: Boolean = true
    private var protectRecents: Boolean = true

    private fun applyScreenshotSetting(allowed: Boolean) {
        screenshotsAllowed = allowed
        if (allowed) window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    // Android's Recent Apps thumbnail is captured while leaving the foreground.
    // Do not block normal foreground screenshots unless requested separately.
    override fun onPause() {
        if (protectRecents) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        applyScreenshotSetting(screenshotsAllowed)
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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        messageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeSharedText" -> {
                    val text = pendingShare
                    pendingShare = null
                    result.success(text)
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
            @Suppress("DEPRECATION")
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
            @Suppress("DEPRECATION")
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
        messageChannel = null
        widgetChannel = null
        super.onDestroy()
    }
}
