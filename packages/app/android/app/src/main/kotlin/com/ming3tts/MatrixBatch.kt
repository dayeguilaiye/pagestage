package com.ming3tts

import org.json.JSONObject
import java.util.concurrent.Phaser
import java.util.concurrent.atomic.AtomicReference

const val PAIR_FLOW = "flow_r4b_s10_pair_wfp16.tflite"

fun pairedInputs(a: Array<FloatArray>, b: Array<FloatArray>) =
    arrayOf(a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3])

enum class PairedLm(val file: String, io: Pair<Int, Int>) {
    PROJECTIONS("lm2_epsdiv_step_pair_wfp16.tflite", 8 to 5),
    INDEPENDENT("lm2_epsdiv_step_twin_wfp16.tflite", 12 to 6);

    val signature = mapOf("step" to io)

    fun inputs(a: Array<FloatArray>, b: Array<FloatArray>): Array<FloatArray> =
        if (this == INDEPENDENT) a + b
        else arrayOf(a[0] + b[0], a[1] + b[1], a[2] + b[2], a[3] + b[3], a[4], a[5], b[4], b[5])

    fun lane(result: Array<FloatArray?>, lane: Int): Array<FloatArray?> {
        if (this == INDEPENDENT) return result.copyOfRange(3 * lane, 3 * (lane + 1))
        val z = checkNotNull(result[0])
        check(z.size == 2 * HostMath.HIDDEN)
        return arrayOf(z.copyOfRange(lane * HostMath.HIDDEN, (lane + 1) * HostMath.HIDDEN),
            result[1 + 2 * lane]!!, result[2 + 2 * lane]!!)
    }
}

fun tripleInputs(sig: String, jobs: List<Array<FloatArray>>): Array<FloatArray> {
    val (a, b, c) = jobs
    fun rows(i: Int): FloatArray {
        val n = a[i].size
        return FloatArray(3 * n).also {
            a[i].copyInto(it)
            b[i].copyInto(it, n)
            c[i].copyInto(it, 2 * n)
        }
    }
    return when (sig) {
        "flow" -> arrayOf(rows(0), rows(1), rows(2), a[3])
        "step" -> arrayOf(rows(0), rows(1), rows(2), rows(3), a[4], a[5], b[4], b[5], c[4], c[5])
        else -> error("Unknown batched signature $sig")
    }
}

fun batchLane(sig: String, out: Array<FloatArray?>, lane: Int, count: Int): Array<FloatArray?> {
    val width = if (sig == "flow") HostMath.LATENT else HostMath.HIDDEN
    val packed = checkNotNull(out[0])
    check(packed.size == count * width)
    val row = packed.copyOfRange(lane * width, (lane + 1) * width)
    return if (sig == "flow") arrayOf(row) else arrayOf(row, out[1 + 2 * lane]!!, out[2 + 2 * lane]!!)
}

/** Engines borrow one set of graphs. Each graph owns reusable LiteRT input and output buffers. */
class CountedGraph(val device: Graph) : GraphCall {
    private val writeMs = ThreadLocal<Double>()
    private var calls = 0
    private var nanos = 0L
    private var inputMs = 0.0
    private var runMs = 0.0
    private var readMs = 0.0
    override val compileMs get() = device.compileMs
    override val lastWriteMs get() = writeMs.get() ?: 0.0

    @Synchronized override fun call(sig: String, inputs: Array<FloatArray>, read: IntArray?): Array<FloatArray?> {
        val start = System.nanoTime()
        val output = device.call(sig, inputs, read)
        nanos += System.nanoTime() - start
        calls++
        writeMs.set(device.lastWriteMs)
        inputMs += device.lastWriteMs
        runMs += device.lastRunMs
        readMs += device.lastReadMs
        return output
    }

    fun reset() {
        calls = 0
        nanos = 0
        inputMs = 0.0
        runMs = 0.0
        readMs = 0.0
    }
    fun metrics() = JSONObject().put("calls", calls).put("ms", nanos / 1e6)
        .put("writeMs", inputMs).put("runMs", runMs).put("readMs", readMs)
    override fun close() = Unit
}

/** The remaining sentences move to the matching, smaller graph after a lane finishes. */
class BatchedStep(private val signature: String, private val solo: CountedGraph, private val pair: CountedGraph,
                           private val lmVariant: PairedLm? = null, lanes: Int = 2, private val triple: CountedGraph? = null) {
    private val inputs = arrayOfNulls<Array<FloatArray>>(lanes)
    private val outputs = arrayOfNulls<Array<FloatArray?>>(lanes)
    private val writeMs = DoubleArray(lanes)
    private val error = AtomicReference<Throwable>()
    private val phases = object : Phaser(lanes) {
        override fun onAdvance(phase: Int, registeredParties: Int): Boolean {
            if (registeredParties == 0) return true
            try {
                val active = inputs.indices.filter { inputs[it] != null }
                val jobs = active.map { inputs[it]!! }
                val graph = when (active.size) {
                    1 -> solo
                    2 -> pair
                    3 -> checkNotNull(triple)
                    else -> error("No active sentences")
                }
                val result = when (active.size) {
                    1 -> graph.call(signature, jobs.single())
                    2 -> graph.call(signature, lmVariant?.inputs(jobs[0], jobs[1]) ?: pairedInputs(jobs[0], jobs[1]))
                    else -> graph.call(signature, tripleInputs(signature, jobs))
                }
                for ((row, lane) in active.withIndex()) {
                    outputs[lane] = when {
                        active.size == 1 -> result
                        lmVariant != null && active.size == 2 -> lmVariant.lane(result, row)
                        else -> batchLane(signature, result, row, active.size)
                    }
                    writeMs[lane] = graph.lastWriteMs
                }
                return false
            } catch (t: Throwable) {
                error.compareAndSet(null, t)
                return true
            }
        }
    }

    fun run(lane: Int, tensors: Array<FloatArray>): Array<FloatArray?> {
        inputs[lane] = tensors
        phases.arriveAndAwaitAdvance()
        error.get()?.let { throw it }
        return checkNotNull(outputs[lane])
    }

    fun end(lane: Int) {
        inputs[lane] = null
        phases.arriveAndDeregister()
    }

    fun lastWriteMs(lane: Int) = writeMs[lane]

    fun abort(t: Throwable) {
        error.compareAndSet(null, t)
        phases.forceTermination()
    }
}

class SentencePort(private val lane: Int, private val signature: String, private val solo: CountedGraph) : GraphCall {
    var group: BatchedStep? = null
    override val compileMs get() = solo.compileMs
    override val lastWriteMs get() = group?.lastWriteMs(lane) ?: solo.lastWriteMs

    override fun call(sig: String, inputs: Array<FloatArray>, read: IntArray?): Array<FloatArray?> {
        val current = group ?: return solo.call(sig, inputs, read)
        check(sig == signature && read == null)
        return current.run(lane, inputs)
    }
    override fun close() = Unit
}
