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
  String get chapterUnprofiled => '未建档';

  @override
  String get chapterUndirected => '未导演';

  @override
  String get chapterDirected => '已导演';

  @override
  String get chapterSynthesized => '已合成';

  @override
  String get chapterWorking => '生成中';

  @override
  String get chapterFailed => '出错';

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
  String get shelfEmptyBody => '导入手机里的 TXT 小说，就可以在这里读和听。';

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
    return '「$file」不是 TXT 文件';
  }

  @override
  String get importUnsupportedBody => '目前只能导入 TXT 文本文件，书架没有变化。';

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
  String get importUnreadableBody => '文件可能损坏了，或者不是 UTF-8、GBK 编码。书架没有变化。';

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
  String get resumeProfiling => '继续建档';

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
  String get reasonInvalidResponse => '服务商返回的内容无法使用';

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
}
