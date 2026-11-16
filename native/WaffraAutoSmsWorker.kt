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
        // Foreground Home owns review. Do not start a second FlutterEngine
        // against the same encrypted SMS queue while its first frames paint.
        if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context))
            return Result.success()
        val done = CountDownLatch(1)
        var successful = false
        var needsContinuation = false
        var engine: FlutterEngine? = null
        val main = Handler(Looper.getMainLooper())
        main.post {
            try {
                if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context)) {
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
                        "excludeAutoBankSms" -> {
                            // M982 #687: same owner-encrypted exclusion as
                            // MainActivity, never a financial commit/ACK.
                            val ids = (call.arguments as? List<*>)
                                ?.filterIsInstance<String>()?.toSet() ?: emptySet()
                            result.success(WaffraAutoSmsStore.excludeMessages(context, ids))
                        }
                        "markAutoBankSmsBackgroundReviewed" -> {
                            // M1020: this marks a reviewed SMS as attempted,
                            // but must never perform an ACK or finance write.
                            val id = call.arguments as? String ?: ""
                            result.success(WaffraAutoSmsStore.markBackgroundSmsReviewed(context, id))
                        }
                        "ackCommittedAutoBankSms" -> {
                            // Only Flutter's independent verified finance-hash
                            // evidence may call this committed-only API.
                            val ids = (call.arguments as? List<*>)
                                ?.filterIsInstance<String>()?.toSet() ?: emptySet()
                            result.success(WaffraAutoSmsStore.acknowledgeCommitted(context, ids))
                        }
                        "notifyAutoSmsSaved" -> {
                            val args = call.arguments as? Map<*, *>
                            result.success(WaffraAutoSmsNotifications.notifySaved(
                                context, args?.get("hash") as? String ?: "",
                                args?.get("income") as? Boolean ?: false,
                                args?.get("amount") as? String ?: "",
                                args?.get("linkedBudget") as? Boolean ?: false,
                                args?.get("entryId") as? String ?: ""))
                        }
                        "notifyAutoSmsNeedsReview" -> {
                            val args = call.arguments as? Map<*, *>
                            val id = args?.get("hash") as? String
                                ?: call.arguments as? String ?: ""
                            val kind = args?.get("kind") as? String ?: "uncertain"
                            result.success(WaffraAutoSmsNotifications.notifyReview(
                                context, id, kind))
                        }
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
                                    // A partial successful run has a durable
                                    // follow-up marker; never confuse partial
                                    // work with "all messages processed".
                                    successful = reply is Map<*, *> &&
                                        reply["finished"] == true &&
                                        reply["hasMore"] is Boolean
                                    needsContinuation = reply is Map<*, *> &&
                                        reply["hasMore"] == true
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
        // M1020 / #737: the encrypted queue preserves unattempted rows.
        // Schedule a successor only for an explicitly partial successful
        // pass. No competing FlutterEngines and no tight reprocessing of
        // already-review-only SMS after a completed full pass.
        if (completed && successful && needsContinuation) enqueue(context)
        // M1019 / #736: after a successful bounded Dart processing pass,
        // replay messages still in Android's SMS provider if the encrypted
        // queue had been full. Never evict rows or write money from Kotlin.
        // A subsequent WorkManager job handles newly imported candidates.
        if (completed && successful && !isForegroundUiActive() &&
            WaffraAutoSmsStore.capacityRecoveryNeeded(context)) {
            try {
                val beforeScanned =
                    (WaffraAutoSmsStore.scanProgress(context)["scanned"] as? Long) ?: -1L
                val recovered = WaffraAutoSmsStore.importConsentMonth(context, maxRead = 100)
                val afterScanned =
                    (WaffraAutoSmsStore.scanProgress(context)["scanned"] as? Long) ?: -1L
                // An inbox page can have only promos/old duplicates. It
                // still advances the durable cursor; schedule the next page
                // as long as measurable progress happened. Never spin after
                // a provider failure, full queue or unchanged cursor.
                if (recovered > 0 || afterScanned > beforeScanned) enqueue(context)
            } catch (_: Exception) {
                // Keep the durable capacity marker; next run can retry.
            }
        }
        return if (completed && successful) Result.success()
            else if (runAttemptCount < 2) Result.retry()
            else Result.failure()
    }

    companion object {
        @Volatile private var foregroundUiActive = false

        fun setForegroundUiActive(active: Boolean) {
            foregroundUiActive = active
        }

        fun isForegroundUiActive(): Boolean = foregroundUiActive

        fun enqueue(context: Context) {
            // An active Activity already drives incremental encrypted review.
            // Keep candidates on disk; background-only workers still run.
            if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context)) return
            try {
                val work = OneTimeWorkRequestBuilder<WaffraAutoSmsWorker>()
                    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 20, TimeUnit.SECONDS)
                    .build()
                // M1018 / #735: KEEP silently drops a new wakeup when an
                // existing worker already took its encrypted queue snapshot.
                // APPEND_OR_REPLACE schedules a successor without stopping
                // the currently running verified SQLCipher worker. Failed
                // prerequisites must not poison new arrivals.
                WorkManager.getInstance(context).enqueueUniqueWork(
                    "waffra_auto_sms_finance",
                    ExistingWorkPolicy.APPEND_OR_REPLACE, work)
            } catch (_: Exception) {
                // Encrypted candidates survive until next foreground review.
            }
        }
    }
}
