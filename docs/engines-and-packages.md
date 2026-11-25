# 引擎、表演与书籍包

语言引擎负责建档和导演，配音引擎负责把剧本中的台词合成为音频。App 从引擎注册表生成设置入口，按书保存演播模式和表现力。桌面 CLI 与手机 App 使用相同的剧本和书籍包格式。

## 引擎扩展

当前提供 OpenAI 兼容的云端语言引擎，以及 MiniMax、百炼、Microsoft Edge 配音引擎。面向骁龙 8 Gen 3 的 Android 模型包内置 Ming 离线配音。用户在设置里手动初始化后，所有角色共享这套图。模型包带有 32 个普通话预设，每个预设保存一份由桌面 Ming 设计并提取的声音特征。每句分别传入角色的声音特征，可以在同一批中使用不同角色。本机语言引擎保留扩展入口。

`packages/core/lib/src/engines/` 定义引擎协议及标准注册表。`Engine` 描述标识、运行位置、配置字段、就绪状态和正文接收地址；就绪状态区分可用、待配置、未安装模型和当前未提供。`TtsEngine` 还提供预设目录、按音色绑定查询的能力、音色设计模型，以及适配器的创建和关闭操作。

新增配音模型时，实现 `TtsEngine` 和 `TtsAdapter`，在 `AppEngines.voice` 中注册；支持声音描述设计的适配器同时实现 `VoiceDesignAdapter`。本机模型声明 `EngineLocality.device`，正文留在设备上时 `endpoint` 返回 `null`；模型未安装时返回 `notInstalled`。模型下载、安装和推理生命周期由实际 runtime 实现。

本机语言模型实现 `LocalLlmRuntime` 的安装状态、模型名称和 `start()`，再构造 `DeviceLlmEngine(runtime: ...)`。`start()` 返回本机 OpenAI 兼容服务的基础地址，适配器复用结构化输出、流式读取和有限重试。应用在 `AppServices.open(storage, engines: ...)` 注入注册表；CLI 的注册入口是 `standardLlmEngines` 和 `standardTtsEngines`。

App 的 `ProviderStore` 保存通用引擎配置，并读取已有服务商设置及安全存储中的密钥。普通设置位于 SQLite，密钥位于系统安全存储；`ProviderGateway` 统一检查配音开关、就绪状态、发送同意和请求节奏。云端请求按实际地址请求发送同意，本机引擎直接进入本机适配器。新引擎的显示名称、字段说明和能力标签在 `Labels` 及中英文 ARB 中补充。

## 表演与台词修订

`Direction` 保存通用表演指令，导演提示词版本为 `director-v6`。语速为慢、正常、快，音量为轻、正常、响；发声提示以台词中的 UTF-16 偏移定位，原文仍保留在章节中。导演只在原文明示非语言声音时添加提示。

`Delivery.lower` 根据音色绑定的 `TtsCapabilities` 和本书表现力生成可执行的表演。支持的情绪直接使用，其余按近似情绪、自然语言指令或数值韵律控制适配，无法执行的部分省略。适配器负责转换为供应商参数或内嵌标记。长台词拆分时，发声提示随对应原文块移动。

表现力分为平实、自然和戏剧。平实按角色朗读，自然沿用导演指令，戏剧加强情绪；演播模式决定是否朗读说话提示。两者按书保存，改变后复用实际请求内容保持一致的台词缓存。CLI 的 `synthesize --mode` 与 `--expressiveness` 保存选择，省略参数时使用本书已保存的值。

正文中点击已导演的台词，可以进入该说话人的换声页，也可以修订这句的说话人。修改前暂停该书的播放和生成；本地合成章节复用未变台词缓存，导入音频的章节提示需要重新合成整章。

## 导入与导出

书页菜单中的分享入口可导出剧本包或有声包，并显示已完成的剧本与音频章节数。书架文件选择器接收 `.pagestage`；书库中已有相同书籍 ID 时先确认替换。

```sh
dart run packages/core/bin/pagestage.dart export <book-id> book.script.pagestage
dart run packages/core/bin/pagestage.dart export <book-id> book.audio.pagestage --kind audio
dart run packages/core/bin/pagestage.dart export <book-id> book.audio.pagestage --kind audio --audio-format m4a
dart run packages/core/bin/pagestage.dart import book.audio.pagestage
dart run packages/core/bin/pagestage.dart import book.audio.pagestage --replace
```

`--kind` 默认为 `script`。`audio` 导出本书已保存演播模式下完整且有效的章节音频，也可通过 `--mode audiobook|drama` 指定。`--audio-format m4a` 将 WAV 转成 64 kbps AAC：macOS 使用 `afconvert`，其他系统使用 `ffmpeg`。导入、导出和转码都只处理本地数据。

包格式为 ZIP，`manifest.json` 的 `format` 是 `pagestage-package`，`version` 是 `1`：

| 条目 | 内容 |
| --- | --- |
| `manifest.json` | 书籍摘要、演播设置、剧本章节列表、音频路径及 SHA-256 |
| `book.json` | 全书原文和章节，源文件只记录文件名 |
| `cast.json` | 演员表、建档范围及发音词典 |
| `voices.json` | 音色描述、已有绑定及选角信息 |
| `scripts/000001.json` | 对应章节剧本 |
| `audio/000001-audiobook.wav` 等 | 已完成的整章音频 |
| `audio/000001-audiobook.json` 等 | 台词时间轴与音频元数据 |

服务商密钥、设备配置、任务和本机样音路径保留在原设备。导入时校验版本、书籍身份、章节顺序、剧本正文哈希和原文覆盖，并验证音频摘要。与正文不符的剧本及依赖它的音频不安装，返回摘要列出实际安装的章节。

替换时先在临时目录验证输入，再暂停该书操作并切换音频目录、事务更新书库；写入失败会恢复原有记录和音频，阅读位置保留。导入音频按剧本判断有效性，接收设备换音色后仍可直接收听；修改剧本后该章按接收设备的配置重新合成。

## 验证入口

```sh
dart format --output=none --set-exit-if-changed packages/core packages/app
dart analyze packages
dart test packages/core/test
cd packages/app
flutter test
flutter test integration_test/packages_test.dart -d <device>
flutter test integration_test/generation_services_test.dart -d <device>
```

离线测试覆盖引擎注册、配置迁移、能力适配、台词缓存、说话人修订、书籍包往返、失败替换回滚及 CLI 演播设置。原生书籍包测试用假模型生成音频，再通过真实书库、原生播放器和系统分享通道验证导入、播放及分享路径限制。

2026-11-13 验证结果：格式检查、`dart analyze packages`、core 309 项及 App 194 项测试通过。iOS 27 模拟器和 Android API 36 模拟器均通过书籍包与生成服务集成测试，覆盖原生播放、系统分享、边听边生成、倍速、选角与清理；Android 调试 APK 构建成功。服务商请求使用离线夹具，本机语言引擎使用回环 HTTP 测试服务，真实模型请求数为 0。
