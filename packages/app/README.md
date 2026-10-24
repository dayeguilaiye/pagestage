# pagestage App

Android 和 iOS 的 Flutter App。目前有书架、书的目录和正文三屏，数据还是内存里的演示书（`MemoryBookshelf.demo()`），接入 core 的书库见 #42。

```sh
cd packages/app
flutter run                          # App
flutter run -t lib/gallery/main.dart # 设计样张
flutter test
```

## 书架

`lib/shelf/` 是书架、目录和正文三屏。页面只通过两个接口取数据：

- `Bookshelf`：书的列表、导入（弹出文件选择器）、删除、章节列表和状态、按段落给出的正文。书和章节状态变化时通知监听者。
- `ReadingSettings`：字号、行距、夜间模式，全局一份，改了立即生效。

`MemoryBookshelf` 和 `MemoryReadingSettings` 是放在内存里的实现，用来开发界面和写 widget 测试；`main.dart` 在接入真实实现之前用它们。

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
