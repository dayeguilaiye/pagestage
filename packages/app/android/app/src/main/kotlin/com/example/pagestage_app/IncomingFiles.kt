package com.example.pagestage_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Files other apps open in pagestage ("Open with") or share to it. Each is
 * copied into cacheDir/incoming/<id>/ under the name the sender shows, and the
 * copy's path handed to Dart over `pagestage/incoming`. Paths wait until Dart
 * calls `ready`, so a file that started the app is kept while Flutter starts.
 * Dart imports the copy and deletes it. Process-wide, like audio_service's
 * cached engine, which outlives any one activity.
 */
object IncomingFiles {
    private val copying = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var messenger: BinaryMessenger? = null
    private var channel: MethodChannel? = null
    private var listening = false
    private val waiting = mutableListOf<String>()

    /** Called whenever an activity configures the engine; only a new engine needs a new channel. */
    fun attach(messenger: BinaryMessenger) {
        if (messenger === this.messenger) return
        this.messenger = messenger
        listening = false
        channel = MethodChannel(messenger, "pagestage/incoming").apply {
            setMethodCallHandler { call, result ->
                if (call.method != "ready") return@setMethodCallHandler result.notImplemented()
                listening = true
                result.success(waiting.toList())
                waiting.clear()
            }
        }
    }

    /** On the main thread. Shared text without a file has nothing to import. */
    fun receive(context: Context, intent: Intent) {
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> stream(intent)
            else -> null
        } ?: return
        val app = context.applicationContext
        val type = intent.type
        copying.execute {
            val path = copy(app, uri, type)
            main.post { deliver(path) }
        }
    }

    private fun stream(intent: Intent): Uri? =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else @Suppress("DEPRECATION") intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri

    private fun deliver(path: String) {
        val channel = channel
        if (!listening || channel == null) {
            waiting += path
            return
        }
        channel.invokeMethod("open", path, object : MethodChannel.Result {
            override fun success(result: Any?) {}
            // Dart stopped listening, after a restart say: the file waits for
            // the next `ready`.
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = keep(path)
            override fun notImplemented() = keep(path)
        })
    }

    private fun keep(path: String) {
        listening = false
        waiting += path
    }

    /**
     * The copy's path. A file that cannot be read still gets one, with
     * nothing there, so Dart's import reports it unreadable by name.
     */
    private fun copy(context: Context, uri: Uri, type: String?): String {
        val folder = File(context.cacheDir, "incoming/${UUID.randomUUID()}")
        val copy = File(folder, name(context, uri, type))
        try {
            folder.mkdirs()
            requireNotNull(context.contentResolver.openInputStream(uri)).use { input ->
                copy.outputStream().use { input.copyTo(it) }
            }
        } catch (_: Exception) {
            copy.delete()
        }
        return copy.absolutePath
    }

    /** The sender's name for the file made safe, with .txt or .epub added when it has no extension. */
    private fun name(context: Context, uri: Uri, type: String?): String {
        val shown = try {
            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { if (it.moveToFirst()) it.getString(0) else null }
        } catch (_: Exception) {
            null
        }
        var name = (shown ?: uri.lastPathSegment ?: "").substringAfterLast('/')
            .replace(Regex("[\\\\:*?\"<>|\\p{Cntrl}]"), "_")
            .trim()
        if (name.isEmpty() || name == "." || name == "..") name = "book"
        if (!Regex("\\.[A-Za-z0-9]{1,8}$").containsMatchIn(name)) {
            val known = try {
                type ?: context.contentResolver.getType(uri)
            } catch (_: Exception) {
                null
            }
            when (known) {
                "text/plain" -> name += ".txt"
                "application/epub+zip" -> name += ".epub"
            }
        }
        if (name.length > 120) {
            val extension = Regex("\\.[A-Za-z0-9]{1,8}$").find(name)?.value ?: ""
            name = name.take(120 - extension.length) + extension
        }
        return name
    }
}
