package com.waffra.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Share only SMS text explicitly selected by the user. Waffra does not read
// the SMS inbox or request READ_SMS, RECEIVE_SMS or bank account access.
class MainActivity : FlutterFragmentActivity() {
    private val privacyChannel = "waffra/privacy"
    private val messagesChannel = "waffra/messages"
    private var messageChannel: MethodChannel? = null
    private var pendingShare: String? = null

    private fun applyScreenshotSetting(allowed: Boolean) {
        if (allowed) window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        else window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
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
        applyScreenshotSetting(prefs.getBoolean("flutter.waffra_allow_screenshots", true))
        receiveSharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receiveSharedText(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, privacyChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "setScreenshotsAllowed") {
                    val allowed = call.arguments as? Boolean ?: false
                    applyScreenshotSetting(allowed)
                    result.success(null)
                } else result.notImplemented()
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

    override fun onDestroy() {
        messageChannel = null
        super.onDestroy()
    }
}
