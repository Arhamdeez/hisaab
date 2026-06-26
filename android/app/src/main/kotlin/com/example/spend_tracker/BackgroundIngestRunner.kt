package com.example.spend_tracker

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Spins up a short-lived Flutter engine to drain [CapturedEventStore] while the
 * UI is closed — so payments register without the user opening the app.
 */
object BackgroundIngestRunner {
    private const val TAG = "BackgroundIngest"
    private const val BG_CHANNEL = "com.example.spend_tracker/background_ingest"
    private const val PREFS = "spend_tracker_ingest"
    private const val RESCAN_KEY = "bg_ingest_rescan"

    private const val SCHEDULE_DELAY_MS = 1500L
    private const val ENGINE_TIMEOUT_SEC = 90L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)
    private var pendingRescan = false
    private var runAgain = false
    private var scheduled: Runnable? = null

    fun schedule(context: Context, rescan: Boolean = false) {
        if (rescan) pendingRescan = true
        val appContext = context.applicationContext
        scheduled?.let { mainHandler.removeCallbacks(it) }
        val task = Runnable { runNow(appContext) }
        scheduled = task
        mainHandler.postDelayed(task, SCHEDULE_DELAY_MS)
    }

    fun runNow(context: Context, rescan: Boolean = false) {
        if (rescan) pendingRescan = true
        val appContext = context.applicationContext
        val shouldRescan = pendingRescan
        pendingRescan = false

        if (!shouldRescan && !IngestPlugin.hasPendingCaptures(appContext)) {
            Log.d(TAG, "skip — capture queue empty")
            return
        }

        if (IngestPlugin.isLiveIngestAttached()) {
            Log.d(TAG, "skip — foreground app is handling ingest")
            return
        }

        if (!running.compareAndSet(false, true)) {
            runAgain = true
            return
        }

        Thread {
            try {
                executeBackgroundIngest(appContext, shouldRescan)
            } catch (e: Exception) {
                Log.e(TAG, "background ingest failed", e)
            } finally {
                running.set(false)
                if (runAgain || IngestPlugin.hasPendingCaptures(appContext)) {
                    runAgain = false
                    schedule(appContext)
                }
            }
        }.start()
    }

    private fun executeBackgroundIngest(context: Context, rescan: Boolean) {
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
        }

        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(RESCAN_KEY, rescan)
            .commit()

        val latch = CountDownLatch(1)
        var engine: FlutterEngine? = null

        mainHandler.post {
            try {
                engine = FlutterEngine(context.applicationContext)
                val flutterEngine = engine!!
                io.flutter.plugins.GeneratedPluginRegistrant.registerWith(flutterEngine)
                // Required so drainPending / scanActiveNotifications MethodChannel works.
                IngestPlugin.registerMethodChannel(
                    context.applicationContext,
                    flutterEngine.dartExecutor.binaryMessenger,
                )

                val channel = MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    BG_CHANNEL,
                )
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "done", "error" -> {
                            if (call.method == "error") {
                                Log.w(TAG, "dart error: ${call.arguments}")
                            } else {
                                Log.i(TAG, "background ingest created=${call.arguments}")
                            }
                            latch.countDown()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }

                flutterEngine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "ingestBackgroundMain",
                    ),
                )
            } catch (e: Exception) {
                Log.e(TAG, "engine start failed", e)
                latch.countDown()
            }
        }

        val finished = latch.await(ENGINE_TIMEOUT_SEC, TimeUnit.SECONDS)
        if (!finished) {
            Log.w(TAG, "background ingest timed out")
        }

        mainHandler.post {
            try {
                engine?.destroy()
            } catch (_: Exception) {
            }
        }
    }
}
