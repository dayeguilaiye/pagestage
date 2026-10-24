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
}
