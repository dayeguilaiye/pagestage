// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get narrator => '旁白';

  @override
  String get narratorSeal => '旁';

  @override
  String get extra => '群演';

  @override
  String get audition => '试听';

  @override
  String get stopAudition => '停止试听';

  @override
  String get auditioning => '试听中';

  @override
  String get more => '更多';

  @override
  String get player => '播放器';

  @override
  String get aiVoice => 'AI 配音';

  @override
  String get nextLine => '下一句';

  @override
  String get back => '返回';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get chapterQueued => '排队中';

  @override
  String get chapterWorking => '生成中';

  @override
  String get chapterPaused => '已暂停';

  @override
  String chapterDirecting(String elapsed) {
    return '分配台词中 $elapsed';
  }

  @override
  String chapterVoicing(int voiced, int total) {
    return '配音中 $voiced/$total';
  }

  @override
  String chapterPausedBecause(String reason) {
    return '已暂停：$reason';
  }

  @override
  String get prepareChapters => '提前准备章节';

  @override
  String get prepareFrom => '从';

  @override
  String get prepareThrough => '到';

  @override
  String get prepareNote =>
      '先为这些章节准备好配音，听的时候直接播放，也能离线听。正文会发给你设置的大模型和配音服务；已经准备好的章节会跳过。';

  @override
  String prepareRange(int first, int through) {
    return '准备第 $first–$through 章';
  }

  @override
  String prepareOne(int chapter) {
    return '准备第 $chapter 章';
  }

  @override
  String get prepareFailed => '没能开始准备，请稍后再试。';

  @override
  String get shelfTitle => '书架';

  @override
  String get importBook => '导入';

  @override
  String get importing => '正在导入';

  @override
  String shelfAll(int count) {
    return '全部 · $count 本';
  }

  @override
  String get shelfEmptyTitle => '书架还是空的';

  @override
  String get shelfEmptyBody =>
      '导入手机里的 TXT 或无 DRM 的 EPUB 小说，或者别人分享的剧本包、有声包，就可以在这里读和听。';

  @override
  String get shelfEmptyAction => '导入一本书';

  @override
  String get shelfLoadFailed => '没能读取书架';

  @override
  String chapterCount(int count) {
    return '共 $count 章';
  }

  @override
  String bookImported(String title) {
    return '已导入《$title》';
  }

  @override
  String importUnsupportedTitle(String file) {
    return '不支持「$file」的格式';
  }

  @override
  String get importUnsupportedBody =>
      '目前可以导入 TXT、没有 DRM 的 EPUB，以及剧本包和有声包（.pagestage）。书架没有变化。';

  @override
  String importDrmTitle(String file) {
    return '「$file」有 DRM 版权保护';
  }

  @override
  String get importDrmBody =>
      '受 DRM 保护的 EPUB 无法读取正文。请导入没有 DRM 的 EPUB 或 TXT 文件，书架没有变化。';

  @override
  String bookUpdated(String title, int added, int changed) {
    return '《$title》已更新：新增 $added 章，另有 $changed 章内容更新';
  }

  @override
  String bookUnchanged(String title) {
    return '《$title》已经是最新的，没有变化';
  }

  @override
  String importEmptyTitle(String file) {
    return '「$file」里没有文字';
  }

  @override
  String get importEmptyBody => '书架没有变化。换一个有正文的 TXT 文件再试。';

  @override
  String importUnreadableTitle(String file) {
    return '读不出「$file」的文字';
  }

  @override
  String get importUnreadableBody => '文件可能损坏了；TXT 文件需要是 UTF-8 或 GBK 编码。书架没有变化。';

  @override
  String get importAnother => '换一个文件';

  @override
  String get deleteBook => '删除';

  @override
  String deleteBookTitle(String title) {
    return '删除《$title》？';
  }

  @override
  String get deleteBookBody => '这本书的章节、角色、台词和音频都会删掉，不能恢复。';

  @override
  String get deleteBookConfirm => '删除这本书';

  @override
  String get contents => '目录';

  @override
  String get contentsLoadFailed => '没能读取目录';

  @override
  String get chapterLoadFailed => '没能打开这一章';

  @override
  String get readingSettings => '阅读设置';

  @override
  String get textSize => '字号';

  @override
  String get lineSpacing => '行距';

  @override
  String get lineSpacingCompact => '紧凑';

  @override
  String get lineSpacingComfortable => '舒适';

  @override
  String get lineSpacingLoose => '宽松';

  @override
  String get nightMode => '夜间模式';

  @override
  String get nightModeSystem => '跟随系统';

  @override
  String get nightModeOff => '关';

  @override
  String get nightModeOn => '开';

  @override
  String get playFromHere => '从这里播放';

  @override
  String get previousLine => '上一句';

  @override
  String get playbackFixtureMissing => '请先准备本地播放素材，再运行播放原型。';

  @override
  String get systemVoice => '系统声音';

  @override
  String get systemVoiceNote => '这本书用手机自带的声音朗读。';

  @override
  String chapterNumber(int number) {
    return '第 $number 章';
  }

  @override
  String chapterOfCount(String title, int number, int count) {
    return '$title · $number / $count';
  }

  @override
  String lineOfCount(int number, int count) {
    return '第 $number / $count 句';
  }

  @override
  String get nowListening => '正在听';

  @override
  String get closePlayer => '收起播放器';

  @override
  String get openPlayer => '打开播放器';

  @override
  String get nothingPlayingTitle => '现在没有在听的书';

  @override
  String get nothingPlayingBody => '在书架上选一本书，点「开始听」。';

  @override
  String get backToShelf => '回到书架';

  @override
  String get chapterProgress => '本章进度';

  @override
  String get previousChapter => '上一章';

  @override
  String get nextChapter => '下一章';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get speedShort => '语速';

  @override
  String get sleepTimer => '睡眠定时';

  @override
  String get sleepTimerShort => '定时';

  @override
  String get sleepEndOfChapterShort => '本章结束';

  @override
  String get sleepOff => '不定时';

  @override
  String sleepMinutes(int minutes) {
    return '$minutes 分钟后';
  }

  @override
  String get sleepEndOfChapter => '听完本章';

  @override
  String sleepStopsIn(String time) {
    return '$time 后停止播放';
  }

  @override
  String get sleepStopsAtChapterEnd => '本章结束时停止播放';

  @override
  String get readAlong => '跟读';

  @override
  String get listenToChapter => '听这一章';

  @override
  String get backToSpokenLine => '回到朗读处';

  @override
  String get startListening => '开始听';

  @override
  String resumeListening(int chapter) {
    return '继续听 · 第 $chapter 章';
  }

  @override
  String listenedTo(int chapter) {
    return '听到第 $chapter 章';
  }

  @override
  String get errorNoSystemVoice => '手机上没有可用的朗读声音。请在系统设置里下载一个中文或英文语音包。';

  @override
  String get endOfBook => '全书听完了';

  @override
  String get errorChapterUnavailable => '没能打开这一章，试试下一章。';

  @override
  String get errorAudioFailed => '这一段音频播放不了，试试下一句。';

  @override
  String get errorBookMissing => '这本书已经不在书架上了。';

  @override
  String get errorPlaybackStopped => '播放停下来了，再点一次播放试试。';

  @override
  String get providerUnknown => '服务商';

  @override
  String get providerLlm => '大模型';

  @override
  String get providerBailian => '阿里云百炼';

  @override
  String get cast => '角色与声音';

  @override
  String get castLoadFailed => '没能读取角色';

  @override
  String castMembers(int count) {
    return '角色 · $count 位';
  }

  @override
  String get castEmpty => '还没有找到角色。开启 AI 配音后，听到哪里就分析到哪里，角色会陆续出现在这里。';

  @override
  String get castEmptyWorking => '正在分析角色，找到的会陆续出现在这里。';

  @override
  String get castProvisional => '暂定';

  @override
  String get voiceNotAssigned => '还没有分配声音';

  @override
  String get auditionFailed => '没能播放试听';

  @override
  String get profileGender => '性别';

  @override
  String get profileAge => '年龄';

  @override
  String get profilePersonality => '性格';

  @override
  String get profileSpeakingStyle => '说话方式';

  @override
  String get profileVoice => '声音';

  @override
  String get profileEmpty => '还没有档案信息。';

  @override
  String get profiling => '分析角色';

  @override
  String get statusQueued => '排队中';

  @override
  String get statusRunning => '分析中';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusComplete => '已完成';

  @override
  String profilingQueuedTo(int chapter) {
    return '排队中，将分析到第 $chapter 章';
  }

  @override
  String profilingRunningTo(int chapter) {
    return '正在分析到第 $chapter 章';
  }

  @override
  String get profilingPausedTitle => '角色分析暂停了';

  @override
  String profilingPausedBody(String provider, String reason) {
    return '$provider：$reason';
  }

  @override
  String resumeProfilingTo(int chapter) {
    return '继续分析到第 $chapter 章';
  }

  @override
  String profilingSkipped(String chapters) {
    return '已跳过第 $chapters 章：服务商没能处理这些内容';
  }

  @override
  String get chapterListSeparator => '、';

  @override
  String get profilingActionFailed => '没能开始分析，请稍后再试。';

  @override
  String get profiledWholeBook => '全书的角色都分析好了。';

  @override
  String get profileThrough => '分析到';

  @override
  String get startProfiling => '开始分析';

  @override
  String get extendProfiling => '继续往后分析';

  @override
  String get profilingNote => '会把所选章节的正文发给你设置的大模型，用来找出角色、为他们挑选声音。';

  @override
  String get reasonMissingKey => '还没有填写密钥';

  @override
  String get reasonUnauthorized => '密钥无效或没有权限';

  @override
  String get reasonRateLimited => '请求太频繁';

  @override
  String get reasonQuotaExceeded => '账户额度用完了，充值后点「继续配音」';

  @override
  String get reasonNetwork => '网络连不上';

  @override
  String get reasonConsentDeclined => '你没有同意发送正文';

  @override
  String get reasonInvalidResponse => '模型的回复格式不对，可以稍后继续或换个模型';

  @override
  String get reasonRequestRejected => '服务商拒绝了请求，请检查接口地址和模型名称';

  @override
  String get reasonSchemaUnsupported =>
      '这个接口不支持结构化输出（JSON Schema），请换一个支持的模型或服务商';

  @override
  String get reasonContentRejected => '服务商拒绝处理这一章的内容';

  @override
  String get reasonTruncated => '这一章的回复超出了模型的输出长度上限';

  @override
  String get reasonInterrupted => '应用关闭时中断了';

  @override
  String get reasonLocalSynthesisFailed => '本机引擎未能合成这段配音';

  @override
  String get reasonUnknown => '服务暂时不可用';

  @override
  String consentTitle(String title) {
    return '把《$title》的内容发出去？';
  }

  @override
  String get consentChapterTextAndCast => '为了分析角色、分配台词和配音，你听到的章节正文和书里的角色会发给它。';

  @override
  String get consentVoiceSample => '生成试听需要一段示例文本和角色的声音描述。';

  @override
  String get consentBookContent => '这一步需要把书里的内容发给服务商。';

  @override
  String get consentProvider => '服务商';

  @override
  String get consentEndpoint => '发送到';

  @override
  String get consentContentLabel => '内容';

  @override
  String get consentChapterTextAndCastName => '章节正文与角色';

  @override
  String get consentVoiceSampleName => '声音样本文本';

  @override
  String get consentBookContentName => '书的内容';

  @override
  String get consentCancelNote => '取消则什么都不会发送。';

  @override
  String get consentAccept => '同意并发送';

  @override
  String get useSystemVoice => '用系统声音朗读';

  @override
  String get waitingForSynthesis => '正在准备 AI 配音，好了就开始';

  @override
  String get generationPausedTitle => 'AI 配音暂停了';

  @override
  String get generationResumeFailed => '没能继续生成，请稍后再试';

  @override
  String generationPausedLine(String chapter, String provider, String reason) {
    return '$chapter · $provider：$reason';
  }

  @override
  String get resumeGeneration => '继续配音';

  @override
  String get reasonVoiceUnavailable => '分配的声音已不可用';

  @override
  String get errorAudioChanged => '音频已更新（清理过或换了声音），点播放重新准备。';

  @override
  String get changeVoice => '换音色';

  @override
  String get designVoice => '设计音色';

  @override
  String changeVoiceTitle(String name) {
    return '给「$name」换声音';
  }

  @override
  String currentVoice(String voice) {
    return '现在用的是「$voice」';
  }

  @override
  String get presetVoices => '预设音色';

  @override
  String get voiceDesign => '音色设计';

  @override
  String get hearBeforeChoosing => '先试听，听过之后才能选用。';

  @override
  String get chooseVoice => '选用';

  @override
  String get voiceInUse => '使用中';

  @override
  String get chooseVoiceFailed => '没能换上这个声音，请再试一次';

  @override
  String get presetsLoadFailed => '没能读取预设音色';

  @override
  String get presetsEmpty => '开启的配音服务里没有适合这本书语言的声音。';

  @override
  String get designProvider => '设计服务商';

  @override
  String get voiceDescriptionLabel => '声音描述';

  @override
  String get voiceDescriptionHint => '例如：五十岁上下的男声，低沉沙哑，说话慢条斯理';

  @override
  String get designCandidates => '生成 3 个候选';

  @override
  String get designCandidatesAgain => '重新生成候选';

  @override
  String get designing => '正在设计声音，需要一点时间';

  @override
  String get designFailed => '没能设计出声音';

  @override
  String get designFailedBody => '描述和服务商都还在，可以直接重试或改一改描述。';

  @override
  String get candidates => '候选声音';

  @override
  String voiceChanged(String name) {
    return '已为「$name」换上新声音';
  }

  @override
  String voiceRebuiltTitle(String name) {
    return '$name的声音重建了';
  }

  @override
  String voiceRebuiltBody(String provider) {
    return '$provider的声音绑定已重新建立，听起来可能和之前不同，建议重新试听。';
  }

  @override
  String get listenAgain => '重新试听';

  @override
  String get settings => '设置';

  @override
  String get llm => '大模型';

  @override
  String get voiceRole => '配音和音色设计';

  @override
  String get voiceRoleNoDesign => '配音';

  @override
  String get providerReady => '已配置';

  @override
  String get providerNotSet => '未配置';

  @override
  String get llmNoModel => '缺少模型';

  @override
  String get llmNoKey => '缺少密钥';

  @override
  String get setupTitle => '先配置大模型';

  @override
  String get setupBody => '分析角色和分配台词要用你自己的大模型账户。';

  @override
  String get setupAction => '配置大模型';

  @override
  String get generationSectionNote => '只在收听时进行，静默阅读不会触发。';

  @override
  String get autoGenerate => '新书默认用 AI 配音';

  @override
  String get autoGenerateNote => '每本书也可以在它的配音设置里单独开关。';

  @override
  String get aheadUnit => '章';

  @override
  String get generationSettingsFailed => '没能保存生成设置，请再试一次';

  @override
  String get castingSection => '角色声音';

  @override
  String get exclusiveVoices => '独享声音的角色数';

  @override
  String exclusiveVoicesValue(int count) {
    return '$count 个';
  }

  @override
  String get exclusiveVoicesNote => '台词最多的几个角色各有自己的声音，其余角色共用几种群演声音。';

  @override
  String get exclusiveVoicesRecastNote => '修改后会给已分析过的书重新分配声音；你换过或设计的声音不变。';

  @override
  String get fewerVoices => '减少专属音色';

  @override
  String get moreVoices => '增加专属音色';

  @override
  String get recast => '重新分配声音';

  @override
  String recastDone(int count) {
    return '已按 $count 个独享声音重新分配';
  }

  @override
  String get recastFailed => '没能重新分配声音，请再试一次';

  @override
  String get appearanceSection => '外观';

  @override
  String get storageSection => '存储与用量';

  @override
  String get storage => '存储空间';

  @override
  String get storageTotal => '共占用';

  @override
  String storageAudioPart(String size) {
    return '音频 $size';
  }

  @override
  String storageOtherPart(String size) {
    return '正文、剧本等 $size';
  }

  @override
  String get storageBooks => '每本书';

  @override
  String storageBookLine(String total, String audio) {
    return '共 $total · 音频 $audio';
  }

  @override
  String storageBookNoAudio(String total) {
    return '共 $total · 没有音频';
  }

  @override
  String get storageLoadFailed => '没能读取存储空间';

  @override
  String get storageEmpty => '还没有占用空间的书';

  @override
  String get storageCountNote => '按书统计正文、台词、角色和音频文件；数据库的索引和日志由所有书共用，不计入。';

  @override
  String get clearAudio => '清理音频';

  @override
  String get clearAudioNote => '清理只删除生成的音频、试听和缓存；正文、台词和角色都会保留，之后播放时再按需重新配音。';

  @override
  String clearAudioTitle(String title) {
    return '清理《$title》的音频？';
  }

  @override
  String clearAudioBody(String size) {
    return '将释放 $size。正文、台词和角色会保留；再听这本书时，会按需重新配音。';
  }

  @override
  String get clearAudioConfirm => '清理音频';

  @override
  String get clearAudioFailed => '没能清理音频，请再试一次';

  @override
  String audioCleared(String title) {
    return '已清理《$title》的音频';
  }

  @override
  String get feedbackSection => '反馈';

  @override
  String get exportDiagnostics => '导出诊断报告';

  @override
  String get exportDiagnosticsNote => '不含密钥和书的正文';

  @override
  String get exportingDiagnostics => '正在准备报告…';

  @override
  String get reportProblem => '反馈问题';

  @override
  String get reportProblemNote => '在 GitHub 上新建一个问题';

  @override
  String get openingBrowser => '正在打开浏览器…';

  @override
  String get exportDiagnosticsFailed => '没能导出诊断报告';

  @override
  String get exportDiagnosticsFailedBody => '报告没有生成或没有打开分享，请再试一次。';

  @override
  String get reportProblemFailed => '没能打开反馈页面';

  @override
  String get reportProblemFailedBody => '浏览器没有打开，请检查网络或默认浏览器后再试。';

  @override
  String get feedbackNote => '报告包含应用版本、设备信息和近期错误，不会自动上传，只在你从分享里发送时离开手机。';

  @override
  String get aboutSection => '关于';

  @override
  String get licenses => '开源许可';

  @override
  String get llmPageNote => '它负责找出书里的角色、决定每句台词由谁来念、用什么语气。';

  @override
  String get connectionSection => '连接';

  @override
  String get baseUrl => '接口地址';

  @override
  String get baseUrlInvalid => '请输入以 https:// 或 http:// 开头的地址';

  @override
  String get protocol => '接口协议';

  @override
  String get protocolChatCompletions => 'Chat Completions';

  @override
  String get protocolResponses => 'Responses';

  @override
  String get apiKey => '密钥';

  @override
  String get llmConnectionNote =>
      '兼容 OpenAI 接口的服务都可以使用，模型需要支持结构化输出（JSON Schema）。';

  @override
  String get modelsSection => '模型';

  @override
  String get profileModel => '分析模型';

  @override
  String get directorModel => '台词模型';

  @override
  String get modelHint => '模型名称';

  @override
  String get sameAsProfileModel => '与分析模型相同';

  @override
  String get modelsNote => '分析模型找出人物、挑选声音；台词模型逐句分配台词和语气，留空则与分析模型相同。';

  @override
  String get minimaxPageNote => '为角色配音，也可以按描述设计新音色。';

  @override
  String get minimaxKeyNote =>
      '国内版密钥来自 minimaxi.com，国际版来自 minimax.io，两边的密钥不能混用。';

  @override
  String get bailianPageNote => '为角色配音。北京地域还可以按描述设计新音色。';

  @override
  String get region => '地域';

  @override
  String get regionBeijing => '北京';

  @override
  String get regionSingapore => '新加坡';

  @override
  String get bailianRegionNote => '北京和新加坡的密钥不通用，请填写所选地域的密钥。';

  @override
  String get keyHint => '粘贴或输入密钥';

  @override
  String get newKeyHint => '粘贴或输入新密钥';

  @override
  String get keySaved => '已保存';

  @override
  String get pasteKey => '粘贴';

  @override
  String get showKey => '显示';

  @override
  String get hideKey => '隐藏';

  @override
  String get replaceKey => '更换';

  @override
  String get deleteKey => '删除密钥';

  @override
  String get deleteKeyTitle => '删除这个密钥？';

  @override
  String get deleteLlmKeyBody => '删除后，分析角色和分配台词会暂停，直到重新填写密钥；已配好的章节照常播放。';

  @override
  String get deleteVoiceKeyBody => '删除后，用这家服务商音色的角色无法生成配音，直到重新填写密钥或换音色。';

  @override
  String get keyDeleted => '密钥已删除';

  @override
  String get keyDeleteFailed => '没能删除密钥，请再试一次';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get saveFailed => '没能保存，请再试一次';

  @override
  String get saveFailedBody => '设置没有改变。检查填写的内容后再试一次。';

  @override
  String get discardTitle => '放弃未保存的修改？';

  @override
  String get discardConfirm => '放弃修改';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get llmSection => '分析角色与台词';

  @override
  String get voiceSection => '配音';

  @override
  String get voiceSectionNote => '生成配音只用开启的引擎。密钥加密存在本机，只发给对应的服务商。';

  @override
  String get edgeRole => '免费，无需密钥';

  @override
  String get voiceNeedsKey => '填写密钥后才能开启';

  @override
  String get noVoiceTitle => '还没有开启配音服务商';

  @override
  String get noVoiceBody => '至少开启一家才能生成配音。Microsoft Edge 免费，无需密钥。';

  @override
  String get turnOnEdge => '开启 Microsoft Edge';

  @override
  String get reasonProviderDisabled => '这家服务已在设置里关闭';

  @override
  String get reasonNoVoiceProvider => '没有开启支持本书语言的配音服务';

  @override
  String offProviderTitle(String provider) {
    return '$provider已关闭';
  }

  @override
  String offProviderNoKeyTitle(String provider) {
    return '$provider还没有密钥';
  }

  @override
  String offProviderBody(String provider) {
    return '配音要用到$provider的音色。打开它，或为用到它的角色换上已开启服务商的音色。';
  }

  @override
  String offProviderSpeakers(String names, String provider) {
    return '$names用的是$provider的音色。打开它，或为这些角色换上已开启服务商的音色。';
  }

  @override
  String speakersAndMore(String names, int total, int more) {
    return '$names等 $total 位';
  }

  @override
  String turnOnProvider(String provider) {
    return '打开$provider';
  }

  @override
  String addProviderKey(String provider) {
    return '填写$provider的密钥';
  }

  @override
  String get rematchVoices => '重新匹配音色';

  @override
  String get rematchFailed => '没能重新匹配音色，请再试一次';

  @override
  String get languageEngineCloud => '云端大模型';

  @override
  String get languageEngineDevice => '本机大模型';

  @override
  String get voiceEngineDevice => '本机语音';

  @override
  String get engineInUse => '使用中';

  @override
  String get useEngine => '使用';

  @override
  String get engineComingSoon => '即将支持';

  @override
  String get engineNotInstalled => '未安装模型';

  @override
  String get engineComingSoonNote => '在手机上直接运行，正文不离开设备，也不需要密钥。这个引擎还在准备中。';

  @override
  String get engineNotInstalledNote => '这个引擎在手机上直接运行，需要先安装它的模型。';

  @override
  String get llmSectionNote => '没有大模型也能听：导入别人分享的剧本包或有声包。';

  @override
  String get voiceSectionCloud => '配音 · 云端';

  @override
  String get voiceSectionDevice => '配音 · 本机';

  @override
  String get voiceSectionDeviceNote => '本机引擎在手机上配音，正文不离开设备。';

  @override
  String get traitEmotion => '情绪';

  @override
  String get traitInstruction => '表演指令';

  @override
  String get traitVocalCues => '语气词';

  @override
  String get traitPacing => '语速音高';

  @override
  String get traitVoiceDesign => '音色设计';

  @override
  String engineVoices(int count) {
    return '$count 个音色';
  }

  @override
  String get engineAbilities => '演出能力';

  @override
  String get engineAbilitiesNote => '台词只写一份。每个配音服务演出它做得到的部分，做不到的换成接近的效果或省略。';

  @override
  String get engineAbilitiesPlain => '只分角色朗读';

  @override
  String get enginePageNote => '为角色配音。';

  @override
  String get edgePageNote => '微软 Edge 浏览器的朗读服务。免费，无需密钥；不带情绪，只调整语速和音高。';

  @override
  String get reasonEngineNotInstalled => '这个本机引擎还没有安装模型';

  @override
  String get reasonEngineUnavailable => '这个引擎暂时还不能用，请在设置里换一个';

  @override
  String packageImported(String title, int scripts) {
    return '已导入《$title》：$scripts 章剧本';
  }

  @override
  String packageImportedAudio(String title, int scripts, int audio) {
    return '已导入《$title》：$scripts 章剧本，$audio 章可以直接听';
  }

  @override
  String importPackageInvalidTitle(String file) {
    return '「$file」不是有效的剧本包或有声包';
  }

  @override
  String get importPackageInvalidBody =>
      '文件可能不完整，或者是用更新版本的 pagestage 导出的。书架没有变化。';

  @override
  String replaceBookTitle(String title) {
    return '替换《$title》？';
  }

  @override
  String get replaceBookBody => '书架上已经有这本书。导入会替换它的角色、台词和音频，收听进度保留。';

  @override
  String get replaceBookConfirm => '替换';

  @override
  String get shareBook => '分享';

  @override
  String shareBookTitle(String title) {
    return '分享《$title》';
  }

  @override
  String get shareScript => '剧本包';

  @override
  String shareScriptNote(int count) {
    return '原文、角色和 $count 章台词。对方用自己的声音配音，不用再跑大模型。';
  }

  @override
  String get shareAudio => '有声包';

  @override
  String shareAudioNote(int count) {
    return '剧本包，再加上已配音的 $count 章音频。对方导入后直接听。';
  }

  @override
  String get shareAudioNone => '还没有配好音的章节。';

  @override
  String get shareNothing => '还没有可以分享的内容。先听几章，等它们配好音。';

  @override
  String get sharePreparing => '正在打包…';

  @override
  String get shareFailed => '没能打包，请再试一次';

  @override
  String get shareNote => '包里有全书正文，只通过系统分享发出。请只分享你有权分享的书。';

  @override
  String get shareLoadFailed => '没能读取这本书的剧本和音频';

  @override
  String get expressiveness => '情绪';

  @override
  String get expressivenessPlain => '平淡';

  @override
  String get expressivenessNatural => '自然';

  @override
  String get expressivenessDramatic => '夸张';

  @override
  String get expressivenessPlainNote => '只分角色朗读，不带情绪和语气词。';

  @override
  String get expressivenessNaturalNote => '按台词里的情绪和语气演。';

  @override
  String get expressivenessDramaticNote => '情绪再强一档。';

  @override
  String changeVoiceOf(String name) {
    return '换「$name」的声音';
  }

  @override
  String reassignLine(String name) {
    return '这句不是「$name」说的';
  }

  @override
  String get reassignTitle => '这句是谁说的？';

  @override
  String get reassignNote => '改了之后，这一章只有这一句重新配音。';

  @override
  String get reassignImportedNote => '这一章的音频是导入的。改了之后，整章会用你开启的声音重新配音。';

  @override
  String reassigned(String name) {
    return '已改为「$name」说的';
  }

  @override
  String get reassignFailed => '没能修改，请再试一次';

  @override
  String get speakersLoadFailed => '没能读取角色';

  @override
  String get mingTitle => 'Ming 离线配音';

  @override
  String get mingPending => '待初始化';

  @override
  String get mingDescription => '内置 32 种普通话音色，覆盖儿童到老年，也有适合旁白的声音。初始化一次即可使用全部音色。';

  @override
  String get mingBeforeInit => '首次使用请初始化，并保持应用在前台。';

  @override
  String get mingReady => '初始化完成，可以配音。';

  @override
  String get mingCopying => '正在复制并校验模型文件…';

  @override
  String mingCompiling(String module) {
    return '正在准备$module…';
  }

  @override
  String get mingPrefill => '文本预填充';

  @override
  String get mingStep => '单句语言模型';

  @override
  String get mingFlow => '单句语音生成';

  @override
  String get mingAgg => '声学特征聚合';

  @override
  String get mingDec => '音频解码';

  @override
  String get mingFlowPair => '双句语音生成';

  @override
  String get mingStepPair => '双句语言模型';

  @override
  String get mingStorageError => '模型文件准备失败。请检查剩余空间后重试。';

  @override
  String get mingInitError => '模块初始化中断，可从已完成的进度继续。';

  @override
  String get mingInitialize => '初始化';

  @override
  String get mingRetry => '继续初始化';

  @override
  String get mingPreview => '试听双人对话';

  @override
  String get mingActionError => '操作未完成，请再试一次。';

  @override
  String get fallbackNote => 'AI 配音没能及时准备好，这一章先用系统声音，下一章自动换回。';

  @override
  String get systemVoiceForNowNote => 'AI 配音暂时用不了，这一章先用系统声音朗读。';

  @override
  String get turnOnAiVoice => '开启 AI 配音';

  @override
  String waitingWithStatus(String status) {
    return '正在准备本章：$status';
  }

  @override
  String get listenWithSystemVoice => '先用系统声音听';

  @override
  String get miniWaiting => '正在准备 AI 配音…';

  @override
  String get listenFromStart => '从头再听';

  @override
  String get errorNoSystemVoiceShort => '手机上没有朗读声音';

  @override
  String get errorChapterUnavailableShort => '这一章打不开';

  @override
  String get errorAudioFailedShort => '这一段播放不了';

  @override
  String get errorBookMissingShort => '这本书已不在书架上';

  @override
  String get errorAudioChangedShort => '音频已更新，点播放继续';

  @override
  String get errorPlaybackStoppedShort => '播放停了，点播放重试';

  @override
  String get chapterProfiling => '分析角色中';

  @override
  String get chapterListening => '正在听';

  @override
  String get chapterVoiced => '已有 AI 配音';

  @override
  String get generationPausedNote => '暂停期间用系统声音朗读，收听不受影响。';

  @override
  String profilingPausedLine(String provider, String reason) {
    return '分析角色 · $provider：$reason';
  }

  @override
  String checkProviderSettings(String provider) {
    return '检查$provider设置';
  }

  @override
  String get resumeAfterFixNote => '改好后会自动继续。';

  @override
  String get retryNow => '立即重试';

  @override
  String get retryingSoon => '稍后会自动重试。';

  @override
  String get reviewAndAgree => '查看并同意';

  @override
  String get chooseVoices => '去换声音';

  @override
  String get useSystemVoiceForBook => '这本书改用系统声音';

  @override
  String get reasonConsentNeeded => '还没同意把正文发给它';

  @override
  String consentSetupTitle(String provider) {
    return '允许把书的正文发给$provider？';
  }

  @override
  String get consentScopeNote => '同意一次，所有书都按这个设置发送；随时可以在 设置 › 隐私 里撤回。';

  @override
  String get consentAgree => '同意';

  @override
  String get listeningSection => '收听';

  @override
  String get aiVoicesEnabled => 'AI 配音';

  @override
  String get aiVoicesEnabledNote => '关闭后所有书都用系统声音，不会再发送任何正文。';

  @override
  String get prepareAheadSetting => '提前准备';

  @override
  String get prepareAheadSettingNote => '听书时先准备好后面几章；设为 0 只准备正在听的一章。';

  @override
  String get fewerAhead => '少准备一章';

  @override
  String get moreAhead => '多准备一章';

  @override
  String get voiceSettings => '配音设置';

  @override
  String get voiceSettingsFailed => '没能读取这本书的配音设置';

  @override
  String get aiVoiceForBook => 'AI 多角色配音';

  @override
  String get aiVoiceForBookNote =>
      '每个角色用不同的声音，听到哪里准备到哪里。正文会发给你在设置里配置的服务商；关闭后用系统声音，已配好的章节照常播放。';

  @override
  String get aiVoicesOffEverywhere => 'AI 配音已在设置里关闭';

  @override
  String get openSettings => '去设置';

  @override
  String get readDialogueTags => '念出「他说」这类提示';

  @override
  String get readDialogueTagsNote => '关闭后角色直接开口，跳过说话提示，更像广播剧。';

  @override
  String get performanceChangeNote =>
      '改动只影响这本书。已配好的章节会在下次收听时按新设置重新配音，会再次调用配音服务；正在播放的这一章先听完。';

  @override
  String get prepareAhead => '提前准备章节…';

  @override
  String get prepareAheadNote => '比如出门前先准备好，离线也能听。';

  @override
  String get stopPreparing => '停止准备';

  @override
  String get stopPreparingNote => '取消排队中的章节；正在听的时候，接下来的一两章仍会准备。';

  @override
  String get castShort => '角色';

  @override
  String get castRowNote => '每个角色是谁、用什么声音';

  @override
  String get sampleVoicedTitle => '示例书已经配好音';

  @override
  String get sampleVoicedBody => '它的设置不能更改。导入你自己的书，就能用自己的服务商配音。';

  @override
  String get voiceStatusSample => '示例 · 已配好音';

  @override
  String get voiceStatusTurnOn => '开启 AI 多角色配音';

  @override
  String voiceStatusReadyThrough(int chapter) {
    return '已准备到第 $chapter 章';
  }

  @override
  String voiceStatusVoicedCount(int count) {
    return '已配好 $count 章';
  }

  @override
  String get voiceStatusAsYouListen => '听到哪里准备到哪里';

  @override
  String get gapLanguageModelTitle => '还差一个大模型账户';

  @override
  String get gapLanguageModelBody => 'AI 配音要先用大模型分析角色、分配台词。设置好之前用系统声音朗读。';

  @override
  String get gapVoiceTitle => '还差一个配音服务';

  @override
  String get gapVoiceBody => '至少开启一家配音服务。Microsoft Edge 免费，不用密钥。';

  @override
  String profileNeededTitle(int chapter) {
    return '从第 $chapter 章用 AI 配音，要先分析前面的角色';
  }

  @override
  String profileNeededBody(int from, int through) {
    return '这会把第 $from–$through 章的正文发给大模型，可能要一段时间；在那之前用系统声音朗读。';
  }

  @override
  String get profileNeededAction => '开始分析';

  @override
  String get jumpToChapter => '跳到…';

  @override
  String get profilingNotStarted => '还没有分析角色';

  @override
  String profilingStatusLine(int chapter, int count) {
    return '已分析到第 $chapter 章 · 共 $count 章';
  }

  @override
  String get profilingAuto => '听到哪里分析到哪里，不用手动操作。';

  @override
  String get profileMore => '提前分析更多章节…';

  @override
  String laterCharacters(int count) {
    return '后面章节登场的 $count 位角色';
  }

  @override
  String get showLaterCharacters => '显示（可能剧透）';

  @override
  String get hideLaterCharacters => '收起';

  @override
  String get profileFirstChapter => '登场';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get ageChild => '儿童';

  @override
  String get ageTeen => '少年';

  @override
  String get ageYoungAdult => '青年';

  @override
  String get ageMiddleAged => '中年';

  @override
  String get ageSenior => '老年';

  @override
  String get startupFailedTitle => 'pagestage 没能打开';

  @override
  String get startupFailedBody =>
      '书和设置都还在。可以再试一次；如果反复出现，请导出诊断报告发给我们，报告里没有书的内容和密钥。';

  @override
  String get keysUnavailableTitle => '读取不到保存的密钥';

  @override
  String get keysUnavailableBody =>
      '系统钥匙串暂时不可用，AI 配音先用不了；书照常可以读，也能用系统声音听。重启手机后再试，或重新填写密钥。';

  @override
  String get regionGlobal => '国际版';

  @override
  String get regionChina => '国内版';

  @override
  String get presetSection => '服务商';

  @override
  String get presetService => '用哪家的大模型';

  @override
  String get presetBailian => '阿里云百炼（通义千问）';

  @override
  String get presetCustom => '自定义';

  @override
  String get presetCustomNote =>
      '兼容 OpenAI 接口、支持结构化输出（JSON Schema）的服务都可以，自己填写地址和模型。';

  @override
  String presetConsoleNote(String console) {
    return '地址、协议和推荐模型已填好，只需在 $console 创建一个 API Key 粘贴到下面。';
  }

  @override
  String get shareBailianKey => '同时用这个密钥开启百炼配音';

  @override
  String get shareBailianKeyNote => '百炼的同一个密钥也能配音（北京地域），不用再填一次。';

  @override
  String get testConnection => '测试连接';

  @override
  String get testConnectionNote => '用一次很小的请求试试能不能用，不会发送书的内容。';

  @override
  String get testConnectionOk => '连接正常，可以使用。';

  @override
  String get testUnauthorized => '密钥不对或没有权限：检查是否复制完整，地域或国内版/国际版是否选对。';

  @override
  String get testSchemaUnsupported =>
      '这个模型不支持结构化输出（JSON Schema）。换一个支持的模型，或选上面的预设。';

  @override
  String get testRequestRejected => '服务商拒绝了请求：检查接口地址和模型名称是否正确。';

  @override
  String get testQuota => '账户余额不足，充值后再试。';

  @override
  String get testMissing => '还缺密钥或模型名称。';

  @override
  String get testRateLimited => '请求太频繁，过一会儿再试。';

  @override
  String get testNetwork => '连不上：检查网络和接口地址。';

  @override
  String get usage => '用量';

  @override
  String get usageRowNote => '每本书用了多少大模型和配音额度';

  @override
  String get usageNote => '数字来自服务商自己的回报，按它们的单位计；具体费用以服务商账单为准。';

  @override
  String get usageEmpty => '还没有用过任何付费服务。';

  @override
  String get usageLoadFailed => '没能读取用量';

  @override
  String get usageEarlier => '早期用量（未按书记录）';

  @override
  String get usageDeletedBook => '已删除的书';

  @override
  String usageTokens(String provider, String count) {
    return '$provider $count tokens';
  }

  @override
  String usageCharacters(String provider, String count) {
    return '$provider $count 字';
  }

  @override
  String get usageNothingBilled => '没有计费用量';

  @override
  String get privacy => '隐私';

  @override
  String get privacyRowNote => '书的正文会发给谁，随时可以撤回';

  @override
  String get privacyIntro =>
      '书只存在这台手机上。开启 AI 配音后，你听到的章节正文和书里的角色会发给你设置的大模型和配音服务，用来分析角色、分配台词和配音；密钥加密保存在本机，只发给对应的服务商。用系统声音朗读时，什么都不会发送。';

  @override
  String get consentsSection => '已同意发送正文的服务';

  @override
  String get consentsNote => '撤回后，需要它的 AI 配音会暂停，用系统声音朗读，直到你再次同意。';

  @override
  String get consentsEmpty => '还没有同意发送给任何服务';

  @override
  String get revokeConsent => '撤回';

  @override
  String get consentRevoked => '已撤回';

  @override
  String get privacyLoadFailed => '没能读取';

  @override
  String get systemVoicePageNote => '没有 AI 配音的书和章节用它朗读。点一下试听并选用。';

  @override
  String get systemVoiceRowNote => '没有 AI 配音时用手机自带的声音朗读，可以选一个更好听的。';

  @override
  String get systemVoiceChinese => '中文';

  @override
  String get systemVoiceEnglish => '英文';

  @override
  String get systemVoiceNone => '没有可用的声音';

  @override
  String get systemVoiceDownloadNote =>
      '在系统设置 › 辅助功能 › 朗读内容 › 声音 里下载「增强」或「高品质」语音，听起来会自然很多。';

  @override
  String get voiceQualityEnhanced => '增强';

  @override
  String get voiceQualityPremium => '高品质';

  @override
  String get continueListening => '继续听';

  @override
  String get sampleBookMeta => '示例 · 已配好音';

  @override
  String get importFailedDismiss => '知道了';

  @override
  String bookUpdatedAdded(String title, int added) {
    return '《$title》新增了 $added 章';
  }

  @override
  String bookUpdatedChanged(String title, int changed) {
    return '《$title》有 $changed 章内容更新';
  }

  @override
  String get chapterShort => '章';

  @override
  String get lineShort => '句';

  @override
  String bookUsageLine(String summary) {
    return '本书已用：$summary。数字来自服务商的回报。';
  }

  @override
  String auditionNeedsProvider(String provider) {
    return '试听要用到$provider，它还没设置好';
  }

  @override
  String get auditionNeedsProviderBody => '这个声音在已配好的章节里还没出现过，需要用它现场生成一段。';
}
