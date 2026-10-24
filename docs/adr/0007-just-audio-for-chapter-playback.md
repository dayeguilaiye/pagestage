# 章节播放采用 just_audio

App 使用 just_audio 播放合成音频，audio_service 统一页面、后台、锁屏和通知栏控制。台词音频与停顿组成一条 PCM 时间轴，台词保留对应的时间区间；播放和跳转使用同一份映射。

选择的关键是语音在 0.5–3 倍速下保持音调。just_audio 0.10.6 在 Android 的 `PlaybackParameters` 中独立设置速度和音调，在 iOS 配置 AVPlayer 的 TimeDomain 音调处理。flutter_soloud 5.2.1 的 `setRelativePlaySpeed` 改变有效采样率，普通变速会影响音调，需要额外处理。

两个引擎都实现了同一播放接口，使用本地《阿Q正传》第 1 章比较完整播放和逐条跳转。测试命令、测量结果与验收范围见 [播放原型](../playback-prototype.md)。
