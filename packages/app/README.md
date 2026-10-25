# pagestage App

Android 和 iOS 的 Flutter App。书架、章节目录和正文直接使用 core 的 `Library`，通过系统文件选择器导入 TXT 或无 DRM 的 EPUB，支持同书更新导入，数据库保存在 App 私有目录。字号、行距和夜间模式在重启后恢复。App 支持边听边生成、已合成音频与系统朗读的统一播放、服务商安全配置、建档与演员表、换音色与音色设计、按书清理音频、本地诊断导出与问题反馈，详见[收听与演员表](../../docs/app-listening-casting.md)。

```sh
cd packages/app
flutter run                          # App
flutter run -t lib/gallery/main.dart # 设计样张
flutter test
```

## Android 测试安装包

[Android test APK](https://github.com/dayeguilaiye/pagestage/actions/workflows/android.yml)
在推送 `main` 时自动构建，也支持在 Actions 页面点击 **Run workflow** 选择分支构建。
手动入口在工作流合入默认分支后可用，所选分支也需要包含工作流。
构建使用 Flutter 3.47.5、Java 17，生成包含各架构的 Release APK。

打开成功的构建记录，通过摘要链接或 **Artifacts** 下载压缩包，解压后将 APK
传到安卓手机安装。下载需要登录具有仓库读取权限的 GitHub 账号，产物保留 14 天。
文件名包含构建编号和提交短 SHA，Android 版本号使用工作流运行编号。

CI 使用固定测试签名，后续安装包可覆盖升级并保留应用数据。已安装的版本如果使用
其他签名，需要先备份数据并卸载，再安装 CI 版本。
仓库的 Actions Secrets 需要配置以下两项：

- `ANDROID_TEST_KEYSTORE_BASE64`：JKS 文件的单行 Base64，别名为 `pagestage-test`。
- `ANDROID_TEST_KEYSTORE_PASSWORD`：十六进制密码，keystore 和私钥使用相同密码。

首次配置的签名备份保存在配置机器的 `.pagestage/android-signing/`，其中 `test.jks`
为密钥库，`password` 为密码；目录被 Git 忽略，应妥善备份并长期复用。
工作流临时还原签名文件，构建结束后清理。构建过程无需服务商 API key。
本地 Release 构建可以通过被 Git 忽略的 `android/key.properties` 指定相同签名；
未配置时使用本地 debug 签名。

## 书架

`lib/shelf/` 是书架、目录和正文三屏。页面只通过两个接口取数据：

- `Bookshelf`：书的列表、导入（弹出文件选择器）、删除、章节列表和状态、按段落给出的正文。书和章节状态变化时通知监听者。
- `ReadingSettings`：字号、行距、夜间模式，全局一份，改了立即生效。

`lib/storage.dart` 提供文件选择器、私有目录和阅读设置。`Library` 实现 core 的 `Bookshelf` 接口，`SavedReadingSettings` 将设置保存在同一个数据库中。`MemoryBookshelf` 和 `MemoryReadingSettings` 用于界面预览和 widget 测试。

播放引擎原型的入口是 `lib/playback/prototype_main.dart`。本地素材准备、模拟器运行和选型结果见 [播放原型](../../docs/playback-prototype.md)。

## 中英文

所有界面文案放在 `lib/l10n/app_zh.arb` 和 `app_en.arb`，跟随系统语言：系统语言是中文时用简体中文，其他语言一律英文。改了 ARB 之后运行 `flutter gen-l10n`（`flutter run`、`flutter test` 也会自动生成），生成的 `app_localizations*.dart` 一起提交。新文案两种语言同时加，测试会检查两边的键一致。

## 设计系统

`lib/design/` 是设计系统的 Flutter 实现，入口 `design.dart`。数值以 [pagestage 设计系统](https://claude.ai/artifact/3tcMfit4fxmas1EeCzsYeY) 的 `tokens.json` 为准，改动先改那边，再同步 `tokens.dart`。

- 主题：`MaterialApp` 用 `PsTheme.light` / `PsTheme.dark`。Material 自带的对话框、底部面板、提示条、开关、滑杆、选项片都已按设计系统定好样式，直接用即可。
- 颜色：`context.ps` 取当前主题的 `PsPalette`。说话人印章和生成封面的颜料色用 `voice(tone)`，`tone` 按演员表顺序分配并存进演员表。
- 文字：`PsType` 里是不带颜色的文字样式，颜色从主题或调用方给。正文用 `reading*`，界面用 `headline` / `body` / `label` / `subhead` / `caption` / `tag`，数字用 `numeral*`。
- 间距、圆角、尺寸、动效：`PsSpace`、`PsRadius`、`PsSize`、`PsMotion`。
- 组件：`PsButton`、`PsIconButton`、`PsPlayButton`、`PsSegmentedControl`、`PsTag`、`PsStatusMark`、`PsBanner`、`PsSeal`、`PsBookCover`、`PsMark`、`PsListGroup` / `PsListRow`、`PsShelfItem`、`PsChapterRow`、`PsCastRow`、`PsPassage`、`PsMiniPlayer`、`PsNavBar` / `PsLargeTitle`、`PsEmptyState`、`PsSheet`、`PsDialog`、`PsIcon`；`showPsSheet`、`showPsMenu`、`showPsToast` 打开对应的浮层。
- 组件自带的文案（播放、旁白、章节状态等）也走本地化，所以组件要放在带 `AppLocalizations.delegate` 的 `MaterialApp` 里。
- `PsPassage` 点台词只回调 `onLineTap`，由调用方弹出「从这里播放」菜单，不直接改变播放位置。

## 字体

`assets/fonts/` 打包了四套字体，均为 SIL Open Font License，许可文本在同一目录，启动时注册到 `LicenseRegistry`：

| 字体 | 用途 |
| --- | --- |
| Noto Serif SC（思源宋体，可变字体，约 25 MB） | 中文正文、标题、印章 |
| Newsreader | 英文正文、拉丁书名、字标 |
| Instrument Sans | 界面文字，中文回落到系统黑体 |
| DM Mono | 时间码、倍速、章节序号 |

前三套是可变字体，`PsType.style` 会同时设置 `fontWeight` 和对应的 `wght` 轴。

## 诊断

设置中的诊断报告通过系统分享面板导出。日志保存在 App 私有目录，单份上限 128 KiB，轮转保留两份。报告包含应用版本、系统版本、固定错误类别、Dart 源码位置和系统崩溃数值摘要。异常消息、key、书籍正文、原生堆栈原文和任意平台字符串均不写入报告；应用不自动上传。

Android 11 / API 30 起从 `ApplicationExitInfo` 读取历史崩溃与 ANR。iOS 14 起订阅 MetricKit 并读取系统保留的历史诊断；系统决定报告交付时间，报告可在后续启动或导出时补入日志。设置中的反馈入口打开本仓库的新建 Issue 页面，由用户填写和提交。

## 示例书资源

`ExampleLibrary` 在新书库首次安装完整资源包，校验音频 SHA-256、正文哈希和剧本/音色输入后原子写入。安装标记持久保存，用户删除书后再次启动仍保持删除状态。播放器直接读取整章 M4A，并沿用台词与停顿时间轴。

本地打包命令：

```sh
dart run packages/app/tool/build_examples.dart --source-dir .pagestage/examples-v5
```

源目录需具备当前 `director-v5` 的两本公版书各五章、演员表及完整 CLI 合成结果。脚本按 64 kbps 单声道 AAC-LC 压缩，输出 M4A 和包含实际总字节数、时长的 `assets/examples/manifest.json`；macOS 使用 `afconvert`，其他系统使用 `ffmpeg`，打包本身不调用服务商。

实际随包素材在 [#35](https://github.com/dayeguilaiye/pagestage/issues/35) 跟进；当前清单为空，待完成素材生产与分发条款核对后填入。2026-10-25 已获准为两本书各前五章生成当前版本剧本，第一章因三次连接失败停止，未收到可记账的服务商响应。音频合成需在剧本完成后另行确认具体请求范围。

分发许可依据为 [MiniMax 开放平台用户协议](https://platform.minimaxi.com/zh/protocol/user-agreement)与[百炼服务协议](https://terms.alicdn.com/legal-agreement/terms/common_platform_service/20230728213935489/20230728213935489.html)。百炼第 7.5–7.6 条讨论生成内容权利及对外使用责任；随 App 分发所用具体音色与音频的许可结论继续记录在 #35，当前资源包不包含服务商生成音频。
