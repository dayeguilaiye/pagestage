# CLI 旁白合成

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

`TtsAdapter.capabilitiesFor(binding)` 根据模型、音色和区域返回音色设计、情绪控制、拼音标注、时间戳和请求字符预算。当前适配器采用非流式 WAV，因此时间戳能力为 `false`。

MiniMax 的预算是 9999 个 Unicode 码点，对应官方“少于 10000 字符”的限制。百炼使用 Qwen-Audio 3.0/3.1 HTTP 接口，默认预算为 600 个码点。这是原型采用的保守实现预算；当前 HTTP 文档没有明确给出数值上限。程序调用方可通过 `BailianTtsAdapter(requestCharacterLimit: ...)` 调整，实际连续性仍需真实音频试听验证。

百炼的音色设计能力按北京区声明。拼音能力仅对当前确认支持的 3.1 预设音色声明；`VoiceBinding.designed` 标记的设计音色尚无官方 SSML 支持保证。

## 离线验证

```sh
dart analyze
dart test packages/core/test
```

合成与 CLI 测试注入假 TTS，返回已知时长的 PCM。契约测试使用依据官方文档构造的 HTTP 响应，覆盖请求、音频解析、错误归类和凭据保护。真实 key 的整章合成、拼接连续性与人工试听尚待补验，见 [issue #4](https://github.com/dayeguilaiye/pagestage/issues/4) 和 [issue #5](https://github.com/dayeguilaiye/pagestage/issues/5)。

API 依据（2026-10-23 核对）：[MiniMax 同步语音合成](https://platform.minimax.io/docs/api-reference/speech-t2a-http)、[MiniMax 错误码](https://platform.minimax.io/docs/api-reference/errorcode)、[百炼 Qwen-Audio HTTP](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-http-api)、[百炼音色目录](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-voice-list)、[百炼 SSML](https://www.alibabacloud.com/help/en/model-studio/ssml-latex-user-guide)。
