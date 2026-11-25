package com.example.pagestage_app

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import io.flutter.plugin.common.EventChannel
import com.ming3tts.MingLine
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val ming by lazy { MingModel.get(this) }
        MethodChannel(messenger, "pagestage/ming").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> result.success(ming.status())
                    "initialize" -> result.success(ming.initialize())
                    "synthesize" -> {
                        val lines = requireNotNull(call.argument<List<Map<String,String>>>("lines")).map {
                            MingLine(it.getValue("text"), it.getValue("voice"), it.getValue("emotion"))
                        }
                        ming.synthesize(lines) { outcome -> outcome.fold(result::success) {
                            result.error("ming_synthesis", it.message, null)
                        } }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                Log.e("PageStageMing", "Ming ${call.method} rejected", error)
                result.error("ming_unavailable", error.message, null)
            }
        }
        EventChannel(messenger, "pagestage/ming/progress").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink) {
                ming.listen { status ->
                    if (status["phase"] in setOf("copying","compiling"))
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    events.success(status)
                }
            }
            override fun onCancel(args: Any?) { ming.listen(null) }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pagestage/files")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "share" -> {
                            // Only a package the app just exported may leave through here.
                            val file = File(call.argument<String>("path") ?: "").canonicalFile
                            val exports = File(filesDir, "exports").canonicalFile
                            require(file.parentFile == exports && file.isFile &&
                                file.name.endsWith(".pagestage"))
                            val uri = FileProvider.getUriForFile(this, "$packageName.diagnostics", file)
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "application/octet-stream"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(send, null))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("share_failed", "Package unavailable", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pagestage/diagnostics")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "snapshot" -> {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            val crashes = if (Build.VERSION.SDK_INT >= 30) {
                                (getSystemService(ACTIVITY_SERVICE) as ActivityManager)
                                    .getHistoricalProcessExitReasons(packageName, 0, 32)
                                    .filter { it.reason == ApplicationExitInfo.REASON_CRASH ||
                                        it.reason == ApplicationExitInfo.REASON_CRASH_NATIVE ||
                                        it.reason == ApplicationExitInfo.REASON_ANR }
                                    .map { mapOf("timestamp" to it.timestamp, "reason" to it.reason,
                                        "status" to it.status, "pssKb" to it.pss, "rssKb" to it.rss) }
                            } else emptyList()
                            // Do not read trace streams, descriptions or process state summaries:
                            // they can contain arbitrary application/user strings.
                            result.success(mapOf("platform" to "android", "osVersion" to Build.VERSION.RELEASE,
                                "appVersion" to info.versionName,
                                "build" to (if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()).toString(),
                                "crashes" to crashes))
                        }
                        "share" -> {
                            val file = File(call.argument<String>("path") ?: "").canonicalFile
                            val allowed = File(filesDir, "diagnostics/pagestage-diagnostics.json").canonicalFile
                            require(file == allowed && file.isFile)
                            val uri = FileProvider.getUriForFile(this, "$packageName.diagnostics", file)
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "application/json"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(send, null))
                            result.success(null)
                        }
                        "feedback" -> {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/dayeguilaiye/pagestage/issues/new")))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("diagnostics_failed", "Diagnostic operation unavailable", null)
                }
            }
        IncomingFiles.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    // A file another app opened in pagestage, or shared to it, that started
    // the app. A restored activity, or one reopened from Recents, had it
    // already.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null &&
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0) {
            IncomingFiles.receive(this, intent)
        }
    }

    // One that arrives while the app runs.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        IncomingFiles.receive(this, intent)
    }
}
