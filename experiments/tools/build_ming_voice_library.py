"""Design Mandarin voices locally, freeze each speaker row, and render comparable auditions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import sys
import zlib

from test_ming_desktop import MODEL, OUTPUT, ROOT, RUNTIME, prepare_runtime

ASSETS = ROOT.parent / 'packages/app/android/app/src/main/assets/ming'
CACHE = ROOT / 'artifacts/ming-presets-v1'
REFERENCE_TEXT = '风从窗边吹过，院子里的灯也亮了。我们先把门关上吧。'
AUDITION_TEXT = '天快亮了。等雨停了，我们就一起出发。'
PREVIEW_SEED = 1895


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--only', nargs='+', help='Generate specific preset IDs')
    parser.add_argument('--alternatives', type=Path,
                        help='JSON map of preset IDs to alternative design prompts. Keep takes in the working cache.')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault('HF_HUB_OFFLINE', '1')
    os.environ.setdefault('PYTORCH_ENABLE_MPS_FALLBACK', '1')
    if not (RUNTIME / 'ming_tts.py').exists():
        OUTPUT.mkdir(parents=True, exist_ok=True)
        prepare_runtime()
    sys.path.insert(0, str(RUNTIME))
    import numpy as np
    import soundfile as sf
    import torch
    import torchaudio
    from ming_tts import MingTTS
    from safetensors import safe_open

    torch.set_num_threads(6)
    tts = MingTTS(str(MODEL), device='mps', text_normalization=False, cache_prompts=False)
    with safe_open(str(MODEL / 'model.safetensors'), framework='pt') as tensors:
        weight = tensors.get_tensor('spk_head.weight').float()
        bias = tensors.get_tensor('spk_head.bias').float()
    to_16k = torchaudio.transforms.Resample(tts.sample_rate, 16000)

    def render(file, seed, **request):
        random.seed(seed)
        np.random.seed(seed)
        torch.manual_seed(seed)
        torch.mps.manual_seed(seed)
        wave = tts.synthesize(**request, cfg=2., sigma=.25, temperature=0.,
                              trim_silence=True, raw_text=True, max_decode_steps=400)
        samples = wave.detach().cpu().numpy().reshape(-1)
        if not (np.isfinite(samples).all() and np.sqrt(np.mean(samples**2)) > .002
                and 1 < len(samples) / tts.sample_rate < 25):
            raise ValueError(f'Invalid audio for {file}')
        temporary = file.with_suffix('.partial.wav')
        sf.write(temporary, samples, tts.sample_rate, subtype='PCM_16')
        temporary.replace(file)

    def embedding(file):
        wave, rate = sf.read(file, dtype='float32', always_2d=True)
        assert rate == tts.sample_rate and wave.shape[1] == 1
        return tts.spkemb_extractor(to_16k(torch.from_numpy(wave.T.copy())))

    voices = [r for r in json.loads((ASSETS / 'voices.json').read_text()) if not r.get('legacy')]
    alternatives = json.loads(args.alternatives.read_text()) if args.alternatives else None
    for index, voice in enumerate(voices, 1):
        ident = voice['id']
        if args.only and ident not in args.only:
            continue
        if alternatives is not None and ident not in alternatives:
            continue
        seed = (zlib.crc32(ident.encode()) + voice.get('designVariation', 0)) % (2**32)
        prompt = alternatives[ident] if alternatives is not None else voice.get('designPrompt', voice['description'])
        style = '说标准普通话。' + prompt
        key = hashlib.sha256(f'{ident}|{seed}|{style}|{REFERENCE_TEXT}|{AUDITION_TEXT}|{PREVIEW_SEED}'.encode()).hexdigest()[:16]
        folder = CACHE / ident / key
        folder.mkdir(parents=True, exist_ok=True)
        ref, raw, sample = folder / 'design.wav', folder / 'speaker.pt', folder / 'audition.wav'
        print(f'{index:02d}/{len(voices)} {ident} {voice["name"]}', flush=True)
        if not ref.exists():
            render(ref, seed, task='VOICE_DESIGN', text=REFERENCE_TEXT,
                   controls={'style': style}, use_zero_spk_emb=True)
        emb = embedding(ref)
        torch.save(emb, raw)
        row = torch.nn.functional.linear(emb, weight, bias).numpy().astype('<f4').reshape(-1)
        assert row.shape == (896,) and np.isfinite(row).all()
        if not sample.exists():
            render(sample, PREVIEW_SEED, task='EMOTION', text=AUDITION_TEXT,
                   controls={'emotion': '中性'}, spk_emb_path=str(raw), use_spk_emb=True)
        rendered_emb = embedding(sample).numpy().ravel()
        np.save(folder / 'audition-embedding.npy', rendered_emb)
        dest = args.output / f'{index:02d}-{voice["name"]}.wav'
        out, sr = sf.read(sample)
        record = {'id': ident, 'file': dest.name, 'key': key, 'design_seed': seed,
                  'seconds': round(len(out)/sr, 3), 'sample_rate': sr,
                  'peak': float(abs(out).max()), 'rms': float(np.sqrt(np.mean(out**2))),
                  'clipped_fraction': float(np.mean(np.abs(out) >= 32767/32768)),
                  'speaker_sha256': hashlib.sha256(row.tobytes()).hexdigest(),
                  'sample_sha256': hashlib.sha256(sample.read_bytes()).hexdigest()}
        (folder / 'record.json').write_text(json.dumps(record, ensure_ascii=False, indent=2))
        if alternatives is not None:
            print(f'  candidate {key}, {record["seconds"]:.2f}s', flush=True)
            continue
        if voice.get('speakerSha256', record['speaker_sha256']) != record['speaker_sha256']:
            raise ValueError(f'{ident} already identifies a different speaker row. Give the new voice its own ID.')
        (ASSETS / f'{ident}.bin').write_bytes(row.tobytes())
        dest.write_bytes(sample.read_bytes())
        (CACHE / f'{ident}.json').write_text(json.dumps(record, ensure_ascii=False, indent=2))
        print(f'  saved {dest.name}, {record["seconds"]:.2f}s', flush=True)


if __name__ == '__main__':
    main()
