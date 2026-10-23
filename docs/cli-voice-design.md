# CLI 音色设计

先导入并建档，再为演员表中的说话人生成候选：

```sh
dart run packages/core/bin/pagestage.dart voice-design generate <book-id> <speaker-id> \
  --provider minimax --count 3 \
  --description '年轻男性，清晰温和的中音，语速平稳，略带沙哑。' \
  --config .pagestage/providers.json

dart run packages/core/bin/pagestage.dart voice-design list <book-id> --speaker <speaker-id>
dart run packages/core/bin/pagestage.dart voice-design select <book-id> <speaker-id> <candidate-id> \
  --config .pagestage/providers.json
```

`generate` 默认生成 3 个候选，`--count` 最少为 3。省略 `--description` 时使用角色档案中的声音描述。`--preview-text` 可以指定统一的试音文字；默认使用与书籍语言一致的短句。每个候选包含独立 ID、声音描述、服务商绑定和样音的绝对路径。用本地播放器打开 JSON 中的 `voice.samplePath` 试听，再把候选 ID 传给 `select`。

样音默认保存在数据目录下的 `voice-candidates/<book-id>/`，可用 `--output-dir` 指定位置。每个成功候选立即保存；后续候选失败时，可用 `list` 找回已经生成的候选。生成候选保留当前选角；`select` 成功后调用 Casting 保存所选音色，后续试音和章节合成都使用该绑定。

MiniMax 的设计接口返回十六进制试听数据，CLI 根据实际 WAV/MP3 容器保存正确扩展名。选择时只对选中的候选立即合成一次，成功后保存 `.selected.wav` 并更新演员表；激活合成失败时保留原选择。原始候选样音同时保留。此流程遵循 [MiniMax 音色设计接口](https://platform.minimax.io/docs/api-reference/voice-design-design)。

百炼使用 `--provider bailian`，配置 `bailian.region` 或 `BAILIAN_REGION` 为 `beijing`。默认目标模型为 `qwen-audio-3.1-tts-flash`，可用 `--model` 指定支持的 3.0/3.1 flash/plus 模型。目标模型会完整保存，后续合成使用同一模型。描述最多 500 个 Unicode 字符，试音文字为 15–200 个字符。设计时请求 WAV；选择时保存该样音。设计绑定带有 `designed=true` 与北京区域标记。参见 [百炼设计接口](https://help.aliyun.com/en/model-studio/voice-design-api-references) 和 [支持模型及约束](https://help.aliyun.com/en/model-studio/voice-design-user-guide)。

服务商 key、区域、地址和模型复用 [TTS 配置](cli-tts.md)。`--model` 优先于配置；未指定时使用该服务商配置的模型。`list` 和百炼候选的 `select` 可离线执行。MiniMax 的 `select` 需要对应 key 完成激活。

离线测试覆盖候选生成/保存、选择、原绑定保留、后续绑定读取，以及依据官方文档构造的 HTTP 协议样例。两本测试书主角各至少三个真实候选的听感验收待 key 配置后执行，跟踪在 GitHub issue #11。
