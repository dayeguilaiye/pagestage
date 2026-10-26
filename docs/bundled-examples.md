# 内置示例书

App 随包提供《阿Q正传》第一章「序」和 *Pride and Prejudice* Chapter I。首次打开空书库时安装，用户可以正常删除；安装标记让删除在后续启动时继续生效。正文与来源见[公版素材说明](../test/fixtures/books/README.md)。

## 生成与打包

开发者使用 `.pagestage/examples-v5` 中的已有建档和音色绑定，生成两本书首章的 `director-v5` 剧本，再以有声书模式合成。导演模型为 DeepSeek `deepseek-flash`，语音为 MiniMax `speech-2.8-hd` 的系统预设音色。真实请求需按根目录 AGENTS.md 确认范围，配置仅通过 CLI 的 `--config .pagestage/providers.json` 传入。

以下命令只读取已完成的本地素材，不请求服务商：

```sh
dart run packages/app/tool/build_examples.dart --source-dir .pagestage/examples-v5
```

源书库可以包含更多章节；打包固定选择两本书各第 1 章。源书、演员表和合成缓存保留供续跑。打包前检查当前导演版本及音频完整性，音频按台词时间轴拼接停顿，再编码为 24 kHz 单声道 AAC-LC、目标 64 kbps 的 M4A。macOS 使用 `afconvert`，其他系统需安装 `ffmpeg`。`packages/app/assets/examples/manifest.json` 保存实际音频字节数、时长、SHA-256、正文、剧本和音色绑定。

安装时校验资源及输入哈希，重定位音频路径，原子写入新书库。播放整章 M4A，正文高亮使用同一台词时间轴。播放器显示「AI 合成」标识。

实际打包结果：音频共 6,043,057 字节（约 5.76 MiB），总时长 736,477 ms（12 分 16 秒）。中文 M4A 为 3,700,544 字节，英文 M4A 为 2,342,513 字节。`afinfo` 校验两份文件均为 24 kHz 单声道 AAC，实际平均码率约 64.8 / 64.6 kbps。

## 分发条款核对

核对日期：2026-10-26。当前资源使用公版正文和 MiniMax 系统预设音色，随 App 分发的是预生成音频。

- [MiniMax 开放平台用户协议](https://platform.minimaxi.com/zh/protocol/user-agreement)第 9.5 条允许用户在遵守法律和协议的前提下决定输出物用途；第 6.3 条讨论用户依法享有权利的输出内容，第 6.6 条限制平台服务、密钥和工具的转让。第 1.5、1.7 条要求履行生成内容标识等义务。
- [MiniMax 国际开放平台条款](https://platform.minimax.io/protocol/terms-of-service)的 Intellectual Property 第 3 项保留用户依法享有的输入与生成内容权利；Client Rights and Obligations 要求合成内容标识。结合上述条款，本项目将合法输入生成的预设音色音频作为 App 示例资源分发，并保留 AI 合成标识和来源说明。此结论基于公开平台条款及当前素材；账号订单若有额外限制，应以订单为准。
- [百炼服务协议](https://terms.alicdn.com/legal-agreement/terms/common_platform_service/20230728213935489/20230728213935489.html)第 7.5–7.6 条规定生成内容权利与对外商业化使用责任。本资源的合成服务商为 MiniMax；未来采用百炼音色时，需按具体模型、音色及订单再次核对。

## 2026-10-26 生成记录

两本首章导演各 1 次请求：中文 2,976 输入 / 3,788 输出 tokens；英文 2,817 输入 / 4,108 输出 tokens。合计 13,689 tokens。演员表和选角复用本地已存结果。

MiniMax 成功合成 90 次：中文 43 次 / 3,122 字符，英文 47 次 / 4,396 字符，共 7,518 字符。英文另遇到 1 次限流，等待 60 秒后恢复，因此 TTS 网络尝试合计 91 次；无缓存命中，服务商未返回 token 用量。两章使用有声书模式，时长分别为 450,486 ms 和 285,991 ms。

## 验证

`packages/app/test/tool/build_examples_test.dart` 用离线适配器准备五章书库，只合成首章，并额外保存第二章剧本。执行实际 AAC 打包后，验证两本书各只有一个完整章节、首章剧本可安装，源书仍保留五章。需要本机 AAC 编码器。

`packages/app/integration_test/bundled_examples_test.dart` 使用实际随包资源、全新私有书库、空密钥存储和原生 just_audio 引擎：检查书架、逐条定位及正文对应、3 倍速完整播放、无服务商调用、删除后不重新安装。

在 `packages/app` 下执行：

```sh
flutter test test/tool/build_examples_test.dart test/application/generation_test.dart
dart test ../core/test/example_library_test.dart
flutter test integration_test/bundled_examples_test.dart -d <device-id>
```

2026-10-26 验证结果：

- 打包回归 1 项、已有无 key 播放与生成回归 16 项、示例安装回归 3 项全部通过；改动涉及的 Dart 文件静态检查通过。
- iOS 27.0 / iPhone 18 Pro 模拟器：两本各一章，90 条台词逐条定位和正文对应通过，3 倍速完整播放通过，测试耗时 4 分 15 秒。
- Android API 36 / sdk_gphone64_arm64 模拟器：相同资源和断言全部通过，测试耗时 4 分 21 秒。
- 两端使用空密钥存储，服务商适配器调用数均为 0，未触发生成确认或系统朗读；删除两本示例后再次安装仍为空书库。
- 两份 M4A 的 SHA-256 与清单一致；清单引用均可迁移，总资源大小（含清单）为 6,154,182 字节。
