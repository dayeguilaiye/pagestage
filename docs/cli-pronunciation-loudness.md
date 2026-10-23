# CLI 发音词典与响度

`synthesize` 和 `narrate` 自动读取本书 Cast 的发音词典。程序调用方将 `List<PronunciationEntry>` 传给 `Synthesizer.synthesize(lexicon: ...)`。原文、Script 区间和界面显示文本始终保留。

## 中文专有名词

词典只作用于 `language: zh`。条目包含完整名词与逐字拼音，例如：

```json
{"term":"长乐","pinyin":"chang2 le4"}
```

拼音用空格分隔，音节数与名词的 Unicode 字符数一致；支持数字声调与带声调字母（`cháng lè`），规范化为 1–5 的数字声调，5 表示轻声。`ü`、`u:`、`v` 统一使用 `v`。重复条目需给出相同读音；匹配词的拼音格式错误或音节数量不符时，在本章首个请求前报错。

匹配采用从左到右、同位置最长词优先。只有台词中实际匹配的条目进入请求；词典顺序、等价声调写法和无关词条不改变有效请求。服务商分块按原文码点计数，并避开已匹配名词内部。名词自身超过请求预算时，在本章首个请求前报错。

| 服务商 | 请求格式 |
| --- | --- |
| MiniMax | 原文加 `pronunciation_dict: {"tone":["长乐/(chang2)(le4)"]}` |
| 百炼 Qwen-Audio 3.1 的兼容预设 | `input.enable_ssml: true`，全文以 `<speak>` 包裹，名词写成 `<phoneme alphabet="py" ph="chang2 le4">长乐</phoneme>` |

百炼生成 SSML 时会转义原文的 XML 特殊字符，词典匹配和分块都在插入标记前完成。预算继续按源文本计数；600 码点是当前 HTTP 适配器的保守实现预算，带标记后的服务商实际限制仍需真实请求验证。

每条 utterance 返回 `pronunciationApplied`，表示已将读音指令提交给适配器。百炼设计音色等尚未声明拼音能力的绑定继续合成原文；中文台词匹配词典时额外返回 `pronunciationWarning` 说明能力限制。英文或没有匹配词条时保持普通文本请求。该字段表示请求处理状态，最终发音需要试听确认。

请求依据：[MiniMax 同步合成](https://platform.minimax.io/docs/api-reference/speech-t2a-http)、[百炼 HTTP 接口](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-http-api)、[百炼 SSML](https://www.alibabacloud.com/help/en/model-studio/ssml-latex-user-guide)（2026-10-23 核对）。

## 统一响度

每个逻辑 utterance 的服务商分块先拼接，再对整段施加一个固定增益，最后加入台词间停顿。默认目标为 **-20 LUFS**，最大提升 **12 dB**，样本峰值上限 **-1 dBFS**。这些是小说语音的工程默认值，程序调用方可通过 `LoudnessSettings(targetLufs: ..., maxBoostDb: ..., samplePeakDbfs: ...)` 调整。

纯 Dart 测量使用 K 加权、400 ms 区块和 100 ms 步长，先执行 -70 LUFS 绝对门限，再执行低于第一轮平均响度 10 LU 的相对门限。增益作用于原始 PCM；加权只用于测量。24 kHz 单声道音频无需外部可执行程序。

- 至少 400 ms 的音频使用完整区块积分，末尾不足一个新区块的样本保留在输出中。
- 更短的台词用实际样本的 K 加权平均能量估算，标记为 `shortClipEstimate`，不添加补齐静音。
- 空音频、静音和门限以下的音频标记为 `unmeasurable`，不提升增益；响度字段为 `null`。
- 达到样本峰值或提升上限时，以 `peakLimited` / `boostLimited` 说明目标受限。单个增益保留台词内部的强弱关系，逐台词统一仍可能减弱台词之间刻意的强弱差别。

`loudness` 结果包含测量方式、`inputLufs`、`estimatedOutputLufs`、`gainDb`、目标和限制标志。输出响度是按实际增益推算的值，PCM16 量化会带来微小误差。实现采用 BS.1770 的测量方法与短片段扩展，尚未进行 EBU 认证；样本峰值上限也不构成重建真峰值的 dBTP 保证。

算法依据：[ITU-R BS.1770-5](https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1770-5-202311-I!!PDF-E.pdf)、[EBU Tech 3341](https://tech.ebu.ch/docs/tech/tech3341.pdf)。采样率相关滤波系数构造参考 [libebur128](https://github.com/jiixyj/libebur128/blob/master/ebur128/ebur128.c)，MIT 许可保存在 `packages/core/lib/src/audio/LIBEBUR128-LICENSE`。

## 缓存与音频路径

原始缓存保存完整 utterance 的服务商 PCM，身份包含实际分块、语言、绑定、表演指令、映射后的情绪或说明、规范化的匹配词典和格式版本。改变有效读音或请求形状会重新合成。

`rawAudioPath` 指向原始缓存；`audioPath` 指向 `normalized/` 下处理后的台词音频，整章文件使用同一份处理结果。即使原始缓存命中，也重新进行响度处理。处理后的路径包含原始缓存身份和响度设置版本，改变目标无需重新付费请求，处理文件损坏可从原始缓存恢复。

## 验证素材

[多音字文本](../packages/core/test/fixtures/pronunciation/polyphonic-zh.json) 包含长乐、单明、重庆、曾乐。[素材说明](../packages/core/test/fixtures/pronunciation/README.md) 记录了来源与离线范围。测试通过假的 LLM/TTS 接缝和离线 HTTP 契约验证中文转换、英文忽略、转义、分块保护、缓存、校准音、门限、峰值、静音和短片段。

真实 key 的双服务商发音试听及混合章节音量试听按本次约定跳过，后续使用同一素材和实际选角补验，跟踪于 [issue #10](https://github.com/dayeguilaiye/pagestage/issues/10)。
