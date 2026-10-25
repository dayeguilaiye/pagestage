package com.example.pagestage_app

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }
}
