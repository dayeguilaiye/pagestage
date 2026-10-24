# 本地章节播放原型

原型复用 `.pagestage/spike/out/aq-synth-1.json`、对应剧本与已保存音频，准备一份可迁移到模拟器的素材。原文来自仓库的《阿Q正传》夹具。整个过程在本地执行，素材保存在 Git 忽略目录中。

## 运行

在仓库根目录准备素材：

```sh
dart run packages/app/tool/prepare_playback.dart
```

首次在模拟器安装原型后，把素材复制到 App 私有目录。iOS 与 Android 分别运行：

```sh
python3 packages/app/tool/install_playback_fixture.py ios
python3 packages/app/tool/install_playback_fixture.py android
```

在 `packages/app` 启动原型，或切换比较引擎：

```sh
flutter run -t lib/playback/prototype_main.dart
flutter run -t lib/playback/prototype_main.dart --dart-define=PLAYBACK_ENGINE=soloud
```

`--device` 可以指定素材安装的模拟器 UUID 或 adb serial。Flutter 重新安装测试 App 时可能重建私有目录，测试出现 `WAITING_FOR_PLAYBACK_FIXTURE` 后再次执行安装素材命令即可。

## 播放接口与时间轴

`PlaybackQueue` 把 `SynthesizedUtterance` 的音频时长和 `pauseBefore` 排入同一时间轴，保留合并台词到音频的映射。`writeWav` 逐段复制已统一响度的 PCM，再填入指定数量的静音采样。引擎读取一条连续 WAV，跳转到台词的音频起点。非正文保留显示，并从播放队列中跳过。

`ChapterPlayer` 提供播放、暂停、上一条、下一条、指定台词和倍速；`PlaybackHandler` 将 audio_service 的系统控制交给同一个播放器。原型正文使用 `PsPassage`，迷你播放器使用 `PsMiniPlayer`。点击台词只打开菜单，选择「从这里播放」才跳转。

## 验证

```sh
cd packages/app
flutter test test/playback/playback_test.dart
flutter test integration_test/playback_test.dart -d <device>
flutter test integration_test/playback_test.dart -d <device> --dart-define=PLAYBACK_ENGINE=soloud
```

集成测试对每一条台词测量跳转，分别运行 0.5、1、3 倍速，然后以 3 倍速从头播放至完成，检查全部 13 个音频区间都经过播放时间轴。测试输出 `PLAYBACK_RESULT` JSON。单元测试直接检查 PCM 中的静音长度和原始语音采样，验证合并台词、跳过的台词与时间映射；widget 测试验证台词菜单；系统控制通过 `PlaybackHandler` 的公共接口测试。

2026-10-24，本机 iOS 27 的 iPhone 18 Pro 模拟器及 Android API 36 模拟器使用约 439.36 秒的章节音频。已记录的结果如下：

| 引擎 | 平台 | 13 次跳转耗时 | 3 倍速完整播放耗时 | 经过音频区间 |
| --- | --- | --- | --- | --- |
| just_audio 0.10.6 | iOS | 1–6 ms | 146.615 秒 | 13/13 |
| just_audio 0.10.6 | Android | 8–50 ms | 146.227 秒 | 13/13 |
| flutter_soloud 5.2.1 | iOS | 0–3 ms | 146.240 秒 | 13/13 |
| flutter_soloud 5.2.1 | Android | 0–2 ms | 146.242 秒 | 13/13 |

毫秒数是本机模拟器测量值，跳转耗时记录从调用跳转到暂停完成的时间。测试允许位置误差 250 ms；这些数值用于比较本次原型，不作为移动设备性能承诺。

选型采用 just_audio，原因见 [ADR-0007](adr/0007-just-audio-for-chapter-playback.md)。对应依赖与使用方式来自 [just_audio](https://pub.dev/packages/just_audio)、[audio_service](https://pub.dev/packages/audio_service) 和 [flutter_soloud](https://pub.dev/packages/flutter_soloud) 的维护者文档；音调处理同时核对了锁定版本的原生实现。

锁屏和通知栏接入 audio_service，iOS 配置音频后台模式，Android 配置媒体前台服务，并声明播放/暂停切换、跳句、进度与倍速动作。系统控制的验证记录：

- Android API 36：系统生成了包含上一句、暂停和下一句的媒体通知。通过 `adb shell cmd media_session dispatch` 验证暂停后进度保持、下一句定位到 33.179 秒、上一句回到 0 秒、恢复播放后进度继续推进。
- iOS 27：锁屏后后台音频持续播放。读取原生 `MPNowPlayingInfoCenter` 确认章节、书名、时长、播放速率和进度正确；原生暂停、上一句和下一句命令均已启用。本机模拟器未稳定显示锁屏控制按钮，锁屏交互验收尚未通过，需要在真机或另一 iOS 运行时复核。[audio_service 上游也有模拟器控件缺失的报告](https://github.com/ryanheise/audio_service/issues/1034)，目前不能据此认定本次问题的根因。

连续播放和 PCM 验证已自动执行，是否存在可感知爆音及倍速听感仍需人工试听。

人工验证清单与结果统一记录在 [#56：iOS 锁屏控制与章节播放听感](https://github.com/dayeguilaiye/pagestage/issues/56)。用户同意先合并实现，后续有空时按该清单补验。
