package com.waffra.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Process a new bank SMS when the UI is closed using a short-lived Flutter
 * engine. All accounting is delegated to WaffraVerifiedFinanceAuthority,
 * using exactly the Home/Widget cross-engine journal. The native receiver
 * NEVER posts or alters amounts. WorkManager may defer execution under
 * Android power restrictions; a foreground fallback also drains the queue.
 */
class WaffraAutoSmsWorker(context: Context, parameters: WorkerParameters) :
    Worker(context, parameters) {

    override fun doWork(): Result {
        val context = applicationContext
        if (!WaffraAutoSmsStore.enabled(context)) return Result.success()
        val done = CountDownLatch(1)
        var successful = false
        var engine: FlutterEngine? = null
        val main = Handler(Looper.getMainLooper())
        main.post {
            try {
                if (!WaffraAutoSmsStore.enabled(context)) {
                    successful = true
                    done.countDown()
                    return@post
                }
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(context)
                loader.ensureInitializationComplete(context, null)
                val created = FlutterEngine(context)
                engine = created
                val messages = MethodChannel(
                    created.dartExecutor.binaryMessenger, "waffra/messages")
                messages.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "autoSmsEnabled" -> result.success(WaffraAutoSmsStore.enabled(context))
                        "pendingAutoBankSms" -> result.success(WaffraAutoSmsStore.pending(context))
                        "claimAutoBankSmsCloudAttempt" ->
                            result.success(WaffraAutoSmsStore.claimCloudAttempt(
                                context, call.arguments as? String ?: ""))
                        "stageAutoBankSmsCloudAnalysis" -> {
                            val args = call.arguments as? Map<*, *>
                            val id = args?.get("id") as? String ?: ""
                            val values = args?.get("analysis") as? Map<*, *> ?: emptyMap<Any, Any>()
                            result.success(WaffraAutoSmsStore.stageCloudAnalysis(context, id, values))
                        }
                        "ackAutoBankSms" -> {
                            val ids = (call.arguments as? List<*>)
                                ?.filterIsInstance<String>()?.toSet() ?: emptySet()
                            result.success(WaffraAutoSmsStore.acknowledge(context, ids))
                        }
                        "notifyAutoSmsSaved" -> {
                            val args = call.arguments as? Map<*, *>
                            result.success(WaffraAutoSmsNotifications.notifySaved(
                                context, args?.get("hash") as? String ?: "",
                                args?.get("income") as? Boolean ?: false,
                                args?.get("amount") as? String ?: "",
                                args?.get("linkedBudget") as? Boolean ?: false))
                        }
                        "notifyAutoSmsNeedsReview" ->
                            result.success(WaffraAutoSmsNotifications.notifyReview(
                                context, call.arguments as? String ?: ""))
                        else -> result.notImplemented()
                    }
                }
                val workerChannel = MethodChannel(
                    created.dartExecutor.binaryMessenger, "waffra/auto_sms_worker")
                workerChannel.setMethodCallHandler { call, result ->
                    if (call.method == "ready") {
                        result.success(null)
                        workerChannel.invokeMethod("process", null,
                            object : MethodChannel.Result {
                                override fun success(reply: Any?) {
                                    successful = reply == true
                                    done.countDown()
                                }
                                override fun error(code: String, message: String?,
                                                   details: Any?) {
                                    done.countDown()
                                }
                                override fun notImplemented() {
                                    done.countDown()
                                }
                            })
                    } else result.notImplemented()
                }
                created.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "waffraAutoSmsBackgroundEntrypoint"))
            } catch (_: Exception) {
                done.countDown()
            }
        }
        val completed = try { done.await(55, TimeUnit.SECONDS) }
            catch (_: InterruptedException) { false }
        main.post { engine?.destroy() }
        return if (completed && successful) Result.success()
            else if (runAttemptCount < 2) Result.retry()
            else Result.failure()
    }

    companion object {
        fun enqueue(context: Context) {
            if (!WaffraAutoSmsStore.enabled(context)) return
            try {
                val work = OneTimeWorkRequestBuilder<WaffraAutoSmsWorker>()
                    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 20, TimeUnit.SECONDS)
                    .build()
                WorkManager.getInstance(context).enqueueUniqueWork(
                    "waffra_auto_sms_finance", ExistingWorkPolicy.KEEP, work)
            } catch (_: Exception) {
                // Encrypted candidates survive until next foreground review.
            }
        }
    }
}
