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

EPUB 使用同一个 `import` 命令，支持 EPUB 3 导航目录与 EPUB 2 NCX。目录锚点决定章节边界，可以在一个文件内拆章或跨多个文件合章；缺少目录时按阅读顺序中的文件分章。导入仅保留标题与正文，拒绝带 DRM 的文件；字体混淆不影响正文提取。

新版文件的前三章正文与已有书一致时，合并到原书。未改变的章节保留剧本和音频；修改的章节清除剧本与音频记录，保留建档范围、演员表和音色；新增章节接到后面。短版本保留已有尾章。命令结果同时包含 `updated`、`addedChapters` 和 `changedChapters`，App 显示对应更新结果。

测试素材是《阿Q正传》和《傲慢与偏见》的前五章，来源与整理方式见 [素材说明](test/fixtures/books/README.md)。

## 从章节到多角色音频

完成导入后，把 key 写进被 Git 忽略的 `.pagestage/providers.json`，字段见 [LLM 配置](docs/cli-profiling.md) 和 [TTS 配置](docs/cli-tts.md)，并用 `chmod 600` 限制读取权限。CLI 只在命令带 `--config` 时读取这个文件，付费请求因此始终是显式的。环境变量同样可用且优先于文件；写进 shell 启动文件会让每条命令都带上 key，建议只在单条命令前临时设置。该文件位于默认数据目录内，清空 `.pagestage/` 前先把它移出。Agent 使用 key 的规则见 [AGENTS.md](AGENTS.md)。

以下 `<book-id>` 使用导入结果中的 ID：

```sh
dart run packages/core/bin/pagestage.dart profile <book-id> --through 1 --config .pagestage/providers.json
dart run packages/core/bin/pagestage.dart cast recommend <book-id> --provider minimax
dart run packages/core/bin/pagestage.dart direct <book-id> 1 --config .pagestage/providers.json
dart run packages/core/bin/pagestage.dart synthesize <book-id> 1 --config .pagestage/providers.json
```

`profile` 建立本书演员表；`cast recommend` 选择音色；`direct` 保存与原文对齐的剧本；`synthesize` 按角色和情绪生成 WAV。示例选角限定 MiniMax，同章可以混用 MiniMax、百炼和 Edge。使用 `cast catalog --language zh` 查看预设、`cast set <book-id> <speaker-id> <provider:voice-id>` 换声。再次合成复用未改变台词的音频缓存。

Edge 可免 key 朗读已导入章节：`dart run packages/core/bin/pagestage.dart narrate <book-id> 1 --provider edge`。使用 `cast recommend <book-id> --provider edge` 可为已建档的书选择 Edge 音色；支持语速、音高和音量，情绪与发音词典不生效。MP3 解码依赖随 Dart/Flutter 构建的原生库，构建环境需要 C 工具链。

广播剧模式使用 `synthesize ... --mode drama`，旁白合并试听使用 `--merge-narrator`。命令输出 JSON，包含已保存状态、用量和音频路径；本地 SQLite、剧本和音频均位于 `--data-dir` 选定的目录。

### 用量账本

每个被服务商接受的真实请求都会向 `--data-dir` 下的 `usage.jsonl` 追加一行，原样保存服务商自己的计费字段：LLM 的 `usage`（含 DeepSeek 的缓存命中 token 等厂商扩展字段）、MiniMax 的 `extra_info`（如 `usage_characters`）、百炼的 `usage`。每行还记录时间、`provider`、请求地址、模型、服务商请求 ID，以及本次 CLI 调用的 `run` 标识和命令参数。LLM 回复即使因格式不合格被拒绝也会记账，因为这次请求已经计费；服务商返回错误的请求不记。流式回复中途断开时，已经确认被接受的请求也会保留已收到的用量字段；服务商未返回用量时保存空对象，不能据此认定请求免费。账本不含 key 和请求正文，假适配器和缓存命中不产生记录。

| 文档 | 内容 |
| --- | --- |
| [建档与 LLM](docs/cli-profiling.md) | 兼容接口配置、增量建档、角色和人物关系 |
| [选角](docs/cli-casting.md) | 预设目录、音色选择、试听和临时角色 |
| [音色设计](docs/cli-voice-design.md) | 生成候选、选择并激活设计音色 |
| [导演](docs/cli-directing.md) | 原文对齐、表演指令和非正文标记 |
| [语音合成](docs/cli-tts.md) | 服务商配置、多角色、演播模式、缓存和停顿 |
| [读音与响度](docs/cli-pronunciation-loudness.md) | 中文词典、拼音请求、统一响度和音频路径 |
| [归属评估](docs/cli-evaluation.md) | 人工参考标注、命中率和错例导出 |
| [产品规格](docs/spec.md) | 原型目标与产品设计 |
| [领域词汇](GLOSSARY.md) | Script、Speaker、VoiceBinding 等术语 |

当前验证使用假 LLM/TTS 和离线 HTTP/WebSocket 契约及 MP3 解码夹具。真实 key 的整章合成、音色区分与人工试听验收待补验。

## 安装包与版本发布

推送到 `main` 或手动运行 GitHub Actions 的 `Android APK and release` 工作流，会构建 APK 并保存在 Actions Artifacts 中，保留 14 天。

推送版本 tag 会构建并发布同名 GitHub Release，附带 `pagestage-<tag>-android.apk`。tag 使用语义化版本，可带 `v` 前缀，例如 `v1.2.3`、`1.2.3`、`v1.2.3-rc.1`；带预发布标识的版本会标记为 Pre-release。无效的版本 tag 会使工作流失败。手动选择 tag 运行工作流也会发布该版本。

APK 的版本名称取 tag 去掉 `v` 前缀和 `+` 构建元数据后的值，Android 版本代码使用 Actions 运行编号。签名使用仓库已配置的 `ANDROID_TEST_KEYSTORE_BASE64` 和 `ANDROID_TEST_KEYSTORE_PASSWORD`，与 main 分支安装包保持一致。

```sh
git tag v1.2.3
git push origin v1.2.3
```

发布任务统一收集 `release-*` 构建产物，目前包含 Android APK。扩展平台时，在对应构建任务上传独立命名的 `release-<平台>` 产物，并把该任务加入发布任务的依赖。同一 tag 重跑时更新同名附件，保留 Release 中的其他附件。

## 开发验证

```sh
dart format --output=none --set-exit-if-changed packages/core packages/app
dart analyze
dart test packages/core/test
(cd packages/app && flutter test)
```

core 的公共入口是 `package:pagestage_core/pagestage_core.dart`。CLI 命令使用共享的 `CliContext`，业务功能通过书库等模块的公共接口调用。单元测试在 LLM、TTS 服务商接缝使用假适配器，书库测试通过公共接口验证导入结果。

Flutter App 在 `packages/app`，包含书架、章节目录、正文、持久化阅读设置、正式播放器、系统朗读、服务商设置、建档和演员表，见 [App 说明](packages/app/README.md)。core 的持久化任务接口见 [调度](docs/scheduler.md)，播放引擎的验证入口见 [播放原型](docs/playback-prototype.md)。
