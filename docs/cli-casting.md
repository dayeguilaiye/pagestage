# CLI 选角与试音

为已建档的书推荐选角：

```sh
dart run packages/core/bin/pagestage.dart cast recommend <book-id>
dart run packages/core/bin/pagestage.dart cast list <book-id>
dart run packages/core/bin/pagestage.dart cast catalog --language zh
```

`recommend` 默认将台词量前 20 个正式角色列为优先独立配音对象，用 `--exclusive-count 5` 调整数量。旁白按书的语言选择，身份在揭晓前单独参与选角。`--provider minimax` 或 `--provider bailian` 限定推荐目录；默认 `all` 使用两家目录。百炼目录可用 `--region beijing|singapore` 指定区域，默认北京。

推荐先比较性别、年龄段，再以说话风格和资料完整度细分匹配程度。同等匹配时，优先角色尽量使用独立音色，群演尽量避开优先角色及同章群演已用的音色。候选不足时自动使用相近年龄、未知标签或其他性别的候选，也允许复用最匹配的音色。只要当前语言、服务商和区域存在可用预设，就为全部说话人完成分配；偏差和复用作为非阻断提示输出，用户可用 `cast set` 调整。当前配置完全没有兼容预设时，返回错误并保留已保存的选角。

旁白优先使用经过试听核对的候选，其次使用官方描述明确提到旁白、讲故事或有声书的候选，最后从其他兼容音色中选择；旁白未提供声音风格时，偏好沉稳、清晰的表达。`narratorReview` 记录试听核对状态，官方适用场景并不代表已做人工试听。

延伸建档、补入临时角色时保留已有音色，并沿用已保存的优先角色数量、服务商和区域选择。显式执行 `cast recommend` 会按当前目录重新推荐自动音色，手动选择、设计音色及身份揭晓后已保存的继承音色保持稳定。

```sh
dart run packages/core/bin/pagestage.dart cast set <book-id> <speaker-id> 'minimax:Chinese (Mandarin)_Gentleman'
dart run packages/core/bin/pagestage.dart cast audition <book-id>
dart run packages/core/bin/pagestage.dart cast audition <book-id> --speaker <speaker-id> --output-dir ./samples
```

从 `catalog` 输出复制完整的 `provider:voice-id`；其中空格也属于 ID。`audition` 使用已选择的音色生成 WAV 样音，默认保存到数据目录的 `samples/<book-id>`。每个说话人的音色记录保存声音描述、样音路径和服务商绑定，演员表引用稳定的本地音色 ID。换音色后会使用新的绑定和样音记录。

试音需要相应服务商的 key。通过 `MINIMAX_API_KEY`、`BAILIAN_API_KEY` 配置，或传入 `--config <本地 JSON 文件>`；环境变量优先。`MINIMAX_BASE_URL`、`BAILIAN_BASE_URL` 和 `BAILIAN_REGION` 的格式见 [TTS CLI](cli-tts.md)。百炼试音的 key、接口地址和区域应与选角时指定的区域一致。推荐目录本身可离线使用。

身份揭晓后的台词使用所属角色的音色。所属角色在揭晓前没有出场时，首次解析揭晓后的章节会保存一份独立的继承音色；随后调整身份的音色只影响揭晓前的台词。手动为所属角色选音色会成为揭晓后使用的音色。`cast list` 显示名字、音色和样音，不输出身份关系或角色档案。

## 目录来源

内置目录含 184 个官方预设绑定：中文 113 个、英文 71 个，官方表检索日期为 2026-10-24。MiniMax 默认模型为 `speech-2.8-hd`，百炼为 `qwen-audio-3.1-tts-flash`。百炼收录该模型普通话和英文条目，保留区域约束及完整 `_v3.1` ID；文档只声明其他语言或方言的条目按其支持范围单独核对后再纳入。当前目录的百炼普通话预设在北京区可用，英文预设在北京和新加坡区可用。

- MiniMax 的[中文音色表](https://platform.minimax.cn/docs/faq/system-voice-id)和[英文音色表](https://platform.minimax.io/docs/faq/system-voice-id)提供名称和语言，合并收录 120 个中英文预设；[Get Voice API](https://platform.minimax.cn/docs/api-reference/voice-management-get)提供系统音色名称和描述。
- [百炼 Qwen-Audio 音色表](https://help.aliyun.com/zh/model-studio/qwen-audio-tts-voice-list)提供性别、声线特质、适用场景及口音。

原始资料保存在 `packages/core/tool/voice_sources/`。`tagProvenance` 记录标签来源和推断依据，`metadataGaps` 记录资料缺口；`styles` 使用中英文说话风格词表。明确的人生阶段词映射到儿童、少年、青年、中年、老年；“甜美”“沉稳”等风格词和单独的 girl、lady 等名称保留未知年龄。每项旁白候选记录 `narratorReview`；当前资料未经过人工试听。

2026-10-24 的系统音色 API 快照返回 303 项，其中 74 项与本目录匹配，34 项提供详细描述；其余条目保留官方名称及资料缺口。官网列出但 API 未返回的 46 项标记 `apiMetadata` 缺口，继续作为官方候选保留。`English_expressive_narrator` 属于这一类，已用当前模型验证合成可用。音色 ID 按服务商原样保留，包括 `Santa_Claus ` 末尾的空格。

详细描述优先于名称进行标签整理，例如 `Gentle_Senior` 的 API 描述明确为青年学姐，因此标记为青年女性。API 原始名称与描述保存在资料快照中，未说明的年龄继续保留未知。

更新公开资料快照后，离线生成内置目录：

```sh
dart run packages/core/tool/build_preset_catalog.dart
```

获得真实请求授权后，查询一次 MiniMax 系统音色元数据并导入目录：

```sh
dart run packages/core/tool/sync_minimax_voices.dart --config .pagestage/providers.json
dart run packages/core/tool/build_preset_catalog.dart --minimax-metadata .pagestage/minimax-system-voices.json
```

DNS 查询失败时，可以先用 `dig @1.1.1.1 api.minimax.cn A` 查询配置中的服务商域名，再给同步命令添加 `--connect-address <解析出的 IP>`。此选项只影响本次连接，保留原域名的 TLS 握手、证书校验与 HTTP Host；IP 应在请求前重新查询。

同步工具只请求 `get_voice` 的 `system` 类别一次，不重试、不生成音频，输出仅包含系统音色的公开名称和描述；失败时保留已有快照。导入工具按官方表的 ID 关联描述并保存来源与时间；新增 ID、语言、模型或区域需先核对官方文档，再更新快照。试听核对通过后，可以在对应原始条目中填写 `narratorReview: approved` 和 `reviewNotes`，记录核对人、日期和试听依据，再离线生成目录。

离线测试使用《阿Q正传》和 *Pride and Prejudice* 前五章已保存的演员表，覆盖正确候选优先、资料缺失、音色复用、旁白兜底、手动选择及续跑。这些测试验证推荐和绑定规则；声音适配程度由试听判断。

## 模块接口

`Casting.recommend` 保存选角，`selectPreset` 更换预设，`selectVoice` 保存已选定的自定义音色，`audition` 生成样音。`prepareChapterBindings` 保存说话人的章节出场记录、为新增临时角色补选角、保存身份揭晓时的音色继承，返回指定章节的有效绑定；合成模块使用这个入口完成音色准备。`Voice` 与服务商的 `VoiceBinding.voiceId` 分别存储，角色合并可以保留已有的稳定音色引用。
