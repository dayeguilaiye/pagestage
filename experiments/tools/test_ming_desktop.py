#!/usr/bin/env python3
"""Reproducible Ming 0.5B desktop listening suite, using local public weights."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import platform
import random
import shutil
import subprocess
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "vendor/Ming-3.0-tts"
RUNTIME = ROOT / "artifacts/ming-desktop/runtime"
OUTPUT = ROOT / "artifacts/ming-desktop/listening"
MODEL = ROOT / "artifacts/models/Ming-3.0-tts-0.5b"


def prepare_runtime():
    """Keep upstream intact; record the small FP32/MPS portability patch."""
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for path in SOURCE.iterdir():
        if path.name.startswith("."):
            continue
        target = RUNTIME / path.name
        if path.is_dir():
            shutil.copytree(path, target, dirs_exist_ok=True)
        elif path.is_file():
            shutil.copy2(path, target)
    for name in ("ming_tts.py", "modeling_bailingmm.py"):
        path = RUNTIME / name
        text = path.read_text().replace("torch.bfloat16", "torch.float32")
        text = text.replace("import torch\n", "import torch\nfrom contextlib import nullcontext\n", 1)
        text = text.replace("torch.autocast(device_type='cuda', dtype=torch.float32)", "nullcontext()")
        path.write_text(text)
    path = RUNTIME / "audio_tokenizer/istft.py"
    text = path.read_text()
    needle = "        x_pred = x_pred.transpose(1, 2)"
    assert text.count(needle) == 1
    text = text.replace(needle, """        # MPS has limited complex FFT support. Only waveform reconstruction
        # runs on CPU; the learned decoder projection stays on MPS.
        if x_pred.device.type == 'mps':
            x_pred = x_pred.cpu()
            self.istft.cpu()
        x_pred = x_pred.transpose(1, 2)""")
    path.write_text(text)
    patches = []
    for name in ("ming_tts.py", "modeling_bailingmm.py", "audio_tokenizer/istft.py"):
        result = subprocess.run(["diff", "-u", str(SOURCE / name), str(RUNTIME / name)], capture_output=True, text=True)
        patches.append(result.stdout)
    (OUTPUT / "macos-fp32.patch").write_text("\n".join(patches))


def cases():
    zh = "雨停了，街角的咖啡馆亮起了灯。别着急，我们还有时间，慢慢走过去就好。"
    en = "The rain has stopped, and the little cafe on the corner is still open. Take your time. We can walk there together."
    emotion = "你终于回来了。我等了你这么久，还以为你再也不会出现了。"
    reference = str(SOURCE / "data/wavs/emotion_prompt.wav")
    rows = []
    for ident, title, voice, text in (
        ("01_zh_female", "中文女声 · 灵小柔", "灵小柔", zh),
        ("02_zh_male", "中文男声 · 灵楷", "灵楷", zh),
        ("03_en_female", "英文女声 · US_Emma", "US_Emma", en),
        ("04_en_male", "英文男声 · UK_George", "UK_George", en),
    ):
        rows.append(dict(id=ident, title=title, task="IP", text=text, controls={"ip": voice}, use_zero_spk_emb=True))
    for idx, mood in enumerate(("中性", "高兴", "愤怒"), 5):
        rows.append(dict(id=f"{idx:02d}_emotion_{idx-5}", title=f"同文同参考 · {mood}", task="EMOTION", text=emotion,
                         controls={"emotion": mood}, prompt_wav_path=reference, use_spk_emb=True))
    rows.append(dict(id="08_directed", title="导演指令 · 轻声悬疑", task="FREEFORM",
                     text="先别开灯。你听，走廊里好像有人。等脚步声过去，我们再慢慢打开这扇门。",
                     instruction="用年轻女性的声音，轻声讲述一段悬疑故事。语速稍慢，压低音量，带一点紧张和警觉，停顿自然，不要夸张。", use_zero_spk_emb=True))
    rows.append(dict(id="09_clone", title="参考音色克隆 · 官方 lingguang 样本", task="TTS", language_id="Chinese", text=zh,
                     prompt_wav_path=str(SOURCE / "data/voice_presets/voice_audio/lingguang.wav"),
                     prompt_text="诶，你今天有空吗？我们能不能聊聊这件事啊？", use_spk_emb=True))
    return rows


def save_report(report):
    (OUTPUT / "results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))
    sections = []
    for row in report["results"]:
        safe = html.escape
        if row["status"] == "ok":
            body = f'<audio controls preload="none" src="{safe(row["file"])}"></audio>'
            body += f'<p>音频 {row["audio_seconds"]:.2f} 秒 · 生成 {row["generation_seconds"]:.2f} 秒 · RTF {row["rtf"]:.2f}</p>'
            if "reference_file" in row:
                body += f'<p>用于克隆/情绪测试的原始参考：</p><audio controls preload="none" src="{safe(row["reference_file"])}"></audio>'
        else:
            body = f'<pre>{safe(row["error"])}</pre>'
        sections.append(f'<section><h2>{safe(row["title"])}</h2><p>{safe(row["request"]["text"])}</p>{body}<details><summary>参数</summary><pre>{safe(json.dumps(row["request"], ensure_ascii=False, indent=2))}</pre></details></section>')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Ming 0.5B 本地试听</title><style>body{font:17px/1.65 system-ui;max-width:850px;margin:36px auto;padding:0 20px;color:#222;background:#faf9f6}section{border-top:1px solid #ccc;padding:18px 0}h2{font-size:21px}audio{width:100%}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:13px}</style><h1>Ming-3.0-TTS 0.5B 本地试听</h1><p>官方完整权重 · macOS / PyTorch FP32 · 本地生成。RTF = 生成耗时 ÷ 音频时长；计时不含模型加载。情绪三条使用相同文本、参考与种子，属于不同情绪条件。这里测整段音质，未测首包流式延迟。</p><p><a href="all_samples.wav">合并试听</a> · <a href="results.json">完整参数与结果</a></p>'''
    (OUTPUT / "index.html").write_text(page + "\n".join(sections) + "</html>")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", default="mps", choices=("mps", "cpu"))
    parser.add_argument("--only", help="Comma-separated case IDs; default all nine")
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")
    os.environ.setdefault("HF_HUB_OFFLINE", "1")
    prepare_runtime()
    sys.path.insert(0, str(RUNTIME))
    import numpy as np
    import soundfile as sf
    import torch
    from ming_tts import MingTTS

    torch.set_num_threads(6)
    report = {"model": "inclusionAI/Ming-3.0-tts-0.5b", "date": "2026-11-04",
              "source_commit": subprocess.check_output(["git", "-C", str(SOURCE), "rev-parse", "HEAD"], text=True).strip(),
              "system": platform.platform(), "device": args.device, "precision": "float32",
              "torch": torch.__version__, "flow_steps": 10, "seed": 1895,
              "text_normalization": False, "streaming": False, "results": []}
    metadata = MODEL / ".cache/huggingface/download/model.safetensors.metadata"
    if metadata.exists():
        report["checkpoint_metadata"] = metadata.read_text().splitlines()
    provenance = MODEL / "download-provenance.json"
    if provenance.exists():
        report["checkpoint_provenance"] = json.loads(provenance.read_text())
    report["hardware"] = subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
    report["physical_memory_bytes"] = int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True))
    if args.resume and (OUTPUT / "results.json").exists():
        previous = json.loads((OUTPUT / "results.json").read_text())
        report["results"] = previous["results"]
    start = time.perf_counter()
    print("Loading official Ming model on", args.device, flush=True)
    tts = MingTTS(str(MODEL), device=args.device, text_normalization=False, cache_prompts=False)
    if args.device == "mps":
        torch.mps.synchronize()
    report["model_load_seconds"] = time.perf_counter() - start
    print("Model loaded:", report["model_load_seconds"], flush=True)
    selected = set(args.only.split(",")) if args.only else None
    for case in cases():
        if selected and case["id"] not in selected:
            continue
        if args.resume and any(r["id"] == case["id"] and r["status"] == "ok" for r in report["results"]):
            continue
        random.seed(1895)
        np.random.seed(1895)
        torch.manual_seed(1895)
        if args.device == "mps":
            torch.mps.manual_seed(1895)
        request = {key: value for key, value in case.items() if key not in ("id", "title")}
        request.update(cfg=2.0, sigma=0.25, temperature=0.0, raw_text=True, trim_silence=True, max_decode_steps=1000)
        row = {"id": case["id"], "title": case["title"], "request": request, "status": "running", "device": args.device, "precision": "float32", "seed": 1895}
        if "prompt_wav_path" in request:
            reference_path = Path(request["prompt_wav_path"])
            target = OUTPUT / ("reference_" + reference_path.name)
            shutil.copy2(reference_path, target)
            row["reference_file"] = target.name
        report["results"] = [r for r in report["results"] if r["id"] != case["id"]]
        print("START", case["id"], case["title"], flush=True)
        start = time.perf_counter()
        try:
            waveform = tts.synthesize(**request).detach().cpu().float().numpy().reshape(-1)
            if args.device == "mps":
                torch.mps.synchronize()
            elapsed = time.perf_counter() - start
            assert len(waveform) > 0 and np.isfinite(waveform).all(), "Empty or nonfinite waveform"
            peak = float(np.abs(waveform).max())
            rms = float(np.sqrt(np.mean(waveform ** 2)))
            assert rms > 0.00001, "Near-silent waveform"
            output = OUTPUT / (case["id"] + ".wav")
            sf.write(output, waveform, tts.sample_rate, subtype="PCM_16")
            row.update(status="ok", file=output.name, generation_seconds=elapsed,
                       audio_seconds=len(waveform) / tts.sample_rate, sample_rate=tts.sample_rate,
                       rtf=elapsed / (len(waveform) / tts.sample_rate), peak=peak, rms=rms,
                       clipped_fraction=float(np.mean(np.abs(waveform) >= 1)),
                       sha256=hashlib.sha256(output.read_bytes()).hexdigest())
            print("DONE", case["id"], json.dumps({k: row[k] for k in ("audio_seconds", "generation_seconds", "rtf", "rms")}), flush=True)
        except Exception:
            row.update(status="error", error=traceback.format_exc(), generation_seconds=time.perf_counter() - start)
            print(row["error"], flush=True)
        report["results"].append(row)
        save_report(report)
        if row["status"] == "error":
            raise RuntimeError(f"Stopped at {case['id']}; see results.json")
    clips = []
    for row in sorted(report["results"], key=lambda x: x["id"]):
        if row["status"] == "ok":
            data, rate = sf.read(OUTPUT / row["file"])
            clips.extend([data, np.zeros(int(rate * 0.8))])
    if clips:
        sf.write(OUTPUT / "all_samples.wav", np.concatenate(clips), rate, subtype="PCM_16")
    save_report(report)
    print("Listening page:", OUTPUT / "index.html", flush=True)


if __name__ == "__main__":
    main()
