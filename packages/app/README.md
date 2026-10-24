# pagestage App

Android 和 iOS 的 Flutter App。目前只有设计系统和一页设计样张（`lib/gallery/`），正式页面还没开始写。

```sh
cd packages/app
flutter run
flutter test
```

## 设计系统

`lib/design/` 是设计系统的 Flutter 实现，入口 `design.dart`。数值以 [pagestage 设计系统](https://claude.ai/artifact/3tcMfit4fxmas1EeCzsYeY) 的 `tokens.json` 为准，改动先改那边，再同步 `tokens.dart`。

- 主题：`MaterialApp` 用 `PsTheme.light` / `PsTheme.dark`。Material 自带的对话框、底部面板、提示条、开关、滑杆、选项片都已按设计系统定好样式，直接用即可。
- 颜色：`context.ps` 取当前主题的 `PsPalette`。说话人印章和生成封面的颜料色用 `voice(tone)`，`tone` 按演员表顺序分配并存进演员表。
- 文字：`PsType` 里是不带颜色的文字样式，颜色从主题或调用方给。正文用 `reading*`，界面用 `headline` / `body` / `label` / `subhead` / `caption` / `tag`，数字用 `numeral*`。
- 间距、圆角、尺寸、动效：`PsSpace`、`PsRadius`、`PsSize`、`PsMotion`。
- 组件：`PsButton`、`PsIconButton`、`PsPlayButton`、`PsSegmentedControl`、`PsTag`、`PsStatusMark`、`PsSeal`、`PsBookCover`、`PsMark`、`PsListGroup` / `PsListRow`、`PsChapterRow`、`PsCastRow`、`PsPassage`、`PsMiniPlayer`、`PsIcon`。
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
