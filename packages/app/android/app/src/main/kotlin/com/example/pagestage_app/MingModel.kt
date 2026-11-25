package com.example.pagestage_app

import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.AtomicFile
import android.util.Log
import com.ming3tts.*
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

/** The app process owns the NPU runtime. Reattaching Flutter or reopening settings only observes it. */
internal class MingModel private constructor(private val context: Context) {
    companion object {
        @Volatile private var instance: MingModel? = null
        fun get(context: Context): MingModel = instance ?: synchronized(this) {
            instance ?: MingModel(context.applicationContext).also { instance = it }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor { Thread(it, "pagestage-ming") }
    private fun assetText(name: String) = context.assets.open("ming/$name").bufferedReader().use { it.readText() }
    private val manifest = JSONObject(assetText("files.json"))
    private val assets = manifest.getJSONArray("models").let { rows -> List(rows.length()) { rows.getJSONObject(it) } }
    // Voice profiles are inputs to the shared graphs and do not affect their cache identity.
    private val voices = JSONArray(assetText("voices.json")).let { rows ->
        List(rows.length()) { index ->
            val row = rows.getJSONObject(index)
            val id = row.getString("id")
            require(id.matches(Regex("[a-zA-Z0-9_-]+")))
            fun strings(key: String) = (row.optJSONArray(key) ?: JSONArray()).let { list ->
                List(list.length(), list::getString)
            }
            mapOf("id" to id, "name" to row.optString("name", id),
                "description" to row.getString("description"), "gender" to row.getString("gender"),
                "languages" to strings("languages"), "ageGroup" to row.optString("ageGroup", "unknown"),
                "styles" to strings("styles"), "narratorCandidate" to row.optBoolean("narratorCandidate"),
                "legacy" to row.optBoolean("legacy"))
        }
    }
    private val voiceIds = voices.map { it.getValue("id") as String }.toSet()
    private val speakerRows = java.util.concurrent.ConcurrentHashMap<String, FloatArray>()
    private val weights = JSONObject(assetText("initialization.json"))
    private val modules = MingProfile.modules
    private val revision = manifest.getString("revision")
    private val models = File(context.noBackupFilesDir, "ming/$revision")
    private val cacheRoot = File(context.cacheDir, "ming/${revision}-${Build.FINGERPRINT.hashCode()}")
    private val compiled = File(cacheRoot, "compiled")
    private val checkpoint = AtomicFile(File(cacheRoot, "progress.json"))
    private val compatible = Build.VERSION.SDK_INT >= 31 && Build.SOC_MODEL.startsWith("SM8650", ignoreCase = true)
    private val bundled = context.assets.list("ming").orEmpty().toSet().let { names ->
        assets.all { it.getString("name") in names } && File(context.applicationInfo.nativeLibraryDir, "libLiteRtDispatch_Qualcomm.so").isFile
    }
    val available = compatible && bundled
    private var savedCount = if (available) restoredCount() else 0
    @Volatile private var state = snapshot(if (savedCount == modules.size) "ready" else "idle", savedCount)
    private var runtime: MingPairRuntime? = null
    private var observer: ((Map<String, Any>) -> Unit)? = null

    private fun restoredCount(): Int {
        return try {
            val saved = JSONObject(checkpoint.readFully().toString(Charsets.UTF_8))
            val files = saved.getJSONObject("cache")
            val modelFilesPresent = assets.all { File(models, it.getString("name")).length() == it.getLong("size") }
            if (!modelFilesPresent || files.length() == 0 || files.keys().asSequence().any {
                    !File(compiled, it).isFile || File(compiled, it).length() != files.getLong(it)
                }) 0 else saved.getInt("done").coerceIn(0, modules.size)
        } catch (_: Exception) { 0 }
    }

    private fun saveCount(done: Int) {
        val files = JSONObject()
        compiled.walkTopDown().filter { it.isFile && it.length() > 0 }.forEach {
            files.put(it.relativeTo(compiled).path, it.length())
        }
        check(files.length() > 0) { "The NPU compiler did not persist its result" }
        val stream = checkpoint.startWrite()
        try {
            stream.write(JSONObject().put("done", done).put("cache", files).toString().toByteArray())
            checkpoint.finishWrite(stream)
        } catch (error: Throwable) {
            checkpoint.failWrite(stream)
            throw error
        }
        savedCount = done
    }

    private fun snapshot(phase: String, done: Int, detail: String = ""): Map<String, Any> {
        val total = modules.sumOf { weights.getDouble(it.id) }
        val fraction = modules.take(done).sumOf { weights.getDouble(it.id) } / total
        val percent = if (done == modules.size) 100 else Math.round(fraction * 100).toInt().coerceAtMost(99)
        return mapOf("available" to available, "phase" to phase, "done" to done, "total" to modules.size,
            "percent" to percent, "detail" to detail)
    }
    fun status() = state + ("voices" to voices)
    fun listen(callback: ((Map<String, Any>) -> Unit)?) { observer = callback; callback?.invoke(state) }
    private fun publish(phase: String, detail: String = "") {
        val next = snapshot(phase, savedCount, detail)
        state = next
        main.post { observer?.invoke(next) }
    }

    private fun stageFiles() {
        models.mkdirs()
        val buffer = ByteArray(1 shl 20)
        for (entry in assets) {
            val name = entry.getString("name")
            val target = File(models, name)
            if (target.isFile && target.length() == entry.getLong("size")) continue
            val partial = File(models, "$name.partial")
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                context.assets.open("ming/$name").use { source ->
                    partial.outputStream().buffered().use { to ->
                        while (true) {
                            val read = source.read(buffer)
                            if (read < 0) break
                            to.write(buffer, 0, read)
                            digest.update(buffer, 0, read)
                        }
                    }
                }
                val hex = digest.digest().joinToString("") { "%02x".format(it) }
                check(partial.length() == entry.getLong("size") && hex == entry.getString("sha256")) { "Invalid install-time asset $name" }
                check(partial.renameTo(target)) { "Cannot store $name" }
            } finally { partial.delete() }
        }
    }

    private fun accelerators(): Accelerators {
        compiled.mkdirs()
        val local = object : ContextWrapper(context) { override fun getCacheDir() = compiled }
        return Accelerators.create(local)
    }

    @Synchronized fun initialize(): Map<String, Any> {
        check(available) { "Ming is unavailable for this installation" }
        if (state["phase"] in setOf("copying", "compiling", "ready")) return state
        publish("copying")
        worker.execute {
            try {
                stageFiles()
                accelerators().use { acc ->
                    check(acc.npu) { acc.npuNote }
                    for (i in savedCount until modules.size) {
                        val m = modules[i]
                        publish("compiling", m.id)
                        val start = SystemClock.elapsedRealtime()
                        Graph(acc, File(models, m.file), Backend.NPU, m.signatures, true).use { }
                        saveCount(i + 1)
                        Log.i("PageStageMing", "module=${m.id} done=$savedCount/7 percent=${snapshot("compiling", savedCount)["percent"]} elapsedMs=${SystemClock.elapsedRealtime()-start}")
                    }
                }
                publish("ready")
            } catch (e: Throwable) {
                Log.e("PageStageMing", "Preparation failed", e)
                publish("error", if (e is IOException) "storage" else "compile")
            }
        }
        return state
    }

    private fun speaker(id: String): FloatArray {
        val bytes = context.assets.open("ming/$id.bin").use { it.readBytes() }
        require(bytes.size == HostMath.HIDDEN * 4)
        return FloatArray(HostMath.HIDDEN).also { ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer().get(it) }
    }

    fun synthesize(lines: List<MingLine>, finish: (Result<List<ByteArray>>) -> Unit) {
        val lengths = lines.map { it.text.codePointCount(0, it.text.length) }
        Log.i("PageStageMing", "synthesize phase=${state["phase"]} chars=$lengths")
        require(lines.size in 1..2) { "Invalid batch size" }
        require(lines.none { it.text.isBlank() }) { "Blank synthesis input" }
        require(lines.all { it.voice in voiceIds }) { "Unknown voice binding" }
        check(state["phase"] == "ready") { "Initialize Ming in settings" }
        worker.execute {
            val start = SystemClock.elapsedRealtime()
            val result = runCatching {
                val engine = runtime ?: MingPairRuntime(models, accelerators()) { id ->
                    speakerRows.computeIfAbsent(id, ::speaker)
                }.also { runtime = it }
                engine.synthesize(lines)
            }
            if (result.isFailure) {
                Log.e("PageStageMing", "Synthesis failed", result.exceptionOrNull())
                runtime?.close()
                runtime = null
            } else {
                Log.i("PageStageMing", "synthesized samples=${result.getOrThrow().map { it.size / 2 }} elapsedMs=${SystemClock.elapsedRealtime()-start}")
            }
            main.post { finish(result) }
        }
    }
}
