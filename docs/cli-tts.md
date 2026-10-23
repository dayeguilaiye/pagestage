# CLI 语音合成

在仓库根目录执行：

```sh
dart pub get
dart run packages/core/bin/pagestage.dart import test/fixtures/books/aq-zh.txt
dart run packages/core/bin/pagestage.dart books
```

`import` 返回 `bookId`。准备相应服务商的环境变量或本地配置后，选择服务商合成已导入的章节：

```sh
dart run packages/core/bin/pagestage.dart narrate <book-id> 1 --provider minimax
dart run packages/core/bin/pagestage.dart narrate <book-id> 1 --provider bailian
```

`narrate` 为每个自然段创建一条旁白台词，按照原文区间合成，段落之间插入 300 毫秒静音。超长台词按适配器声明的请求字符预算拆分，优先在句末、其次在空白处分开，必要时按 Unicode 码点拆分；拆出的原文按顺序拼回后与输入完全一致。一个段落内的音频块直接拼接，段落间保留停顿。

输出为 24 kHz、单声道、16 位 PCM WAV。JSON 结果包括文件路径、音频时长、字符用量、请求数、耗时和服务商报告的 token 用量。未提供的用量字段为 `null`。默认文件放在 `.pagestage/audio/<book-id>/chapter-1.wav`，用 `--output` 指定路径；对比两家音频时分别选择输出文件。`--data-dir` 选择书库与音频目录。

## 多角色整章合成

先完成 [建档](cli-profiling.md)、[选角](cli-casting.md) 和 [导演](cli-directing.md)，再合成持久化的 Script：

```sh
dart run packages/core/bin/pagestage.dart synthesize <book-id> 1 --config .pagestage/providers.json
dart run packages/core/bin/pagestage.dart synthesize <book-id> 1 --mode drama --config .pagestage/providers.json
dart run packages/core/bin/pagestage.dart synthesize <book-id> 1 --merge-narrator --config .pagestage/providers.json
```

`synthesize` 读取每个说话人的 VoiceBinding，支持同一章混用 MiniMax 和百炼。导演新增的临时说话人按已保存的选角策略补齐音色。只有本次实际朗读涉及的服务商需要配置 key。模型、音色和参数来自选角结果；`MINIMAX_MODEL`、`BAILIAN_MODEL` 等旁白默认值不改写已选绑定。

| 选项或规则 | 行为 |
| --- | --- |
| `--mode audiobook`（默认） | 朗读正文和说话提示，跳过非正文 |
| `--mode drama` | 朗读正文，跳过说话提示和非正文 |
| `--merge-narrator` | 合并原文中相邻、表演指令相同的旁白台词；原文逐字保留，长请求仍按服务商预算拆分 |
| 连续同一说话人 | 100 ms 停顿 |
| 切换说话人 | 180 ms 停顿 |
| 原文换段 | 300 ms 停顿，优先于说话人规则 |

停顿根据两条可听台词之间原文的换行判断，包含附在台词末尾或开头的空白。第一条前面不加停顿；同一 utterance 的服务商分块之间直接拼接。合并旁白时，合并后的原文作为一个 utterance，内部节奏交由 TTS 处理，供试听对比。

MiniMax 仅传情绪枚举。百炼将情绪、强度和补充说明组合成中文或英文自然语言 `instruction`，例如 `Read with a sad emotion and strong intensity. Speak softly.`。

默认整章文件是 `.pagestage/audio/<book-id>/chapter-1-audiobook.wav` 或 `chapter-1-drama.wav`。JSON 返回整章路径、音频时长、耗时、实际新请求数、缓存命中数、服务商用量以及每条原文对应的说话人和音频引用。合并旁白的各行共用一个 utterance 音频引用，`utteranceLineIndices` 是原 Script 的零起始索引；接口没有提供单词或行内时间戳。

### 音频缓存

`.pagestage/audio/cache/` 保存每个 utterance 的原始 PCM WAV，已经拼好服务商分块。缓存身份包含实际分块原文、语言、服务商、模型、音色绑定参数、完整表演指令、映射后的请求说明以及规范化的匹配发音词典。相同内容跨 CLI 调用复用；换掉一个说话人的音色，仅他的台词重新请求。修改原文、模型或表演指令会产生新缓存。缓存文件丢失或损坏时自动重新合成。

缓存保留原始 utterance 音频。每次组装先从原始音频统一响度，再添加章节停顿。`rawAudioPath` 指向原始缓存，`audioPath` 指向 `normalized/` 下处理后的台词音频，详见 [发音词典与响度](cli-pronunciation-loudness.md)。开关演播模式可复用保留台词的缓存；合并旁白改变 utterance 的原文组合，因此第一次会生成对应缓存。`requests`、`characters` 和 token 字段只统计本次新请求；全部命中时请求数、字符用量为 0，未报告的 token 用量为 `null`。程序调用方可通过 `Synthesizer(cacheDirectory: ...)` 选定缓存目录；默认在输出目录下的 `.utterances/`。

## 配置

`--provider` 默认 `minimax`。环境变量优先于本地配置字段；`--model` 和 `--voice` 优先于两者。模型与预设音色必须匹配。

| 环境变量 | JSON 字段 | 默认值 |
| --- | --- | --- |
| `MINIMAX_API_KEY` | `minimax.key` | 必填 |
| `MINIMAX_BASE_URL` | `minimax.baseUrl` | `https://api.minimax.io/v1` |
| `MINIMAX_MODEL` | `minimax.model` | `speech-2.8-hd` |
| `MINIMAX_VOICE` | `minimax.voice` | 中文 `Chinese (Mandarin)_Male_Announcer`，英文 `English_expressive_narrator` |
| `BAILIAN_API_KEY` | `bailian.key` | 必填 |
| `BAILIAN_REGION` | `bailian.region` | `beijing`，也可选 `singapore` |
| `BAILIAN_BASE_URL` | `bailian.baseUrl` | 北京 `https://dashscope.aliyuncs.com/api/v1`；新加坡 `https://dashscope-intl.aliyuncs.com/api/v1` |
| `BAILIAN_MODEL` | `bailian.model` | `qwen-audio-3.1-tts-flash` |
| `BAILIAN_VOICE` | `bailian.voice` | 中文 `longsanshu_v3.1`，英文 `Emily_v3.1` |

百炼也支持设置工作空间专用地址，例如 `https://<workspace-id>.cn-beijing.maas.aliyuncs.com/api/v1`。地址、key、`region` 和音色需要来自同一区域。新加坡区的可用预设请以服务商目录为准。

也可以创建本地 `.pagestage/providers.json`，通过 `--config .pagestage/providers.json` 读取。`.pagestage/` 已被 Git 忽略。示例值需替换为自己的 key：

```json
{
  "minimax": {
    "key": "your-local-key",
    "model": "speech-2.8-hd"
  },
  "bailian": {
    "key": "your-local-key",
    "region": "beijing",
    "model": "qwen-audio-3.1-tts-flash"
  }
}
```

服务商错误以固定的安全消息输出，无效 key、余额不足和限流各有独立类别；失败退出码为 69。配置解析错误不会输出配置原文，退出码为 65。适配器不自动重试付费请求，百炼的签名音频下载地址不会收到 API key。

## 适配器能力

`TtsAdapter.capabilitiesFor(binding)` 根据模型、音色和区域返回拼音标注能力及请求字符预算。`TtsRequest` 携带原文、语言、音色绑定、表演指令和发音词典条目；适配器将表演指令转换为对应的厂商参数。MiniMax 使用情绪枚举，百炼将情绪、强度和说明组合成自然语言指令。

MiniMax 的预算是 9999 个 Unicode 码点，对应官方“少于 10000 字符”的限制。百炼使用 Qwen-Audio 3.0/3.1 HTTP 接口，默认预算为 600 个码点。这是原型采用的保守实现预算；当前 HTTP 文档没有明确给出数值上限。程序调用方可通过 `BailianTtsAdapter(requestCharacterLimit: ...)` 调整，实际连续性仍需真实音频试听验证。

音色设计使用独立的 `VoiceDesignAdapter.design` 接口，在发送请求前校验模型、地域和 endpoint。百炼要求北京区配置和兼容的 endpoint；设计音色的合成沿用同一地域限制。拼音能力仅对当前确认支持的 3.1 预设音色声明；`VoiceBinding.designed` 标记的设计音色尚无官方 SSML 支持保证。

## 离线验证

```sh
dart analyze
dart test packages/core/test
```

合成与 CLI 测试注入假 TTS，返回已知时长的 PCM。契约测试使用依据官方文档构造的 HTTP 响应，覆盖请求、音频解析、错误归类和凭据保护。真实 key 的整章合成、拼接连续性与人工试听尚待补验，多角色声音区别、表演听感及两本测试书第 1 章的真实 key 合成同样待补验，见 [issue #9](https://github.com/dayeguilaiye/pagestage/issues/9)、[issue #4](https://github.com/dayeguilaiye/pagestage/issues/4) 和 [issue #5](https://github.com/dayeguilaiye/pagestage/issues/5)。

API 依据（2026-10-23 核对）：[MiniMax 同步语音合成](https://platform.minimax.io/docs/api-reference/speech-t2a-http)、[MiniMax 错误码](https://platform.minimax.io/docs/api-reference/errorcode)、[百炼 Qwen-Audio HTTP](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-http-api)、[百炼音色目录](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-voice-list)、[百炼 SSML](https://www.alibabacloud.com/help/en/model-studio/ssml-latex-user-guide)。
