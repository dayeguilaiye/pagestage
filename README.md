# pagestage

以听为主的小说阅读器。CLI 原型使用纯 Dart core 包，开发环境为 Dart 3.11 或更新版本。

## 运行 CLI

在仓库根目录执行：

```sh
dart pub get
dart run packages/core/bin/pagestage.dart import test/fixtures/books/aq-zh.txt --title 阿Q正传
dart run packages/core/bin/pagestage.dart import test/fixtures/books/pride-and-prejudice-en.txt --title 'Pride and Prejudice'
dart run packages/core/bin/pagestage.dart books
dart run packages/core/bin/pagestage.dart chapters <book-id>
```

`import` 返回书的 `bookId`、语言和章节列表。后续命令使用这个 ID。使用全局参数 `--data-dir <目录>` 选择本地数据目录，默认是当前目录的 `.pagestage`；书和章节通过 drift 保存到该目录的 SQLite 文件。

TXT 先严格按 UTF-8 解码，再尝试 GB18030。GB18030 解码使用 WHATWG Encoding Standard 的索引，支持 GBK 两字节字符与 GB18030 四字节字符。中文的「章」「回」与英文 Chapter 标题用于划分章节，「卷」用于分组；没有章节标题时每约 5000 个 Unicode 字符分成一章。章节正文保留解码后的换行和空白，后续剧本的原文区间使用 Dart UTF-16 偏移量。

测试素材是《阿Q正传》和《傲慢与偏见》的前五章，来源与整理方式见 [素材说明](test/fixtures/books/README.md)。

## 从章节到多角色音频

完成导入后，按 [LLM 配置](docs/cli-profiling.md) 和 [TTS 配置](docs/cli-tts.md) 准备环境变量，或创建被 Git 忽略的 `.pagestage/providers.json`。以下 `<book-id>` 使用导入结果中的 ID：

```sh
dart run packages/core/bin/pagestage.dart profile <book-id> --through 1 --config .pagestage/providers.json
dart run packages/core/bin/pagestage.dart cast recommend <book-id> --provider minimax
dart run packages/core/bin/pagestage.dart direct <book-id> 1 --config .pagestage/providers.json
dart run packages/core/bin/pagestage.dart synthesize <book-id> 1 --config .pagestage/providers.json
```

`profile` 建立本书角色表；`cast recommend` 选择音色；`direct` 保存与原文对齐的剧本；`synthesize` 按角色和情绪生成 WAV。示例选角限定 MiniMax，同章也可以分别绑定两家服务商。使用 `cast catalog --language zh` 查看预设、`cast set <book-id> <speaker-id> <provider:voice-id>` 换声。再次合成复用未改变台词的音频缓存。

广播剧模式使用 `synthesize ... --mode drama`，旁白合并试听使用 `--merge-narrator`。命令输出 JSON，包含已保存状态、用量和音频路径；本地 SQLite、剧本和音频均位于 `--data-dir` 选定的目录。

| 文档 | 内容 |
| --- | --- |
| [建档与 LLM](docs/cli-profiling.md) | 兼容接口配置、增量建档、角色和人物关系 |
| [选角](docs/cli-casting.md) | 预设目录、音色选择、试听和临时角色 |
| [音色设计](docs/cli-voice-design.md) | 生成候选、选择并激活设计音色 |
| [导演](docs/cli-directing.md) | 原文对齐、演出指令和非正文标记 |
| [语音合成](docs/cli-tts.md) | 服务商配置、多角色、演播模式、缓存和停顿 |
| [读音与响度](docs/cli-pronunciation-loudness.md) | 中文词典、拼音请求、统一响度和音频路径 |
| [归属评估](docs/cli-evaluation.md) | 人工参考标注、命中率和错例导出 |
| [产品规格](docs/spec.md) | 原型目标与产品设计 |
| [领域词汇](GLOSSARY.md) | Script、Speaker、VoiceBinding 等术语 |

当前验证使用假 LLM/TTS 和依据官方文档构造的离线 HTTP 契约。真实 key 的整章合成、音色区分与人工试听验收待补验。

## 开发验证

```sh
dart format --output=none --set-exit-if-changed packages/core
dart analyze
dart test packages/core/test
```

core 的公共入口是 `package:pagestage_core/pagestage_core.dart`。CLI 命令使用共享的 `CliContext`，业务功能通过书库等模块的公共接口调用。单元测试在 LLM、TTS 服务商接缝使用假适配器，书库测试通过公共接口验证导入结果。
