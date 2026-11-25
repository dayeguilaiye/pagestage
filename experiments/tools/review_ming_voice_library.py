"""Check frozen Ming auditions on the desktop and build their local listening page."""
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
import re

import numpy as np
import soundfile as sf
import torch
from scipy.signal import resample_poly
import librosa
import whisper

from build_ming_voice_library import ASSETS, AUDITION_TEXT, CACHE, PREVIEW_SEED, ROOT

AGES = {'child': '儿童', 'teen': '青少年', 'youngAdult': '青年', 'middleAged': '中年', 'senior': '老年'}
GENDERS = {'female': '女声', 'male': '男声'}


def listening_page(output, rows):
    esc = html.escape
    groups = []
    mixes = output / '分组连听'
    mixes.mkdir(exist_ok=True)
    for age, title in AGES.items():
        cards = []
        sections = []
        clips = []
        offset = 0
        for item in rows:
            if item['ageGroup'] != age:
                continue
            wave, rate = sf.read(output / item['file'], dtype='int16')
            sections.append({'name': item['name'], 'start': offset / rate})
            silence = np.zeros(rate // 2, dtype=np.int16)
            clips.extend([wave, silence])
            offset += len(wave) + len(silence)
            cards.append(f'''<article data-gender="{item['gender']}" data-narrator="{int(item['narratorCandidate'])}">
<h3>{esc(item['name'])}<small>{GENDERS[item['gender']]}{' · 旁白候选' if item['narratorCandidate'] else ''}</small></h3>
<p>{esc(item['description'])}</p><audio controls preload="none" aria-label="{esc(item['name'])}" src="{esc(item['file'], quote=True)}"></audio></article>''')
        if cards:
            mix = mixes / f'{title}.wav'
            sf.write(mix, np.concatenate(clips[:-1]), rate, subtype='PCM_16')
            cues = esc(json.dumps(sections,ensure_ascii=False), quote=True)
            groups.append(f'''<section><h2>{title}</h2><details><summary>连听本组 {len(cards)} 个声音</summary>
<audio controls preload="none" data-cues="{cues}" src="{mix.relative_to(output)}"></audio>
<output aria-label="正在试听的声音"></output></details><div class="grid">'''+''.join(cards)+'</div></section>')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>PageStage · Ming 音色试听</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#faf8f3;color:#252c28;font:16px/1.55 "PingFang SC",system-ui,sans-serif}main{max-width:1080px;margin:auto;padding:36px 24px 72px}
h1,h2{font-family:"Songti SC",serif}h1{font-size:clamp(32px,5vw,54px);margin:0}h2{font-size:27px;margin:36px 0 0}h3{margin:0;font-size:21px}small{font-size:13px;color:#535e55;font-weight:400;margin-left:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(310px,100%),1fr));gap:0 32px}article{border-top:1px solid #c1c8bf;padding:16px 0;display:flex;flex-direction:column}
article p{margin:6px 0 12px;flex:1}audio{width:100%}nav{display:flex;gap:8px;flex-wrap:wrap;margin:24px 0}button{border:1px solid #9ba79d;background:transparent;color:inherit;border-radius:20px;padding:5px 16px;font:inherit;cursor:pointer}
button[aria-pressed=true]{background:#234437;color:white}button:focus-visible{outline:3px solid #ab651c}[hidden]{display:none}
details{margin:4px 0 12px}summary{cursor:pointer;color:#315642}details audio{max-width:440px;vertical-align:middle;margin:8px 10px 0 0}output{font-weight:600}
</style><main><h1>Ming 音色试听</h1>'''
    page += f'<p>{len(rows)} 种普通话预设，按设计年龄分组。每个声音用固定的音色特征，以中性情绪朗读同一句话。</p><p>“{esc(AUDITION_TEXT)}”</p>'
    page += '<nav aria-label="筛选音色">'+''.join(
        f'<button data-filter="{k}" aria-pressed="{str(k=="all").lower()}">{v}</button>'
        for k,v in [('all','全部'),('female','女声'),('male','男声'),('narrator','旁白候选')])+'</nav>'
    page += ''.join(groups)+'''</main><script>
document.querySelectorAll('button').forEach(b=>b.onclick=()=>{
  const f=b.dataset.filter;
  document.querySelectorAll('button').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));
  document.querySelectorAll('article').forEach(a=>{
    a.hidden=!(f==='all'||a.dataset.gender===f||(f==='narrator'&&a.dataset.narrator==='1'));
    if(a.hidden)a.querySelector('audio').pause();
  });
  document.querySelectorAll('section').forEach(s=>{
    s.hidden=!s.querySelector('article:not([hidden])');
    s.querySelector('details').hidden=f!=='all';
    if(f!=='all')s.querySelector('details audio').pause();
  });
});
document.addEventListener('play',e=>{for(const a of document.querySelectorAll('audio'))if(a!==e.target)a.pause()},true);
for(const a of document.querySelectorAll('audio[data-cues]')){
  const marks=JSON.parse(a.dataset.cues);
  a.ontimeupdate=()=>{a.nextElementSibling.textContent=marks.filter(m=>m.start<=a.currentTime).at(-1)?.name||''};
}
</script></html>'''
    (output/'index.html').write_text(page, encoding='utf-8')


def normalized_text(text):
    simplified = text.translate(str.maketrans('們發', '们发'))
    return re.sub(r'[^\u4e00-\u9fff]', '', simplified)


def check_speech(audio, model):
    wave, rate = sf.read(audio, dtype='float32')
    divisor = math.gcd(rate, 16000)
    wave = resample_poly(wave, 16000 // divisor, rate // divisor).astype('float32')
    result = model.transcribe(
        wave, language='zh', fp16=False, temperature=0,
        condition_on_previous_text=False, verbose=None,
    )
    frequencies, voiced, _ = librosa.pyin(
        wave, fmin=60, fmax=650, sr=16000, frame_length=1024, hop_length=160,
    )
    pitch = frequencies[voiced]
    return {
        'transcript': result['text'].strip(),
        'median_f0_hz': round(float(np.median(pitch)), 1) if pitch.size else None,
    }


def closest_pairs(vectors, names):
    matrix = np.array(vectors)
    matrix = matrix / np.linalg.norm(matrix, axis=1, keepdims=True)
    cosine = matrix @ matrix.T
    pairs = [
        {'voices': [names[j], names[i]], 'cosine': round(float(cosine[i, j]), 4)}
        for i in range(len(names)) for j in range(i)
    ]
    return sorted(pairs, key=lambda pair: -pair['cosine'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--all-takes', action='store_true',
                        help='Also check alternative takes still in the working cache.')
    args = parser.parse_args()
    torch.set_num_threads(3)
    rows, designs, auditions = [], [], []
    model = None

    def check_take(folder):
        nonlocal model
        checks = folder / 'audition-qa.json'
        if not checks.exists():
            if model is None:
                checkpoint = ROOT / 'artifacts/models/whisper/small.pt'
                model = whisper.load_model(str(checkpoint), device='cpu')
            metrics = check_speech(folder / 'audition.wav', model)
            checks.write_text(json.dumps(metrics, ensure_ascii=False))
            print(folder.parent.name, folder.name, metrics, flush=True)
        return json.loads(checks.read_text())

    for voice in json.loads((ASSETS / 'voices.json').read_text()):
        if voice.get('legacy'):
            continue
        ident = voice['id']
        manifest = CACHE / f'{ident}.json'
        if not manifest.exists():
            continue
        row = json.loads(manifest.read_text())
        folder = CACHE / ident / row['key']
        if args.all_takes:
            for take in folder.parent.glob('*/record.json'):
                check_take(take.parent)
        audio = args.output / row['file']
        assert hashlib.sha256(audio.read_bytes()).hexdigest() == row['sample_sha256']
        speaker = (ASSETS / f'{ident}.bin').read_bytes()
        assert len(speaker) == 896 * 4
        assert hashlib.sha256(speaker).hexdigest() == row['speaker_sha256']
        designs.append(torch.load(folder / 'speaker.pt', map_location='cpu',
                                  weights_only=True).numpy().ravel())
        auditions.append(np.load(folder / 'audition-embedding.npy'))
        metrics = check_take(folder)
        rows.append({
            **voice, **row, **metrics,
            'transcript_matches': normalized_text(metrics['transcript']) == normalized_text(AUDITION_TEXT),
        })

    if rows:
        names = [row['name'] for row in rows]
        report = {
            'text': AUDITION_TEXT, 'emotion': '中性', 'steps': 10, 'seed': PREVIEW_SEED,
            'model': 'inclusionAI/Ming-3.0-tts-0.5b', 'voices': rows,
            'design_pairs': closest_pairs(designs, names),
            'audition_pairs': closest_pairs(auditions, names),
        }
        (CACHE / 'quality.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
        listening_page(args.output, rows)
        print('Reviewed:', len(rows), 'Closest auditions:', report['audition_pairs'][:5], flush=True)


if __name__ == '__main__':
    main()
