package com.ming3tts

import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.Closeable
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.math.roundToInt

data class MingModule(val id: String, val file: String, val signatures: Map<String, Pair<Int, Int>>)
data class MingLine(val text: String, val voice: String, val emotion: String)

object MingProfile {
    val placement = Placement.parse(Placement.FAST)
    val modules = placement.roles.map { (id, spec) -> MingModule(id, spec.file, Graph.signaturesOf(id)) } +
        listOf(MingModule("flowPair", PAIR_FLOW, Graph.FLOW),
            MingModule("stepPair", PairedLm.PROJECTIONS.file, PairedLm.PROJECTIONS.signature))
}

/** One set of NPU weights, two independent sentence states, and a single-row tail when a line stops. */
class MingPairRuntime(private val dir: File, private val acc: Accelerators,
                      private val speakerFor: (String) -> FloatArray) : Closeable {
    private val graphs = linkedMapOf<String, CountedGraph>()
    private val engines = mutableListOf<MingEngine>()
    private val workers = Executors.newFixedThreadPool(2)
    private val flowPorts = mutableListOf<SentencePort>()
    private val stepPorts = mutableListOf<SentencePort>()
    init {
        try {
            check(acc.npu) { acc.npuNote }
            for (module in MingProfile.modules) {
                graphs[module.id] = CountedGraph(Graph(acc, File(dir, module.file), Backend.NPU, module.signatures, true))
            }
            for (lane in 0..1) {
                flowPorts += SentencePort(lane, "flow", graphs.getValue("flow"))
                stepPorts += SentencePort(lane, "step", graphs.getValue("step"))
                engines += MingEngine(dir, MingProfile.placement, graphFactory = { role, _, _ ->
                    when (role) {
                        "flow" -> flowPorts[lane]
                        "step" -> stepPorts[lane]
                        else -> graphs.getValue(role)
                    }
                })
            }
        } catch (error: Throwable) {
            close()
            throw error
        }
    }

    fun synthesize(lines: List<MingLine>): List<ByteArray> {
        require(lines.size in 1..2)
        if (lines.size == 1) return listOf(render(0, lines.single()))
        val flow = BatchedStep("flow", graphs.getValue("flow"), graphs.getValue("flowPair"))
        val step = BatchedStep("step", graphs.getValue("step"), graphs.getValue("stepPair"), PairedLm.PROJECTIONS)
        flowPorts.forEach { it.group = flow }
        stepPorts.forEach { it.group = step }
        try {
            graphs.values.forEach { it.reset() }
            val jobs = lines.mapIndexed { lane, line ->
                workers.submit<ByteArray> {
                    try { render(lane, line) }
                    catch (t: Throwable) { flow.abort(t); step.abort(t); throw t }
                    finally { flow.end(lane); step.end(lane) }
                }
            }
            val finished = jobs.map { runCatching { it.get() } }
            Log.i("PageStageMing", "matrix pair flowCalls=${graphs.getValue("flowPair").metrics().getInt("calls")} stepCalls=${graphs.getValue("stepPair").metrics().getInt("calls")}")
            return finished.map { it.getOrThrow() }
        } finally {
            flowPorts.forEach { it.group = null }
            stepPorts.forEach { it.group = null }
        }
    }

    private fun render(lane: Int, line: MingLine): ByteArray {
        val speaker = speakerFor(line.voice)
        val request = Request(line.text, "", null, VoiceFile("", 0, FloatArray(0), FloatArray(0), speaker),
            PromptContract.DEFAULT_TTS_PROMPT, PromptContract.emotionInstruction(line.emotion))
        val output = ByteArrayOutputStream()
        val stats = engines[lane].generate(request, MingEngine.gaussianNoise(1895), { pcm ->
            val bytes = ByteBuffer.allocate(pcm.size * 2).order(ByteOrder.LITTLE_ENDIAN)
            for (value in pcm) {
                check(value.isFinite())
                bytes.putShort((value.coerceIn(-1f, 1f) * 32767).roundToInt().toShort())
            }
            output.write(bytes.array())
        })
        check(stats.stopped && output.size() > 0) { "Ming reached the sentence context limit" }
        return output.toByteArray()
    }

    override fun close() {
        workers.shutdown()
        engines.forEach { it.close() }
        graphs.values.forEach { it.device.close() }
        acc.close()
    }
}
