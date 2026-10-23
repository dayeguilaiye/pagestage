# CLI 旁白合成

在仓库根目录执行：

```sh
dart pub get
dart run packages/core/bin/pagestage.dart import test/fixtures/books/aq-zh.txt
dart run packages/core/bin/pagestage.dart books
```

`import` 返回 `bookId`。将 MiniMax key 放入 `MINIMAX_API_KEY` 环境变量后，可为已导入的章节合成旁白：

```sh
dart run packages/core/bin/pagestage.dart narrate <book-id> 1
```

`narrate` 为每个自然段创建一条旁白台词，按照原文区间合成，段落之间插入 300 毫秒静音。输出为 24 kHz、单声道、16 位 PCM WAV；JSON 结果包括文件路径、音频时长、服务商报告的合成字符用量、请求数和耗时。默认文件放在 `.pagestage/audio/<book-id>/chapter-1.wav`，用 `--output` 指定路径。`--data-dir` 选择书库与音频目录。

## 配置

环境变量优先于本地配置字段；`--model` 和 `--voice` 优先于两者。

| 环境变量 | JSON `minimax` 字段 | 默认值 |
| --- | --- | --- |
| `MINIMAX_API_KEY` | `key` | 必填 |
| `MINIMAX_BASE_URL` | `baseUrl` | `https://api.minimax.io/v1` |
| `MINIMAX_MODEL` | `model` | `speech-2.8-hd` |
| `MINIMAX_VOICE` | `voice` | 中文 `Chinese (Mandarin)_Male_Announcer`，英文 `English_expressive_narrator` |

也可以创建本地 `.pagestage/providers.json`，通过 `--config .pagestage/providers.json` 读取。`.pagestage/` 已被 Git 忽略。格式如下，示例值需替换为自己的 key：

```json
{
  "minimax": {
    "key": "your-local-key",
    "baseUrl": "https://api.minimax.io/v1",
    "model": "speech-2.8-hd",
    "voice": "Chinese (Mandarin)_Male_Announcer"
  }
}
```

服务商错误以固定的安全消息输出，无效 key、余额不足和限流各有独立类别；失败退出码为 69。配置解析错误不会输出配置原文，退出码为 65。适配器不自动重试付费请求。

## 离线验证

```sh
dart analyze
dart test packages/core/test
```

合成与 CLI 测试注入假 TTS，返回已知时长的 PCM。MiniMax 契约测试使用依据官方文档构造的 HTTP 响应，检查请求格式、WAV 解析、错误归类和凭据不进入错误输出。真实 key 的整章合成与人工试听尚待补验，具体记录见 [issue #4](https://github.com/dayeguilaiye/pagestage/issues/4)。

API 依据：[MiniMax 同步语音合成](https://platform.minimax.io/docs/api-reference/speech-t2a-http)、[错误码](https://platform.minimax.io/docs/api-reference/errorcode)，核对日期 2026-10-23。
