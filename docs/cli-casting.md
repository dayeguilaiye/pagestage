# CLI 选角与试音

为已建档的书推荐选角：

```sh
dart run packages/core/bin/pagestage.dart cast recommend <book-id>
dart run packages/core/bin/pagestage.dart cast list <book-id>
dart run packages/core/bin/pagestage.dart cast catalog --language zh
```

`recommend` 默认让台词量前 20 个正式角色独占音色，用 `--exclusive-count 5` 调整数量。旁白按书的语言选择，身份在揭晓前另有音色。`--provider minimax` 或 `--provider bailian` 限定推荐目录；默认 `all` 使用两家目录。百炼目录可用 `--region beijing|singapore` 指定区域，默认北京。目录容量不足时返回错误，保留已保存的选角。

群演按性别、年龄段匹配，优先避免同章共用音色；目录不足时输出复用提示。现有音色在延伸建档、补入临时角色时保持稳定，新增临时角色沿用已保存的专属数量、服务商和区域选择。手动换音色和设计音色在重新推荐时继续保留。

```sh
dart run packages/core/bin/pagestage.dart cast set <book-id> <speaker-id> 'minimax:Chinese (Mandarin)_Gentleman'
dart run packages/core/bin/pagestage.dart cast audition <book-id>
dart run packages/core/bin/pagestage.dart cast audition <book-id> --speaker <speaker-id> --output-dir ./samples
```

从 `catalog` 输出复制完整的 `provider:voice-id`；其中空格也属于 ID。`audition` 使用已选择的音色生成 WAV 样音，默认保存到数据目录的 `samples/<book-id>`。每个说话人的音色记录保存声音描述、样音路径和服务商绑定，演员表引用稳定的本地音色 ID。换音色后会使用新的绑定和样音记录。

试音需要相应服务商的 key。通过 `MINIMAX_API_KEY`、`BAILIAN_API_KEY` 配置，或传入 `--config <本地 JSON 文件>`；环境变量优先。`MINIMAX_BASE_URL`、`BAILIAN_BASE_URL` 和 `BAILIAN_REGION` 的格式见 [TTS CLI](cli-tts.md)。百炼试音的 key、接口地址和区域应与选角时指定的区域一致。推荐目录本身可离线使用。

身份揭晓后的台词使用所属角色的音色。所属角色在揭晓前没有出场时，首次解析揭晓后的章节会保存一份独立的继承音色；随后调整身份的音色只影响揭晓前的台词。手动为所属角色选音色会成为揭晓后使用的音色。`cast list` 显示名字、音色和样音，不输出身份关系或角色档案。

## 目录来源

内置目录含 143 个真实预设绑定：中文 83 个、英文 60 个，检索日期为 2026-10-23。MiniMax 默认模型为 `speech-2.8-hd`，百炼为 `qwen-audio-3.1-tts-flash`。

- [MiniMax 预设音色目录](https://platform.minimax.io/docs/faq/system-voice-id)
- [百炼 Qwen-Audio 音色目录](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-voice-list)

目录中的性别和年龄段用于推荐。`tagProvenance` 记录各字段来自服务商标签、名称推断或未知；年龄段推断尚未经过试听。百炼条目保留文档中的区域约束和完整 `_v3.1` ID。实际可用性、声音适配程度和两本书的试听结果待配置真实 key 后验收。

## 模块接口

`Casting.recommend` 保存选角，`selectPreset` 更换预设，`selectVoice` 保存已选定的自定义音色，`audition` 生成样音。`bindingsForChapter` 提供指定章节的有效绑定，负责身份揭晓和新增临时角色的补选角；合成模块应使用这个入口。`Voice` 与服务商的 `VoiceBinding.voiceId` 分别存储，角色合并可以保留已有的稳定音色引用。
