# Ming Android 初期预研结果

2026-11-11，通过 adb 在用户手机 Xiaomi 24031PN0DC（SM8650 / 骁龙 8 Gen 3，约 16 GB RAM）运行。应用已经安装，模型已经放入手机，打开“Ming 0.5B 语音实验室”即可离线测试。

| 测试 | 语音时长 | 生成耗时 | RTF | 首段音频 | 采样峰值 PSS |
|---|---:|---:|---:|---:|---:|
| GPU 首句，高兴，冷加载 | 4.56 s | 7.70 s | 1.69 | 生成阶段约 2.85 s；含加载 34.69 s | 4.74 GiB |
| GPU 完整八句对话，热态 | 29.68 s | 50.77 s | 1.71 | 2.74 s | 4.48 GiB |
| GPU 首句，中性 | 4.32 s | 7.51 s | 1.74 | 正常分块输出 | 记录见原始报告 |

用户试听反馈（2026-11-11）：**“手机端音质和电脑没什么差别，还是不错的，就是生成速度有点慢。”**

完整对话实测 **RTF 1.71**：29.68 秒语音生成耗时 50.77 秒，生成速度约为实时的 0.58 倍，内存约 4.5–5 GiB。已实现分块生成和播放，完整对话测得 20 次 AudioTrack underrun。本轮记录为：手机音质与电脑基本一致、仍然不错，生成速度偏慢。

CPU 四线程对照在约 173.5 秒时取消，未输出首段音频，采样峰值 PSS 约 8.50 GiB；交付界面使用已验证的 GPU 路线。

完整对话、情绪切换、单句生成、停止、历史记录、复制报告均已实际操作。完整八句有效且正常停止；单句和完整音频拼接一致，无削波样本。首句和第七句的本地 Whisper 抽查与台词一致。Android tokenizer 的 16 组请求与官方 Python 输入一致。Flutter 分析、界面测试及 Android 输入契约测试通过。

原始记录：[GPU 完整对话](../artifacts/ming-android/dialogue-gpu/report.json)、[完整音频](../artifacts/ming-android/dialogue-gpu/dialogue.wav)、[首句](../artifacts/ming-android/first-gpu/report.json)、[中性对照](../artifacts/ming-android/neutral-gpu/report.json)、[CPU 取消记录](../artifacts/ming-android/cpu-final/report.json)。

APK：[ming-tts-lab-arm64.apk](../artifacts/apks/ming-tts-lab-arm64.apk)。APK 约 30.5 MB，模型约 2.12 GB，已分别安装和复制到手机。参考音色特征预先在电脑提取；手机端执行全部语音生成。操作与复现见 [README.md](README.md)。

## 2026-11-19 · 小米 14 Ultra（SM8650）GPU 与 NPU 对照

同一台手机使用 LiteRT 2.2.0、高通 QAIRT 2.47.0 和 Hexagon V75。三组均使用《两张门票》原八句、相同参考音色、显式情绪、种子 1895、十步 flow、16 latent 增量解码，并开启实时播放。每组先用第一句预热，再计完整八句；全 NPU 增加一次热态复测。RTF 为逐句生成总耗时除以有效语音总时长，排除模型加载、首次编译和句间插入的静音。首段从热态测试开始计至第一块 PCM 可用。

| 模型图后端 | 语音 | 生成 | RTF | 首段 PCM | AudioTrack 缓冲欠载次数 | 试听 |
|---|---:|---:|---:|---:|---:|---|
| 纯 GPU | 29.68 s | 50.764 s | 1.7104 | 2.71 s | 20 | [WAV](../artifacts/ming-android/8gen3-npu-comparison/gpu/dialogue.wav) |
| 仅 flow 用 NPU | 30.16 s | 41.503 s | 1.3761 | 2.22 s | 19 | [WAV](../artifacts/ming-android/8gen3-npu-comparison/flow-npu/dialogue.wav) |
| 全 NPU | 29.60 s | 29.519 s | 0.9973 | 1.49 s | 1 | [WAV](../artifacts/ming-android/8gen3-npu-comparison/all-npu/dialogue.wav) |
| 全 NPU 热态复测 | 29.60 s | 32.168 s | 1.0868 | 1.59 s | 1 | [WAV](../artifacts/ming-android/8gen3-npu-comparison/all-npu-repeat/dialogue.wav) |

全 NPU 两次合计 RTF 为 1.042，长时间稳定快于实时仍待验证。复测与首轮全 NPU 的 WAV 文件 SHA-256 完全相同。四轮均完成全部八句，参考条件与历史 GPU 基线逐句一致，已校验输出时长、非静音和拼接顺序。三种配置的第 1、7 句通过本地 Whisper small 内容抽查。原始报告和逐句音频保存在各试听文件所在目录。[设备后端日志](../artifacts/ming-android/8gen3-npu-comparison/placement.log)

### 7 步 flow · 全 NPU 三轮热态复测

同一台 SM8650，同日复用上表的全 NPU 10 步录音作为试听基线。7 步使用相同 checkpoint，按 EPSS 七步时间表重新导出 FP16 权重图和匹配的时间嵌入。高通编译器选择了该图的全部 2,000 个算子。音色、情绪、文本、种子、CFG、解码块和播放配置沿用上轮；预热首句后连续测三轮。

| 轮次 | 有效语音 | 生成时间 | RTF | 播放缓冲欠载 |
|---|---:|---:|---:|---:|
| 1 | 29.12 s | 28.781 s | 0.9884 | 1 |
| 2 | 29.12 s | 28.697 s | 0.9855 | 1 |
| 3 | 29.12 s | 28.790 s | 0.9887 | 1 |

三轮整段 RTF 均低于 1，每轮提前 0.33–0.42 秒完成。三份 WAV 逐字节一致，八句全部正常停止，输出无削波样本。分轮报告与逐句录音见[真机实测目录](../artifacts/ming-android/8gen3-npu-s7/)，可直接对照[七步整段](../artifacts/ming-android/8gen3-npu-s7/run-1/dialogue.wav)与[十步整段](../artifacts/ming-android/8gen3-npu-comparison/all-npu/dialogue.wav)。

2026-11-19 用户完成 7 步与 10 步同机对照试听，反馈“7 步没有 10 步的清晰，还是有点明显”。7 步三轮合计 RTF 0.9875，速度收益伴随可感知的清晰度下降。后续优化保留 10 步 flow，以原 10 步录音作为清晰度基线。

### 10 步 flow · 短句 KV 缓存

同一台小米 14 Ultra，全 NPU，先测 512 位置原版两轮，再测 256 位置实验版三轮，最后切回原版两轮。逐组用首句预热。实验版用相同权重和精度重新导出语言模型的 prefill、step 两张图，将历史 KV 输入从 511 槽缩至 255 槽。八句保留完整上下文，每轮有效语音均为 29.60 秒。256 上限包含提示与生成帧，长句仍可选用原版。

| 配置与轮次 | 生成秒数 | RTF | LM 逐帧秒数 | flow 秒数 | 播放缓冲欠载 |
|---|---:|---:|---:|---:|---:|
| 原版 512，前测 1 | 30.804 | 1.0407 | 7.02 | 20.50 | 1 |
| 原版 512，前测 2 | 28.581 | 0.9656 | 6.99 | 18.37 | 1 |
| 短句 256 1 | 28.504 | 0.9630 | 6.84 | 18.43 | 1 |
| 短句 256 2 | 28.544 | 0.9643 | 6.85 | 18.48 | 1 |
| 短句 256 3 | 30.460 | 1.0291 | 6.96 | 20.25 | 1 |
| 原版 512，回测 1 | 32.352 | 1.0930 | 7.23 | 21.62 | 3 |
| 原版 512，回测 2 | 32.331 | 1.0923 | 7.24 | 21.60 | 2 |

七轮整段 WAV 与先前的 10 步基线逐字节一致。短缓存下 LM 逐帧耗时略有下降，三轮中两轮快于实时。flow 耗时的轮间波动大于缩小 KV 缓存带来的 LM 节省。继续以 10 步作为声音基线，短缓存保留为短句实验配置。[各轮原始数据、图尺寸和设备日志](../artifacts/ming-android/8gen3-npu-ctx256/)

### 2026-11-20 · 10 步 flow 末层前馈裁剪

小米 14 Ultra（骁龙 8 Gen 3），全 NPU。每个 flow 求解步有八个 Transformer 层，最后一层只取六行中的最后两行输出。实验图把已有的行切片移到最后一层的前馈网络之前，使十个求解步的末层各计算两行。注意力仍使用全部输入。两图均含 2,834 个算子，159 个缓冲区中的常量数据逐字节相同。按全连接层张量形状计算，每次 flow 调用的理论乘加量从 61.067 亿降至 57.711 亿，下降 5.50%。高通编译器将实验图全部算子分配到同一个 NPU 分区。桌面 LiteRT CPU 的 12 组固定输入获得逐位相同的输出。[图生成脚本](../tools/prune_ming_flow_ffn.py) · [图结构与权重校验](../artifacts/ming-android/8gen3-npu-flow-lastrows/graph-check.json) · [NPU 编译记录](../artifacts/ming-android/8gen3-npu-flow-lastrows/placement.log)

两版沿用原八句、参考音色、情绪提示、种子 1895、512 位置语言模型、16 latent 解码及实时播放配置。每次正式计时前单独预热首句，四组内轮换运行顺序。每轮均正常生成 370 帧、29.60 秒人声。下表为逐句生成总耗时及 RTF，排除加载、首次编译、句间静音与等待播放结束的时间。

| 配对 | 顺序 | 原版生成 | 裁剪版生成 | 原版 RTF | 裁剪版 RTF |
|---|---|---:|---:|---:|---:|
| 1 | 原版 → 裁剪版 | 30.232 s | 30.273 s | 1.0214 | 1.0227 |
| 2 | 裁剪版 → 原版 | 30.819 s | 30.100 s | 1.0412 | 1.0169 |
| 3 | 裁剪版 → 原版 | 32.738 s | 33.018 s | 1.1060 | 1.1155 |
| 4 | 原版 → 裁剪版 | 32.782 s | 32.642 s | 1.1075 | 1.1028 |
| 四轮平均 | | 31.643 s | 31.508 s | 1.0690 | 1.0645 |

裁剪版平均每段节省 0.135 秒（0.43%），两组更快、两组更慢。整段内 flow 累计耗时平均从 20.950 秒降至 20.639 秒。所有轮次的八份单句 WAV 和整段 WAV 均与 11 月 19 日原始 10 步参考逐字节一致，整段 SHA-256 为 `60fca36269c0c3f7c8d61d8f23f01ef3145459ec8d5b72773594e9599847ba75`。[逐轮报告与音频校验](../artifacts/ming-android/8gen3-npu-flow-lastrows/comparison.json) · [原版试听](../artifacts/ming-android/8gen3-npu-flow-lastrows/pair-1-A/dialogue.wav) · [裁剪版试听](../artifacts/ming-android/8gen3-npu-flow-lastrows/pair-1-B/dialogue.wav)

另在手机同一个 LiteRT 环境中加载两张 flow 图，用相同的八组固定伪随机输入与原十步时间嵌入预热。随后做 32 组配对，每组每版各执行八次，轮换先后顺序。计时包含输入写入、NPU 推理及结果读回。每版 256 次调用，原版平均 59.031 毫秒，裁剪版 59.487 毫秒，多用 0.77%。32 组中裁剪版有 4 组更快，八组输入的输出逐位一致。本机上的整段生成耗时相近，单独计时的 flow 略慢，继续采用原始全 NPU 10 步图。实验版可通过 `all-npu-ffn2` 重测。[逐对计时](../artifacts/ming-android/8gen3-npu-flow-lastrows/flow-call-pairs.json) · [真机测试实现](android/app/src/androidTest/kotlin/dev/pagestage/lab/ming_tts_lab/FlowComparison.kt)

### 2026-11-20 · 原始十步 flow 的双句批处理

上轮四次原版串行测试平均用时 31.64 秒，其中 flow 调用累计 20.95 秒（66.2%），逐帧语言模型累计 7.28 秒（23.0%）。本次从原始十步 FP16 权重导出支持两句独立输入的 flow 图。每句使用各自的音色、情绪、随机序列、语言模型缓存和解码状态。两句各准备好一帧时，让 NPU 用同一组权重计算两帧，各自执行完整十步。一句结束后，另一句的剩余帧使用原始单句图。八句共 370 帧，按相邻台词两两配对后，执行 174 次双帧和 22 次单帧 flow 调用。[导出脚本](../tools/export_ming_flow_pair.py) · [两句的逐帧调度](../../packages/app/android/app/src/main/kotlin/com/ming3tts/MatrixBatch.kt)

双句图与原图的 45 份 FP16 权重缓冲逐字节匹配。高通编译器将双句图 2,861 个算子全部放入同一个 NPU 分区。桌面检查改变第二句输入时第一句的输出恒定。在手机上比较八组不同输入，单句分别运行、双句合批及两句交换顺序，按句对应后的最大绝对误差均为 0。首次手机端编译实测经过 622.6 秒，期间系统曾挂起后台测试进程，随后一次从缓存加载双句图耗时 1.37 秒。[图结构、权重与桌面验证](../artifacts/ming-android/8gen3-npu-flow-pair/export-check.json) · [手机数值校验](../artifacts/ming-android/8gen3-npu-flow-pair/npu-parity.json) · [设备日志](../artifacts/ming-android/8gen3-npu-flow-pair/placement.log)

两版均在同一台小米 14 Ultra、同一个保持唤醒的实验进程中使用全 NPU、512 位置语言模型和 16 latent 增量解码。先各用前两句预热，再交替完成四组完整八句。每轮重新生成录音，按台词顺序流式播放并写出逐句和整段 WAV。生成耗时从正式开始合成计至最后音频写完，按实际经过时间计算，分母只计有效人声。首段为第一句的 PCM 可交给播放器的时间。[真机对照实现](android/app/src/androidTest/kotlin/dev/pagestage/lab/ming_tts_lab/PairDialogue.kt)

| 配对 | 顺序 | 单句串行生成 | 双句批处理生成 | 串行 RTF | 双句 RTF |
|---|---|---:|---:|---:|---:|
| 1 | 串行 → 双句 | 32.769 s | 24.090 s | 1.1071 | 0.8138 |
| 2 | 双句 → 串行 | 32.762 s | 23.929 s | 1.1068 | 0.8084 |
| 3 | 双句 → 串行 | 32.980 s | 24.211 s | 1.1142 | 0.8180 |
| 4 | 串行 → 双句 | 33.192 s | 24.386 s | 1.1213 | 0.8239 |
| 四轮平均 | | 32.926 s | 24.154 s | 1.1124 | 0.8160 |

本轮串行生成的 32.93 秒中，flow 累计 21.42 秒（65.0%），逐帧语言模型 7.71 秒（23.4%），将声学帧转为下一帧输入的聚合器 2.17 秒（6.6%）。提示词预填充 0.77 秒，后台解码器 0.88 秒，后者会与其他工作重叠。双句模式的 flow 累计降至 12.55 秒，其中双帧调用 11.26 秒、单帧收尾 1.28 秒。整段实际生成时间平均缩短 8.77 秒（26.6%），四组分别节省 8.68、8.83、8.77、8.81 秒。两版每轮生成 29.60 秒有效人声，每轮起止采样的 Android 温控状态均为 0。正式测试期间只对本次实验进程临时禁止系统后台冻结，该设置随进程结束失效。[分轮原始数据与校验](../artifacts/ming-android/8gen3-npu-flow-pair/comparison.json)

两种模式各四轮的八个单句和整段 WAV 均与原始十步参考逐字节一致，整段 SHA-256 为 `60fca36269c0c3f7c8d61d8f23f01ef3145459ec8d5b72773594e9599847ba75`。双句模式适用于已有后续台词的章节，平均首段 PCM 从 1.60 秒变为 2.29 秒。仅有一条台词时使用原始单句图。逐句与整段 WAV 已复制到电脑桌面的「Ming 10步试听 · 双句合批」。[串行试听](../artifacts/ming-android/8gen3-npu-flow-pair/pair-1-A/dialogue.wav) · [双句批处理试听](../artifacts/ming-android/8gen3-npu-flow-pair/pair-1-B/dialogue.wav)

复测使用实验室的测试入口 `dev.pagestage.lab.ming_tts_lab.test/dev.pagestage.lab.ming_tts_lab.FlowPairBenchmark`。双句图的文件名为 `flow_r4b_s10_pair_wfp16.tflite`，与原模型共用手机模型目录。`adb shell am instrument -w -e mode prepare <测试入口>` 预编译并核对两路输出，`-e mode dialogue` 执行四组完整对照。

### 2026-11-20 · 双句语言模型逐帧推理

在同一台小米 14 Ultra 上，两组实验都用原始 10 步、双句 flow、512 位置上下文、16 帧增量解码，以及《两张门票》的相同音色、情绪和逐句种子 1895。每组单独预热，在同一进程中以 AB、BA、BA、AB 顺序交替运行八句。A 逐句提交语言模型，B 同时提交两句，先说完的一句退出后继续使用单句图。端到端计时到最后一个 WAV 写完为止，分母采用当轮实际生成的人声秒数。首段计时到第一段音频交给播放器为止。

**语言模型矩阵合批。** 两句共用 24 层注意力投影和前馈网络的矩阵运算，分别传入原有 KV 缓存、位置和掩码。高通编译器将 2,763 个算子放入同一个 NPU 分区。导出器将残差系数 0.25 折进 24 个注意力输出矩阵，其余 144 个 FP16 权重缓冲与原图逐字节相同。手机六组不同缓存位置的固定输入交换两路后输出相同，与单句计算的隐藏状态最大绝对差为 13.246。[导出实现](../tools/export_ming_step_pair.py) · [导出检查](../artifacts/ming-android/8gen3-npu-step-pair/export-check.json) · [NPU 数值检查](../artifacts/ming-android/8gen3-npu-step-pair/npu-parity.json)

| 矩阵合批实验 | 端到端平均 | 加权 RTF | 四轮 RTF 范围 | 首段平均 | LM 调用累计平均 |
|---|---:|---:|---:|---:|---:|
| A · 仅 flow 合批 | 20.269 s | 0.6848 | 0.6305–0.7471 | 2.107 s | 7.909 s |
| B · flow 和 LM 矩阵合批 | 17.990 s | 0.6082 | 0.5955–0.6219 | 1.666 s | 4.599 s |

四组配对分别节省 1.12、0.93、3.76、3.31 秒，整段平均缩短 11.2%。B 的四轮共 32 个逐句 WAV 均与十步参考有差异，人声时长依次为 29.60、29.60、29.52、29.60 秒。A 前三轮逐句和整段匹配参考，第四轮第二句有波形差异，八句时长仍分别匹配原版。各轮起止的 Android 温控状态均为 0。第一轮八句录音的离线 Whisper small 转写中，两版均有 7 句与台词用字对应（忽略标点与繁简），第 5 句的「发之前」均出现同音字偏差。CAM++ 逐句说话人向量余弦相似度为 0.885–0.963。音色、清晰度和情绪以录音试听为准。[四组耗时与逐句 SHA-256](../artifacts/ming-android/8gen3-npu-step-pair/comparison.json) · [转写](../artifacts/ming-android/8gen3-npu-step-pair/transcripts.json) · [说话人向量](../artifacts/ming-android/8gen3-npu-step-pair/speaker-check.json)

**两份原图联合提交。** 从正式单句 LM 文件直接生成双句图，保留每路算子、形状和运算次序。两路共用原来的 168 份 FP16 权重，各自传入六个输入，独立返回隐藏状态和当帧 KV。高通编译器将全部 3,514 个算子编进一个 NPU 分区。手机六组固定输入与逐句调用比较，三项输出最大误差均为 0，交换两句的位置后也均为 0。额外图文件为 683.6 MiB，首次手机编译经历 409.3 秒，期间小米系统曾冻结后台测试进程，打开实验室后继续编译。该时间单独记录。[原图组合脚本](../tools/pair_ming_step_graph.py) · [权重与桌面核对](../artifacts/ming-android/8gen3-npu-step-twin/export-check.json) · [手机数值核对](../artifacts/ming-android/8gen3-npu-step-twin/npu-parity.json)

| 原图联合提交实验 | 端到端平均 | 加权 RTF | 四轮 RTF 范围 | 首段平均 | LM 调用累计平均 |
|---|---:|---:|---:|---:|---:|
| A · 仅 flow 合批 | 20.644 s | 0.6974 | 0.6907–0.7076 | 1.980 s | 8.320 s |
| B · flow 合批和两份 LM 原图联合提交 | 22.026 s | 0.7436 | 0.7148–0.8107 | 2.115 s | 7.514 s |

联合提交四组分别多花 1.01、0.76、0.70、3.05 秒，平均耗时增加 6.7%。两版四轮各有 3 次播放器供数不足，起止的 Android 温控状态均为 0。A 的 32 个单句、4 段完整录音全都与原版一致。B 的 30 个单句、3 段完整录音与原版一致，第二轮第 1、8 句出现波形差异，其中第 1 句增加一帧（80 毫秒）。该图在正式实验中从编译缓存加载用时 4.59 秒。[四组耗时与逐句 SHA-256](../artifacts/ming-android/8gen3-npu-step-twin/comparison.json) · [设备日志](../artifacts/ming-android/8gen3-npu-step-twin/placement.log)

单独测逐帧 LM 时，每组固定六对输入，轮换顺序做 24 组。时间包含写入两句的 KV、执行 NPU 推理和取回两句的输出。矩阵版处理一对输入从 42.54 ms 降至 23.93 ms，24 组均提速。两份原图联合提交从 43.04 ms 降至 40.11 ms，24 组中有 21 组提速。这项局部节省在完整八句调度中伴随额外的逐帧同步，整段耗时以表中的实测为准。复测入口参数分别为 `time-step` 与 `time-twin`。[矩阵版逐组计时](../artifacts/ming-android/8gen3-npu-step-pair/step-call-times.json) · [原图版逐组计时](../artifacts/ming-android/8gen3-npu-step-twin/step-call-times.json)

用户试听第 2 句「太好了！我等这一场等了好久，终于能去了！」和第 8 句「好，那就别去了！我现在也没心情了！」后反馈「我没听出差别」。在试听页选用的第一轮录音中，从双句 flow 基线到语言模型矩阵合批，第 2 句由 3.76 秒变为 3.92 秒，第 8 句由 3.68 秒变为 3.52 秒。

用户选定原版 10 步的矩阵合批方案，以双句 flow 和双句语言模型作为后续批量大小对照的基线。电脑桌面「Ming 10步试听 · 双句语言模型」提供三版完整录音和逐句对照。基线和矩阵合批取第一轮，原图联合提交取出现差异的第二轮。[基线录音](../artifacts/ming-android/8gen3-npu-step-pair/pair-1-A/dialogue.wav) · [矩阵合批录音](../artifacts/ming-android/8gen3-npu-step-pair/pair-1-B/dialogue.wav) · [原图联合提交录音](../artifacts/ming-android/8gen3-npu-step-twin/pair-2-B/dialogue.wav)

实验入口为 `dev.pagestage.lab.ming_tts_lab.test/dev.pagestage.lab.ming_tts_lab.FlowPairBenchmark`。矩阵版依次使用 `-e mode prepare-step` 和 `-e mode dialogue-step`，原图版使用 `prepare-twin` 和 `dialogue-twin`。每种方案均需在同一时段与其自身的双句 flow 对照比较。[双句调度与端到端计时](android/app/src/androidTest/kotlin/dev/pagestage/lab/ming_tts_lab/PairDialogue.kt)

### 2026-11-20 · 双句与三句矩阵合批

小米 14 Ultra（骁龙 8 Gen 3，SM8650）使用已选的 Ming 原版 10 步、全 NPU、512 位置上下文和 16 帧增量解码。A 复用上一轮双句矩阵合批的语言模型和 flow 文件。B 在这两个环节同时算三句，每句拥有自己的音色、情绪、随机序列和 KV 缓存。A 将《两张门票》按顺序分成四对，B 将同样八句分为 1–3、4–6、7–8 句。每组按仍在生成的句数选用三句、双句或单句图，并按原台词顺序播放、写盘。两版每句的种子均为 1895。[三句图导出](../tools/export_ming_triple.py) · [逐帧调度](../../packages/app/android/app/src/main/kotlin/com/ming3tts/MatrixBatch.kt)

三句 flow 的 45 份 FP16 权重缓冲和语言模型的 168 份 FP16 权重缓冲分别与双句图逐字节相同。高通编译器分别把全部 2,873 和 3,512 个算子放入单个 NPU 分区。在手机上使用四组固定三句输入，比较双句和三句的对应输出、轮换三句位置、替换第三句后核对前两句，flow 潜变量与语言模型隐藏状态、K、V 的最大绝对误差均为 0。[权重与桌面校验](../artifacts/ming-android/8gen3-npu-matrix-three/export-check.json) · [手机 flow 校验](../artifacts/ming-android/8gen3-npu-matrix-three/probe-flow.json) · [手机语言模型校验](../artifacts/ming-android/8gen3-npu-matrix-three/probe-step.json)

每次启动独立测试进程，两版各用前三句预热，再按 AB、BA、BA、AB 交替运行完整八句。生成耗时从启动本轮合成计到整段 WAV 写完。RTF 的分母是有效人声时长，扣除七段各 0.35 秒的句间停顿。汇总使用总生成时间除以总有效人声时长。图编译和缓存加载在正式轮次前完成，播放器等待播完发生在生成计时结束后。[真机测试入口](android/app/src/androidTest/kotlin/dev/pagestage/lab/ming_tts_lab/FlowPairBenchmark.kt)

首段 PCM 计到首块音频交给播放器。首帧播放时间根据手机扬声器播放路径中 `AudioTrack` 的帧位置和呈现时间戳回推。首句出声采用这项估计加上 WAV 内的人声起点，以连续三个 10 ms 窗口的均方根电平达到 −45 dBFS 时的第一个窗口为起点。[播放器计时实现](android/app/src/main/kotlin/dev/pagestage/lab/ming_tts_lab/LabAudio.kt) · [Android 播放时间戳](https://developer.android.com/reference/android/media/AudioTrack#getTimestamp(android.media.AudioTimestamp))

三句图在保留双句图的基础上额外占用 878.3 MiB。三句 flow 和语言模型在首次真机准备中分别耗时 304.75 秒和 29.76 秒，flow 编译期间系统曾冻结后台测试进程。首次正式对照从缓存加载这两张图分别耗时 0.98 秒和 2.16 秒。复测入口为 `FlowPairBenchmark` 的 `prepare-triple`（固定输入校验）和 `dialogue-triple`（完整八句对照）。[编译与首次运行日志](../artifacts/ming-android/8gen3-npu-matrix-three/placement.log)

| 同机八组对照 | 生成八句均值 | 加权 RTF | RTF 范围 | 首段 PCM 就绪 | 扬声器首帧估计 | 首句出声估计 |
|---|---:|---:|---:|---:|---:|---:|
| 双句矩阵合批 | 19.95 s | 0.6739 | 0.6223–0.7297 | 1.90 s | 2.13 s | 2.25 s |
| 三句矩阵合批 | 19.80 s | 0.6689 | 0.5832–0.7274 | 2.79 s | 3.04 s | 3.16 s |

每轮八句逐句音频合计 29.60 秒，首句人声起点均在文件内 0.12 秒。三句在八组中有六组较早完成，生成八句平均省 0.15 秒（0.75%）。八组都是双句先出声，平均早 0.91 秒。两种方案各八轮的播放器均记录到每轮 3 次缓冲供数不足，各轮起止的 Android 温控状态均为 0。用户确认点播保留原版 10 步、全 NPU 的双句矩阵合批。[两次实验汇总及逐轮数据](../artifacts/ming-android/8gen3-npu-matrix-three/all-sessions.json)

本次实测由手机在首次加载时编译模型，并在应用缓存中保存结果。以双句逐帧语言模型为例，首次准备耗时 21.67 秒，随后在新进程中从缓存加载耗时 2.79 秒。双句方案所需的七张图在两次新进程中加载并创建输入输出缓冲区，计时合计分别为 8.47 秒和 10.89 秒。表中的 2.25 秒从模型就绪后开始合成计起。[双句模型首次和再次加载记录](../artifacts/ming-android/8gen3-npu-step-pair/placement.log) · [再次启动时的各模块计时](../artifacts/ming-android/8gen3-npu-matrix-three/placement.log)

| 实验与组次 | 双句 RTF | 三句 RTF | 双句首句出声估计 | 三句首句出声估计 |
|---|---:|---:|---:|---:|
| 首次 1 | 0.6225 | 0.5832 | 2.07 s | 2.74 s |
| 首次 2 | 0.6223 | 0.5913 | 2.05 s | 2.78 s |
| 首次 3 | 0.6269 | 0.5887 | 2.16 s | 2.80 s |
| 首次 4 | 0.6264 | 0.7274 | 2.05 s | 3.43 s |
| 复测 1 | 0.7135 | 0.7147 | 2.42 s | 3.40 s |
| 复测 2 | 0.7236 | 0.7154 | 2.41 s | 3.36 s |
| 复测 3 | 0.7297 | 0.7136 | 2.47 s | 3.37 s |
| 复测 4 | 0.7266 | 0.7165 | 2.40 s | 3.39 s |

首次实验的前三组三句各省 0.92–1.16 秒，第四组三句多用 2.99 秒。该组双句生成完成、等待播放结束期间，电脑的 USB 调试连接短暂中断。手机继续完成实验，取回的两版报告和录音均计入汇总。重连后按相同顺序再做四组，记录到的 USB 采样均在线，测试进程冻结采样为 0。复测的平均 RTF 为双句 0.7233、三句 0.7151，平均首帧播放时间为 2.30、3.26 秒。手机原先的 USB 连接时亮屏设置已恢复。第四组耗时波动的原因尚未确定。[首次四组](../artifacts/ming-android/8gen3-npu-matrix-three/comparison.json) · [首次实验的连接记录](../artifacts/ming-android/8gen3-npu-matrix-three/phone-session.json) · [重连后四组](../artifacts/ming-android/8gen3-npu-matrix-three/recheck/comparison.json) · [复测设备状态](../artifacts/ming-android/8gen3-npu-matrix-three/recheck/phone-session.json)

每轮中，双句方案的语言模型和 flow 各调用 195 次（175 次双句、20 次单句），三句方案各调用 151 次（83 次三句、53 次双句、15 次单句）。从全部正式轮次按调用数加权，双句方案的一次双句 flow 平均 62.14 ms，三句方案的一次三句 flow 平均 101.41 ms。语言模型的对应数值是 23.01 ms 和 24.69 ms。单次 flow 的额外计算抵消了大部分合批收益。

64 对逐句录音中，51 对逐样本相同，10 对最多相差 1–2 个 16 位 PCM 量化刻度。另 3 对涉及复测的第 1、5、8 句。八组的每句时长都相同。桌面「Ming 10步试听 · 双句与三句矩阵合批」保存首次第一组的完整对话和逐句 WAV，另附这 3 对波形差异较大的录音。第 1 句从 2.41 秒起出现差异，第 5、8 句从约 1.77、1.78 秒起出现差异。同一批量大小在不同轮次也会生成不同波形。[首次逐句差异](../artifacts/ming-android/8gen3-npu-matrix-three/audio-differences.json) · [复测逐句差异](../artifacts/ming-android/8gen3-npu-matrix-three/recheck/audio-differences.json) · [双句完整 WAV](../artifacts/ming-android/8gen3-npu-matrix-three/pair-1-A/dialogue.wav) · [三句完整 WAV](../artifacts/ming-android/8gen3-npu-matrix-three/pair-1-B/dialogue.wav)

这 3 对补充录音的 CAM++ 说话人向量余弦相似度为 0.988–0.998。离线 Whisper small 转写中，第 1 和第 8 句的两版用字一致，第 5 句原词「发之前」的两版转写分别为「发支前」和「发支钱」。清晰度、音色和情绪可在桌面试听页按句对照。[补充录音转写](../artifacts/ming-android/8gen3-npu-matrix-three/spot-transcripts.json) · [补充录音说话人向量](../artifacts/ming-android/8gen3-npu-matrix-three/spot-speakers.json)

<a id="pagestage-ming-init"></a>

## 2026-11-20 · PageStage 主 App 的 Ming 首次初始化

小米 14 Ultra（24031PN0DC，SM8650）在亮屏前台完成整轮测试。LiteRT 2.2.0 和 QAIRT 2.47.0 使用新建的空缓存，依次准备与主 App 相同的七张 FP16 图。逐项计时从创建图到释放编译句柄，包含 NPU 编译和缓存写入。七项开始与结束时 Android 进程重要性均为前台的 100。

| 完成项 | 模块 | 前台校准 | 校准占比 | 主 App 复测 | 累计显示 |
| --- | --- | ---: | ---: | ---: | ---: |
| 1/7 | 文本预填充 | 34.35 秒 | 6.88% | 40.61 秒 | 7% |
| 2/7 | 单句语言模型 | 20.17 秒 | 4.04% | 24.98 秒 | 11% |
| 3/7 | 单句语音生成（10 步） | 140.74 秒 | 28.19% | 175.38 秒 | 39% |
| 4/7 | 声学特征聚合 | 4.41 秒 | 0.88% | 5.56 秒 | 40% |
| 5/7 | 音频解码 | 29.94 秒 | 6.00% | 35.68 秒 | 46% |
| 6/7 | 双句语音生成（10 步） | 244.42 秒 | 48.95% | 296.67 秒 | 95% |
| 7/7 | 双句语言模型 | 25.27 秒 | 5.06% | 30.15 秒 | 100% |
| **合计** | | **499.29 秒** | **100%** | **609.03 秒** | |

设置页读取七个未取整的毫秒权重，按已完成项的累计占比四舍五入。点击后先从随安装交付的资源包复制并校验 3.76 GB 模型，期间显示 0/7。每完成一个模块，应用把结果存入自己的缓存，再通知界面更新。重启时检查同一模型版本、系统版本和缓存文件是否完整。

[真机原始计时](../artifacts/ming-android/8gen3-ming-init-seven/timings.json) · [逐图 NPU 日志](../artifacts/ming-android/8gen3-ming-init-seven/placement.log) · [App 进度权重](../../packages/app/android/app/src/main/assets/ming/initialization.json)

主 App 在同一手机上原地安装，版本为 0.1.0+16。首次打开设置显示 0% · 0/7，点「初始化」后现场观察到全部七个节点。含模型文件准备，从点击到显示 100% · 7/7 用时 619.83 秒。各节点显示值与这一轮七项编译的实际累计占比最大相差 0.57 个百分点。重新启动进程后直接显示 100% · 7/7。

使用设置自带的《两张门票》前两句，双句 flow 和语言模型分别实际执行 49 次矩阵合批，两个参考音色各自进入对应输入行。两句有效 PCM 均与此前四轮双句基线逐样本相同，保存的 44.1 kHz 单声道 WAV 含句间停顿，共 8.73 秒。音色由独立目录登记，角色共享七张图的缓存。

[主 App 复测计时](../artifacts/ming-android/8gen3-ming-init-seven/main-init.json) · [屏幕节点记录](../artifacts/ming-android/8gen3-ming-init-seven/app-progress.json) · [双句音频核对](../artifacts/ming-android/8gen3-ming-init-seven/app-preview-check.json)

最后更新音色目录和设置说明后，设备继续显示 100% · 7/7，沿用原有 NPU 缓存。本轮仅静默复查设置页。[最终设置页](../artifacts/ming-android/8gen3-ming-init-seven/final-ready.png)
