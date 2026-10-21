package com.waffra.app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * A short-lived transparent Flutter surface above the Android launcher.
 * Unlike MainActivity, it does not render Waffra's full home/navigation UI.
 */
class WaffraQuickActivity : FlutterActivity() {
    override fun getInitialRoute(): String = "/waffra-widget"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "waffra/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "closeWidgetWindow" -> {
                        result.success(null)
                        finish()
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
    }
}
