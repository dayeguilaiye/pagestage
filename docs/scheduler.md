# 持久化生成任务

`Scheduler` 是 core 的生成任务入口。调用方提供 `LocalStore`、建档和导演的 LLM 适配器，以及 TTS 适配器。真实适配器沿用服务商会话提供的限流队列与网络恢复，调度器负责持久化、排序、进度和暂停。

```dart
final scheduler = await Scheduler.open(
  store: store,
  profileLlm: profileLlm,
  directorLlm: directorLlm,
  ttsAdapters: adapters,
);
await scheduler.enqueue(book.id, TaskKind.profile, through: 5);
await scheduler.idle;
await Casting(store).recommend(book, providers: {'minimax'});
await scheduler.enqueue(book.id, TaskKind.synthesize, first: 1, through: 1);
```

每个任务对应一本书的一章，类型是建档、导演或合成。建档从第 1 章推进到指定范围；导演和合成要求章节已经建档，合成自动排入缺少的导演任务。排队时用户任务先于提前量任务，同一优先级按入队顺序执行。正在进行的章节或台词先保存结果。

`tasks` 返回当前快照，`events` 发布任务状态和刚完成的 `SynthesizedUtterance`。音频记录在每条台词完成后保存到 `AudioRepository`，此时 `ChapterAudio.complete` 为 `false`，播放器可以使用已有台词。整章完成后标记为 `true`。完成记录同时校验剧本、音色绑定、发音词典和文件，重新执行时复用有效的合成缓存。

任务状态为 `queued`、`running`、`paused`、`completed`。`close()` 等当前章节或台词保存后停止；重新打开同一数据库会恢复用户任务，将中断的运行状态恢复为排队。已经建档、导演或合成的成果会跳过。部分合成通过逐条缓存续跑。

服务商错误会留下 `provider` 和 `reason`，同一服务商相关的后续请求等待恢复。调用 `resume(provider: 'minimax')` 或 `resume()` 继续。持久化错误只保存固定类别，不保存原始响应、key 或正文。调用方可以在恢复之前更新注入适配器所用的配置。

## 收听提前量

```dart
await scheduler.reportListening(book.id, chapter: 1,
    lookahead: Lookahead(directing: 2, synthesis: 1));
await scheduler.reportListening(null); // 收听停止
```

默认导演提前 2 章、合成提前 1 章，范围限定在已有的建档范围和书的结尾内。合成提前量必须小于等于导演提前量，两个值都允许为 0。阅读页只读取书库；播放器在收听时报告位置，停止时传入 `null`。重新打开调度器后，提前量任务等待新的收听位置。

## 验证

`dart test packages/core/test/scheduler_test.dart` 使用假 LLM、假 TTS 和假时钟，验证恢复、优先级、逐条输出、缓存、提前量以及服务商暂停。`library_lifecycle_test.dart` 覆盖这些成果对应的章节状态和书籍删除。
