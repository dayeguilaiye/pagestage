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
  String get aiVoice => 'AI 合成';

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
    return '导演中 $elapsed';
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
  String get prepareChapters => '提前生成';

  @override
  String get prepareFrom => '从';

  @override
  String get prepareThrough => '到';

  @override
  String get prepareNote =>
      '先为这些章节导演、配音，听的时候直接播放。正文会发给你设置的大模型和配音服务；已经生成好的章节会跳过。';

  @override
  String prepareRange(int first, int through) {
    return '生成第 $first–$through 章';
  }

  @override
  String prepareOne(int chapter) {
    return '生成第 $chapter 章';
  }

  @override
  String get prepareNeedsProfile => '建档范围内的章节才能生成。先在演员表里建档。';

  @override
  String get prepareFailed => '没能开始生成，请稍后再试。';

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
  String get shelfEmptyBody => '导入手机里的 TXT 或无 DRM 的 EPUB 小说，就可以在这里读和听。';

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
  String get importUnsupportedBody => '目前可以导入 TXT 和没有 DRM 的 EPUB 文件，书架没有变化。';

  @override
  String importDrmTitle(String file) {
    return '「$file」有 DRM 版权保护';
  }

  @override
  String get importDrmBody =>
      '受 DRM 保护的 EPUB 无法读取正文。请导入没有 DRM 的 EPUB 或 TXT 文件，书架没有变化。';

  @override
  String bookUpdated(String title, int added, int changed) {
    return '《$title》已更新：新增 $added 章，$changed 章内容有变化';
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
  String get deleteBookBody => '这本书的章节、演员表、剧本和音频都会删掉，不能恢复。';

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
  String get systemVoice => '系统朗读';

  @override
  String get systemVoiceNote => '这一章还没有生成配音，先用手机自带的声音朗读。';

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
  String get cast => '演员表';

  @override
  String get castLoadFailed => '没能读取演员表';

  @override
  String castMembers(int count) {
    return '演员 · $count 位';
  }

  @override
  String get castEmpty => '还没有演员。建档后，书里的说话人和他们的声音会列在这里。';

  @override
  String get castEmptyWorking => '正在建档，找到的说话人会陆续出现在这里。';

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
  String get profiling => '建档';

  @override
  String get chaptersProfiled => '章已建档';

  @override
  String get statusQueued => '排队中';

  @override
  String get statusRunning => '建档中';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusComplete => '已完成';

  @override
  String profilingQueuedTo(int chapter) {
    return '排队中，将建档到第 $chapter 章';
  }

  @override
  String profilingRunningTo(int chapter) {
    return '正在建档到第 $chapter 章';
  }

  @override
  String get profilingPausedTitle => '建档暂停了';

  @override
  String profilingPausedBody(String provider, String reason) {
    return '$provider：$reason';
  }

  @override
  String resumeProfilingTo(int chapter) {
    return '继续建档到第 $chapter 章';
  }

  @override
  String profilingSkipped(String chapters) {
    return '已跳过第 $chapters 章：服务商没能处理这些内容';
  }

  @override
  String get chapterListSeparator => '、';

  @override
  String get profilingActionFailed => '没能开始建档，请稍后再试。';

  @override
  String get profiledWholeBook => '全书都已建档。';

  @override
  String get profileThrough => '建档到';

  @override
  String get startProfiling => '开始建档';

  @override
  String get extendProfiling => '继续往后建档';

  @override
  String get profilingNote =>
      '建档会把所选章节的正文发给你设置的大模型，用来找出说话人、为他们挑选声音。发送前会先征得你的同意。';

  @override
  String get reasonMissingKey => '还没有填写密钥，请到设置里补上';

  @override
  String get reasonUnauthorized => '密钥无效或没有权限，请到设置里检查';

  @override
  String get reasonRateLimited => '请求太频繁，过一会儿再继续';

  @override
  String get reasonQuotaExceeded => '账户额度用完了';

  @override
  String get reasonNetwork => '网络连接中断';

  @override
  String get reasonConsentDeclined => '你取消了发送';

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
  String get reasonUnknown => '服务暂时不可用';

  @override
  String get settings => '设置';

  @override
  String get settingsSubtitle => '使用你自己的服务商账户';

  @override
  String get llmSection => '大模型';

  @override
  String get llmSectionNote => '用来建档和导演：找出说话人，为每句台词分配声音和语气。';

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
  String get profileModel => '建档模型';

  @override
  String get profileModelHelp => '用来分析人物和挑选声音。';

  @override
  String get directorModel => '导演模型';

  @override
  String get directorModelHelp => '用来逐句导演。留空则使用建档模型。';

  @override
  String get sameAsProfileModel => '与建档模型相同';

  @override
  String get llmKey => '大模型密钥';

  @override
  String get minimaxSectionNote => '生成角色的配音。';

  @override
  String get edgeSectionNote =>
      '在线音色，无需密钥，可在演员表中选择。未配置付费语音服务时用于自动选角。支持普通文本朗读；情绪和多音字指令不生效。';

  @override
  String get minimaxKey => 'MiniMax 密钥';

  @override
  String get bailianSection => '阿里云百炼';

  @override
  String get bailianSectionNote => '生成角色的配音，按地域选择接入点。';

  @override
  String get bailianKey => '百炼密钥';

  @override
  String get region => '地域';

  @override
  String get regionBeijing => '北京';

  @override
  String get regionSingapore => '新加坡';

  @override
  String get keyStored => '已保存';

  @override
  String get keyNotSet => '未设置';

  @override
  String get keyWillBeRemoved => '将删除';

  @override
  String get keyHint => '粘贴密钥';

  @override
  String get keyStoredHint => '留空保持不变，输入则替换';

  @override
  String get keyRemovedHint => '保存后删除这个密钥';

  @override
  String get showKey => '显示';

  @override
  String get hideKey => '隐藏';

  @override
  String get removeKey => '删除密钥';

  @override
  String get undoRemoveKey => '撤销删除';

  @override
  String get saveSettings => '保存';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get settingsSaveFailed => '没能保存设置';

  @override
  String get settingsSaveFailedBody => '设置没有改变。检查一下填写的内容，再保存一次。';

  @override
  String get castSection => '演员';

  @override
  String get exclusiveVoices => '独占声音数';

  @override
  String get exclusiveVoicesNote => '戏份最多的角色各用一个专属声音，其余角色共用群演声音。';

  @override
  String get exclusiveVoicesFailed => '没能修改独占声音数';

  @override
  String get fewerVoices => '减少';

  @override
  String get moreVoices => '增加';

  @override
  String consentTitle(String title) {
    return '把《$title》的内容发出去？';
  }

  @override
  String get consentChapterTextAndCast => '导演需要所选章节的正文和这本书的演员表，用来分配台词和声音。';

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
  String get consentChapterTextAndCastName => '章节正文与演员表';

  @override
  String get consentVoiceSampleName => '声音样本文本';

  @override
  String get consentBookContentName => '书的内容';

  @override
  String get consentCancelNote => '取消则什么都不会发送。';

  @override
  String get consentAccept => '同意并发送';

  @override
  String generationTitle(String chapter) {
    return '$chapter还没有配音';
  }

  @override
  String get generationBody => '可以现在生成 AI 配音，边听边生成；也可以先用手机自带的声音朗读。';

  @override
  String generationOutOfRange(String chapter) {
    return '$chapter还没有建档，暂时不能生成配音。把建档延伸到这一章后就可以生成；现在也可以先用手机自带的声音朗读。';
  }

  @override
  String get generateNow => '生成配音';

  @override
  String get useSystemVoice => '用系统声音朗读';

  @override
  String extendProfilingTo(String chapter) {
    return '把建档延伸到$chapter';
  }

  @override
  String get waitingForSynthesis => '正在生成接下来的配音，好了就继续播放';

  @override
  String get generationPausedTitle => '配音生成暂停了';

  @override
  String get generationResumeFailed => '没能继续生成，请稍后再试';

  @override
  String generationPausedLine(String chapter, String provider, String reason) {
    return '$chapter · $provider：$reason';
  }

  @override
  String get resumeGeneration => '继续生成';

  @override
  String get reasonVoiceUnavailable => '分配的声音已不可用，请在演员表里换一个';

  @override
  String get errorAudioChanged => '音频已更新（清理过或换了声音），点播放重新准备。';

  @override
  String get errorGenerationCancelled => '已取消生成，点播放可以重新选择。';

  @override
  String get performanceMode => '演绎方式';

  @override
  String get modeAudiobook => '有声书';

  @override
  String get modeDrama => '广播剧';

  @override
  String get modeAudiobookNote => '旁白完整朗读原文，包括「他说」「她问道」这类提示。';

  @override
  String get modeDramaNote => '角色直接开口，跳过「他说」这类说话提示。';

  @override
  String get modeSaveFailed => '没能保存演绎方式，请再试一次';

  @override
  String get generationSection => '边听边生成';

  @override
  String get generationSectionNote =>
      '提前量是在你听到之前预先处理的章数；合成提前量不能超过导演提前量，设为 0 表示关闭。';

  @override
  String get autoGenerate => '自动生成配音';

  @override
  String get autoGenerateNote => '播放没有配音的章节时直接生成，不再询问';

  @override
  String get directingAhead => '导演提前量';

  @override
  String get synthesisAhead => '合成提前量';

  @override
  String get aheadOff => '关闭';

  @override
  String aheadChapters(int count) {
    return '提前 $count 章';
  }

  @override
  String get fewerDirectingAhead => '减少导演提前量';

  @override
  String get moreDirectingAhead => '增加导演提前量';

  @override
  String get fewerSynthesisAhead => '减少合成提前量';

  @override
  String get moreSynthesisAhead => '增加合成提前量';

  @override
  String get generationSettingsFailed => '没能保存生成设置';

  @override
  String get storageSection => '存储';

  @override
  String get storage => '存储空间';

  @override
  String get storageRowNote => '查看每本书占用的空间，清理音频';

  @override
  String get storageNote =>
      '按书统计：书的正文、剧本、演员表等记录加上它的音频文件。数据库文件由所有书共用，其中的索引和日志开销不计入。';

  @override
  String get storageLoadFailed => '没能读取存储空间';

  @override
  String get storageEmpty => '还没有占用空间的书';

  @override
  String get storageTotal => '总占用';

  @override
  String get storageAudio => '可清理的音频';

  @override
  String get storageBooks => '书';

  @override
  String storageBookLine(String total, String audio) {
    return '共 $total · 音频 $audio';
  }

  @override
  String get clearAudio => '清理音频';

  @override
  String get clearAudioNote => '清理只删除生成的音频、试听和合成缓存；正文、剧本和演员表都会保留，之后播放时再按需重新合成。';

  @override
  String clearAudioTitle(String title) {
    return '清理《$title》的音频？';
  }

  @override
  String clearAudioBody(String size) {
    return '将释放 $size。正文、剧本和演员表会保留；再听这本书时，会按需重新合成音频。';
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
  String get changeVoice => '换音色';

  @override
  String get designVoice => '设计音色';

  @override
  String changeVoiceTitle(String name) {
    return '给$name换声音';
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
  String get presetsEmpty => '当前配置下没有适合这本书语言的预设音色。';

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
    return '已为$name换上新声音';
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
  String get diagnosticsSection => '诊断与反馈';

  @override
  String get exportDiagnostics => '导出诊断报告';

  @override
  String get exportDiagnosticsNote => '生成报告，通过系统分享发给你选择的人或应用';

  @override
  String get exportingDiagnostics => '正在准备报告…';

  @override
  String get reportProblem => '反馈问题';

  @override
  String get reportProblemNote => '在浏览器里打开项目的 GitHub，新建一个问题';

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
  String get diagnosticsPrivacyTitle => '报告里有什么';

  @override
  String get diagnosticsIncludes => '包含：应用版本、系统与设备信息、近期的错误和崩溃记录。';

  @override
  String get diagnosticsExcludes => '不包含：任何密钥，以及书的正文。';

  @override
  String get diagnosticsNoUpload => '不会自动上传：只有你在分享里选择发送时，报告才会离开手机。';
}
