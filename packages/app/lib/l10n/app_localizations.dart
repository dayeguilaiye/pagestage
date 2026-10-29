import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @play.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @narrator.
  ///
  /// In zh, this message translates to:
  /// **'旁白'**
  String get narrator;

  /// The single glyph on the narrator's seal.
  ///
  /// In zh, this message translates to:
  /// **'旁'**
  String get narratorSeal;

  /// No description provided for @extra.
  ///
  /// In zh, this message translates to:
  /// **'群演'**
  String get extra;

  /// No description provided for @audition.
  ///
  /// In zh, this message translates to:
  /// **'试听'**
  String get audition;

  /// No description provided for @stopAudition.
  ///
  /// In zh, this message translates to:
  /// **'停止试听'**
  String get stopAudition;

  /// No description provided for @auditioning.
  ///
  /// In zh, this message translates to:
  /// **'试听中'**
  String get auditioning;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @player.
  ///
  /// In zh, this message translates to:
  /// **'播放器'**
  String get player;

  /// Tag that always sits beside the player: the audio is synthesized.
  ///
  /// In zh, this message translates to:
  /// **'AI 合成'**
  String get aiVoice;

  /// No description provided for @nextLine.
  ///
  /// In zh, this message translates to:
  /// **'下一句'**
  String get nextLine;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @chapterQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get chapterQueued;

  /// No description provided for @chapterWorking.
  ///
  /// In zh, this message translates to:
  /// **'生成中'**
  String get chapterWorking;

  /// No description provided for @chapterPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get chapterPaused;

  /// No description provided for @chapterDirecting.
  ///
  /// In zh, this message translates to:
  /// **'导演中 {elapsed}'**
  String chapterDirecting(String elapsed);

  /// No description provided for @chapterVoicing.
  ///
  /// In zh, this message translates to:
  /// **'配音中 {voiced}/{total}'**
  String chapterVoicing(int voiced, int total);

  /// No description provided for @chapterPausedBecause.
  ///
  /// In zh, this message translates to:
  /// **'已暂停：{reason}'**
  String chapterPausedBecause(String reason);

  /// No description provided for @prepareChapters.
  ///
  /// In zh, this message translates to:
  /// **'提前生成'**
  String get prepareChapters;

  /// No description provided for @prepareFrom.
  ///
  /// In zh, this message translates to:
  /// **'从'**
  String get prepareFrom;

  /// No description provided for @prepareThrough.
  ///
  /// In zh, this message translates to:
  /// **'到'**
  String get prepareThrough;

  /// No description provided for @prepareNote.
  ///
  /// In zh, this message translates to:
  /// **'先为这些章节导演、配音，听的时候直接播放。正文会发给你设置的大模型和配音服务；已经生成好的章节会跳过。'**
  String get prepareNote;

  /// No description provided for @prepareRange.
  ///
  /// In zh, this message translates to:
  /// **'生成第 {first}–{through} 章'**
  String prepareRange(int first, int through);

  /// No description provided for @prepareOne.
  ///
  /// In zh, this message translates to:
  /// **'生成第 {chapter} 章'**
  String prepareOne(int chapter);

  /// No description provided for @prepareNeedsProfile.
  ///
  /// In zh, this message translates to:
  /// **'建档范围内的章节才能生成。先在演员表里建档。'**
  String get prepareNeedsProfile;

  /// No description provided for @prepareFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能开始生成，请稍后再试。'**
  String get prepareFailed;

  /// No description provided for @shelfTitle.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get shelfTitle;

  /// No description provided for @importBook.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importBook;

  /// No description provided for @importing.
  ///
  /// In zh, this message translates to:
  /// **'正在导入'**
  String get importing;

  /// No description provided for @shelfAll.
  ///
  /// In zh, this message translates to:
  /// **'全部 · {count} 本'**
  String shelfAll(int count);

  /// No description provided for @shelfEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'书架还是空的'**
  String get shelfEmptyTitle;

  /// No description provided for @shelfEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'导入手机里的 TXT 或无 DRM 的 EPUB 小说，就可以在这里读和听。'**
  String get shelfEmptyBody;

  /// No description provided for @shelfEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'导入一本书'**
  String get shelfEmptyAction;

  /// No description provided for @shelfLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能读取书架'**
  String get shelfLoadFailed;

  /// No description provided for @chapterCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 章'**
  String chapterCount(int count);

  /// No description provided for @bookImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入《{title}》'**
  String bookImported(String title);

  /// No description provided for @importUnsupportedTitle.
  ///
  /// In zh, this message translates to:
  /// **'不支持「{file}」的格式'**
  String importUnsupportedTitle(String file);

  /// No description provided for @importUnsupportedBody.
  ///
  /// In zh, this message translates to:
  /// **'目前可以导入 TXT 和没有 DRM 的 EPUB 文件，书架没有变化。'**
  String get importUnsupportedBody;

  /// No description provided for @importDrmTitle.
  ///
  /// In zh, this message translates to:
  /// **'「{file}」有 DRM 版权保护'**
  String importDrmTitle(String file);

  /// No description provided for @importDrmBody.
  ///
  /// In zh, this message translates to:
  /// **'受 DRM 保护的 EPUB 无法读取正文。请导入没有 DRM 的 EPUB 或 TXT 文件，书架没有变化。'**
  String get importDrmBody;

  /// No description provided for @bookUpdated.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》已更新：新增 {added} 章，{changed} 章内容有变化'**
  String bookUpdated(String title, int added, int changed);

  /// No description provided for @bookUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》已经是最新的，没有变化'**
  String bookUnchanged(String title);

  /// No description provided for @importEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'「{file}」里没有文字'**
  String importEmptyTitle(String file);

  /// No description provided for @importEmptyBody.
  ///
  /// In zh, this message translates to:
  /// **'书架没有变化。换一个有正文的 TXT 文件再试。'**
  String get importEmptyBody;

  /// No description provided for @importUnreadableTitle.
  ///
  /// In zh, this message translates to:
  /// **'读不出「{file}」的文字'**
  String importUnreadableTitle(String file);

  /// No description provided for @importUnreadableBody.
  ///
  /// In zh, this message translates to:
  /// **'文件可能损坏了；TXT 文件需要是 UTF-8 或 GBK 编码。书架没有变化。'**
  String get importUnreadableBody;

  /// No description provided for @importAnother.
  ///
  /// In zh, this message translates to:
  /// **'换一个文件'**
  String get importAnother;

  /// No description provided for @deleteBook.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteBook;

  /// No description provided for @deleteBookTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除《{title}》？'**
  String deleteBookTitle(String title);

  /// No description provided for @deleteBookBody.
  ///
  /// In zh, this message translates to:
  /// **'这本书的章节、演员表、剧本和音频都会删掉，不能恢复。'**
  String get deleteBookBody;

  /// No description provided for @deleteBookConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除这本书'**
  String get deleteBookConfirm;

  /// No description provided for @contents.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get contents;

  /// No description provided for @contentsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能读取目录'**
  String get contentsLoadFailed;

  /// No description provided for @chapterLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能打开这一章'**
  String get chapterLoadFailed;

  /// No description provided for @readingSettings.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readingSettings;

  /// No description provided for @textSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get textSize;

  /// No description provided for @lineSpacing.
  ///
  /// In zh, this message translates to:
  /// **'行距'**
  String get lineSpacing;

  /// No description provided for @lineSpacingCompact.
  ///
  /// In zh, this message translates to:
  /// **'紧凑'**
  String get lineSpacingCompact;

  /// No description provided for @lineSpacingComfortable.
  ///
  /// In zh, this message translates to:
  /// **'舒适'**
  String get lineSpacingComfortable;

  /// No description provided for @lineSpacingLoose.
  ///
  /// In zh, this message translates to:
  /// **'宽松'**
  String get lineSpacingLoose;

  /// No description provided for @nightMode.
  ///
  /// In zh, this message translates to:
  /// **'夜间模式'**
  String get nightMode;

  /// No description provided for @nightModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get nightModeSystem;

  /// No description provided for @nightModeOff.
  ///
  /// In zh, this message translates to:
  /// **'关'**
  String get nightModeOff;

  /// No description provided for @nightModeOn.
  ///
  /// In zh, this message translates to:
  /// **'开'**
  String get nightModeOn;

  /// No description provided for @playFromHere.
  ///
  /// In zh, this message translates to:
  /// **'从这里播放'**
  String get playFromHere;

  /// No description provided for @previousLine.
  ///
  /// In zh, this message translates to:
  /// **'上一句'**
  String get previousLine;

  /// No description provided for @playbackFixtureMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先准备本地播放素材，再运行播放原型。'**
  String get playbackFixtureMissing;

  /// Tag beside the player when the phone's own text-to-speech voice is reading.
  ///
  /// In zh, this message translates to:
  /// **'系统朗读'**
  String get systemVoice;

  /// No description provided for @systemVoiceNote.
  ///
  /// In zh, this message translates to:
  /// **'这一章还没有生成配音，先用手机自带的声音朗读。'**
  String get systemVoiceNote;

  /// No description provided for @chapterNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 章'**
  String chapterNumber(int number);

  /// No description provided for @chapterOfCount.
  ///
  /// In zh, this message translates to:
  /// **'{title} · {number} / {count}'**
  String chapterOfCount(String title, int number, int count);

  /// No description provided for @lineOfCount.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} / {count} 句'**
  String lineOfCount(int number, int count);

  /// No description provided for @nowListening.
  ///
  /// In zh, this message translates to:
  /// **'正在听'**
  String get nowListening;

  /// No description provided for @closePlayer.
  ///
  /// In zh, this message translates to:
  /// **'收起播放器'**
  String get closePlayer;

  /// No description provided for @openPlayer.
  ///
  /// In zh, this message translates to:
  /// **'打开播放器'**
  String get openPlayer;

  /// No description provided for @nothingPlayingTitle.
  ///
  /// In zh, this message translates to:
  /// **'现在没有在听的书'**
  String get nothingPlayingTitle;

  /// No description provided for @nothingPlayingBody.
  ///
  /// In zh, this message translates to:
  /// **'在书架上选一本书，点「开始听」。'**
  String get nothingPlayingBody;

  /// No description provided for @backToShelf.
  ///
  /// In zh, this message translates to:
  /// **'回到书架'**
  String get backToShelf;

  /// No description provided for @chapterProgress.
  ///
  /// In zh, this message translates to:
  /// **'本章进度'**
  String get chapterProgress;

  /// No description provided for @previousChapter.
  ///
  /// In zh, this message translates to:
  /// **'上一章'**
  String get previousChapter;

  /// No description provided for @nextChapter.
  ///
  /// In zh, this message translates to:
  /// **'下一章'**
  String get nextChapter;

  /// No description provided for @playbackSpeed.
  ///
  /// In zh, this message translates to:
  /// **'播放速度'**
  String get playbackSpeed;

  /// No description provided for @speedShort.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get speedShort;

  /// No description provided for @sleepTimer.
  ///
  /// In zh, this message translates to:
  /// **'睡眠定时'**
  String get sleepTimer;

  /// No description provided for @sleepTimerShort.
  ///
  /// In zh, this message translates to:
  /// **'定时'**
  String get sleepTimerShort;

  /// No description provided for @sleepEndOfChapterShort.
  ///
  /// In zh, this message translates to:
  /// **'本章结束'**
  String get sleepEndOfChapterShort;

  /// No description provided for @sleepOff.
  ///
  /// In zh, this message translates to:
  /// **'不定时'**
  String get sleepOff;

  /// No description provided for @sleepMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟后'**
  String sleepMinutes(int minutes);

  /// No description provided for @sleepEndOfChapter.
  ///
  /// In zh, this message translates to:
  /// **'听完本章'**
  String get sleepEndOfChapter;

  /// No description provided for @sleepStopsIn.
  ///
  /// In zh, this message translates to:
  /// **'{time} 后停止播放'**
  String sleepStopsIn(String time);

  /// No description provided for @sleepStopsAtChapterEnd.
  ///
  /// In zh, this message translates to:
  /// **'本章结束时停止播放'**
  String get sleepStopsAtChapterEnd;

  /// No description provided for @readAlong.
  ///
  /// In zh, this message translates to:
  /// **'跟读'**
  String get readAlong;

  /// No description provided for @listenToChapter.
  ///
  /// In zh, this message translates to:
  /// **'听这一章'**
  String get listenToChapter;

  /// No description provided for @backToSpokenLine.
  ///
  /// In zh, this message translates to:
  /// **'回到朗读处'**
  String get backToSpokenLine;

  /// No description provided for @startListening.
  ///
  /// In zh, this message translates to:
  /// **'开始听'**
  String get startListening;

  /// No description provided for @resumeListening.
  ///
  /// In zh, this message translates to:
  /// **'继续听 · 第 {chapter} 章'**
  String resumeListening(int chapter);

  /// No description provided for @listenedTo.
  ///
  /// In zh, this message translates to:
  /// **'听到第 {chapter} 章'**
  String listenedTo(int chapter);

  /// No description provided for @errorNoSystemVoice.
  ///
  /// In zh, this message translates to:
  /// **'手机上没有可用的朗读声音。请在系统设置里下载一个中文或英文语音包。'**
  String get errorNoSystemVoice;

  /// No description provided for @endOfBook.
  ///
  /// In zh, this message translates to:
  /// **'全书听完了'**
  String get endOfBook;

  /// No description provided for @errorChapterUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'没能打开这一章，试试下一章。'**
  String get errorChapterUnavailable;

  /// No description provided for @errorAudioFailed.
  ///
  /// In zh, this message translates to:
  /// **'这一段音频播放不了，试试下一句。'**
  String get errorAudioFailed;

  /// No description provided for @errorBookMissing.
  ///
  /// In zh, this message translates to:
  /// **'这本书已经不在书架上了。'**
  String get errorBookMissing;

  /// No description provided for @errorPlaybackStopped.
  ///
  /// In zh, this message translates to:
  /// **'播放停下来了，再点一次播放试试。'**
  String get errorPlaybackStopped;

  /// No description provided for @providerUnknown.
  ///
  /// In zh, this message translates to:
  /// **'服务商'**
  String get providerUnknown;

  /// No description provided for @providerLlm.
  ///
  /// In zh, this message translates to:
  /// **'大模型'**
  String get providerLlm;

  /// No description provided for @providerBailian.
  ///
  /// In zh, this message translates to:
  /// **'阿里云百炼'**
  String get providerBailian;

  /// No description provided for @cast.
  ///
  /// In zh, this message translates to:
  /// **'演员表'**
  String get cast;

  /// No description provided for @castLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能读取演员表'**
  String get castLoadFailed;

  /// No description provided for @castMembers.
  ///
  /// In zh, this message translates to:
  /// **'演员 · {count} 位'**
  String castMembers(int count);

  /// No description provided for @castEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有演员。建档后，书里的说话人和他们的声音会列在这里。'**
  String get castEmpty;

  /// No description provided for @castEmptyWorking.
  ///
  /// In zh, this message translates to:
  /// **'正在建档，找到的说话人会陆续出现在这里。'**
  String get castEmptyWorking;

  /// No description provided for @castProvisional.
  ///
  /// In zh, this message translates to:
  /// **'暂定'**
  String get castProvisional;

  /// No description provided for @voiceNotAssigned.
  ///
  /// In zh, this message translates to:
  /// **'还没有分配声音'**
  String get voiceNotAssigned;

  /// No description provided for @auditionFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能播放试听'**
  String get auditionFailed;

  /// No description provided for @profileGender.
  ///
  /// In zh, this message translates to:
  /// **'性别'**
  String get profileGender;

  /// No description provided for @profileAge.
  ///
  /// In zh, this message translates to:
  /// **'年龄'**
  String get profileAge;

  /// No description provided for @profilePersonality.
  ///
  /// In zh, this message translates to:
  /// **'性格'**
  String get profilePersonality;

  /// No description provided for @profileSpeakingStyle.
  ///
  /// In zh, this message translates to:
  /// **'说话方式'**
  String get profileSpeakingStyle;

  /// No description provided for @profileVoice.
  ///
  /// In zh, this message translates to:
  /// **'声音'**
  String get profileVoice;

  /// No description provided for @profileEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有档案信息。'**
  String get profileEmpty;

  /// No description provided for @profiling.
  ///
  /// In zh, this message translates to:
  /// **'建档'**
  String get profiling;

  /// No description provided for @chaptersProfiled.
  ///
  /// In zh, this message translates to:
  /// **'章已建档'**
  String get chaptersProfiled;

  /// No description provided for @statusQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get statusQueued;

  /// No description provided for @statusRunning.
  ///
  /// In zh, this message translates to:
  /// **'建档中'**
  String get statusRunning;

  /// No description provided for @statusPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get statusPaused;

  /// No description provided for @statusComplete.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusComplete;

  /// No description provided for @profilingQueuedTo.
  ///
  /// In zh, this message translates to:
  /// **'排队中，将建档到第 {chapter} 章'**
  String profilingQueuedTo(int chapter);

  /// No description provided for @profilingRunningTo.
  ///
  /// In zh, this message translates to:
  /// **'正在建档到第 {chapter} 章'**
  String profilingRunningTo(int chapter);

  /// No description provided for @profilingPausedTitle.
  ///
  /// In zh, this message translates to:
  /// **'建档暂停了'**
  String get profilingPausedTitle;

  /// No description provided for @profilingPausedBody.
  ///
  /// In zh, this message translates to:
  /// **'{provider}：{reason}'**
  String profilingPausedBody(String provider, String reason);

  /// No description provided for @resumeProfilingTo.
  ///
  /// In zh, this message translates to:
  /// **'继续建档到第 {chapter} 章'**
  String resumeProfilingTo(int chapter);

  /// No description provided for @profilingSkipped.
  ///
  /// In zh, this message translates to:
  /// **'已跳过第 {chapters} 章：服务商没能处理这些内容'**
  String profilingSkipped(String chapters);

  /// No description provided for @chapterListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'、'**
  String get chapterListSeparator;

  /// No description provided for @profilingActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能开始建档，请稍后再试。'**
  String get profilingActionFailed;

  /// No description provided for @profiledWholeBook.
  ///
  /// In zh, this message translates to:
  /// **'全书都已建档。'**
  String get profiledWholeBook;

  /// No description provided for @profileThrough.
  ///
  /// In zh, this message translates to:
  /// **'建档到'**
  String get profileThrough;

  /// No description provided for @startProfiling.
  ///
  /// In zh, this message translates to:
  /// **'开始建档'**
  String get startProfiling;

  /// No description provided for @extendProfiling.
  ///
  /// In zh, this message translates to:
  /// **'继续往后建档'**
  String get extendProfiling;

  /// No description provided for @profilingNote.
  ///
  /// In zh, this message translates to:
  /// **'建档会把所选章节的正文发给你设置的大模型，用来找出说话人、为他们挑选声音。发送前会先征得你的同意。'**
  String get profilingNote;

  /// No description provided for @reasonMissingKey.
  ///
  /// In zh, this message translates to:
  /// **'还没有填写密钥，请到设置里补上'**
  String get reasonMissingKey;

  /// No description provided for @reasonUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'密钥无效或没有权限，请到设置里检查'**
  String get reasonUnauthorized;

  /// No description provided for @reasonRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'请求太频繁，过一会儿再继续'**
  String get reasonRateLimited;

  /// No description provided for @reasonQuotaExceeded.
  ///
  /// In zh, this message translates to:
  /// **'账户额度用完了'**
  String get reasonQuotaExceeded;

  /// No description provided for @reasonNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接中断'**
  String get reasonNetwork;

  /// No description provided for @reasonConsentDeclined.
  ///
  /// In zh, this message translates to:
  /// **'你取消了发送'**
  String get reasonConsentDeclined;

  /// No description provided for @reasonInvalidResponse.
  ///
  /// In zh, this message translates to:
  /// **'模型的回复格式不对，可以稍后继续或换个模型'**
  String get reasonInvalidResponse;

  /// No description provided for @reasonRequestRejected.
  ///
  /// In zh, this message translates to:
  /// **'服务商拒绝了请求，请检查接口地址和模型名称'**
  String get reasonRequestRejected;

  /// No description provided for @reasonSchemaUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'这个接口不支持结构化输出（JSON Schema），请换一个支持的模型或服务商'**
  String get reasonSchemaUnsupported;

  /// No description provided for @reasonContentRejected.
  ///
  /// In zh, this message translates to:
  /// **'服务商拒绝处理这一章的内容'**
  String get reasonContentRejected;

  /// No description provided for @reasonTruncated.
  ///
  /// In zh, this message translates to:
  /// **'这一章的回复超出了模型的输出长度上限'**
  String get reasonTruncated;

  /// No description provided for @reasonInterrupted.
  ///
  /// In zh, this message translates to:
  /// **'应用关闭时中断了'**
  String get reasonInterrupted;

  /// No description provided for @reasonUnknown.
  ///
  /// In zh, this message translates to:
  /// **'服务暂时不可用'**
  String get reasonUnknown;

  /// No description provided for @consentTitle.
  ///
  /// In zh, this message translates to:
  /// **'把《{title}》的内容发出去？'**
  String consentTitle(String title);

  /// No description provided for @consentChapterTextAndCast.
  ///
  /// In zh, this message translates to:
  /// **'导演需要所选章节的正文和这本书的演员表，用来分配台词和声音。'**
  String get consentChapterTextAndCast;

  /// No description provided for @consentVoiceSample.
  ///
  /// In zh, this message translates to:
  /// **'生成试听需要一段示例文本和角色的声音描述。'**
  String get consentVoiceSample;

  /// No description provided for @consentBookContent.
  ///
  /// In zh, this message translates to:
  /// **'这一步需要把书里的内容发给服务商。'**
  String get consentBookContent;

  /// No description provided for @consentProvider.
  ///
  /// In zh, this message translates to:
  /// **'服务商'**
  String get consentProvider;

  /// No description provided for @consentEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'发送到'**
  String get consentEndpoint;

  /// No description provided for @consentContentLabel.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get consentContentLabel;

  /// No description provided for @consentChapterTextAndCastName.
  ///
  /// In zh, this message translates to:
  /// **'章节正文与演员表'**
  String get consentChapterTextAndCastName;

  /// No description provided for @consentVoiceSampleName.
  ///
  /// In zh, this message translates to:
  /// **'声音样本文本'**
  String get consentVoiceSampleName;

  /// No description provided for @consentBookContentName.
  ///
  /// In zh, this message translates to:
  /// **'书的内容'**
  String get consentBookContentName;

  /// No description provided for @consentCancelNote.
  ///
  /// In zh, this message translates to:
  /// **'取消则什么都不会发送。'**
  String get consentCancelNote;

  /// No description provided for @consentAccept.
  ///
  /// In zh, this message translates to:
  /// **'同意并发送'**
  String get consentAccept;

  /// No description provided for @generationTitle.
  ///
  /// In zh, this message translates to:
  /// **'{chapter}还没有配音'**
  String generationTitle(String chapter);

  /// No description provided for @generationBody.
  ///
  /// In zh, this message translates to:
  /// **'可以现在生成 AI 配音，边听边生成；也可以先用手机自带的声音朗读。'**
  String get generationBody;

  /// No description provided for @generationOutOfRange.
  ///
  /// In zh, this message translates to:
  /// **'{chapter}还没有建档，暂时不能生成配音。把建档延伸到这一章后就可以生成；现在也可以先用手机自带的声音朗读。'**
  String generationOutOfRange(String chapter);

  /// No description provided for @generateNow.
  ///
  /// In zh, this message translates to:
  /// **'生成配音'**
  String get generateNow;

  /// No description provided for @useSystemVoice.
  ///
  /// In zh, this message translates to:
  /// **'用系统声音朗读'**
  String get useSystemVoice;

  /// No description provided for @extendProfilingTo.
  ///
  /// In zh, this message translates to:
  /// **'把建档延伸到{chapter}'**
  String extendProfilingTo(String chapter);

  /// No description provided for @waitingForSynthesis.
  ///
  /// In zh, this message translates to:
  /// **'正在生成接下来的配音，好了就继续播放'**
  String get waitingForSynthesis;

  /// No description provided for @generationPausedTitle.
  ///
  /// In zh, this message translates to:
  /// **'配音生成暂停了'**
  String get generationPausedTitle;

  /// No description provided for @generationResumeFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能继续生成，请稍后再试'**
  String get generationResumeFailed;

  /// No description provided for @generationPausedLine.
  ///
  /// In zh, this message translates to:
  /// **'{chapter} · {provider}：{reason}'**
  String generationPausedLine(String chapter, String provider, String reason);

  /// No description provided for @resumeGeneration.
  ///
  /// In zh, this message translates to:
  /// **'继续生成'**
  String get resumeGeneration;

  /// No description provided for @reasonVoiceUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'分配的声音已不可用，请在演员表里换一个'**
  String get reasonVoiceUnavailable;

  /// No description provided for @errorAudioChanged.
  ///
  /// In zh, this message translates to:
  /// **'音频已更新（清理过或换了声音），点播放重新准备。'**
  String get errorAudioChanged;

  /// No description provided for @errorGenerationCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消生成，点播放可以重新选择。'**
  String get errorGenerationCancelled;

  /// No description provided for @performanceMode.
  ///
  /// In zh, this message translates to:
  /// **'演绎方式'**
  String get performanceMode;

  /// No description provided for @modeAudiobook.
  ///
  /// In zh, this message translates to:
  /// **'有声书'**
  String get modeAudiobook;

  /// No description provided for @modeDrama.
  ///
  /// In zh, this message translates to:
  /// **'广播剧'**
  String get modeDrama;

  /// No description provided for @modeAudiobookNote.
  ///
  /// In zh, this message translates to:
  /// **'旁白完整朗读原文，包括「他说」「她问道」这类提示。'**
  String get modeAudiobookNote;

  /// No description provided for @modeDramaNote.
  ///
  /// In zh, this message translates to:
  /// **'角色直接开口，跳过「他说」这类说话提示。'**
  String get modeDramaNote;

  /// No description provided for @modeSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能保存演绎方式，请再试一次'**
  String get modeSaveFailed;

  /// No description provided for @changeVoice.
  ///
  /// In zh, this message translates to:
  /// **'换音色'**
  String get changeVoice;

  /// No description provided for @designVoice.
  ///
  /// In zh, this message translates to:
  /// **'设计音色'**
  String get designVoice;

  /// No description provided for @changeVoiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'给{name}换声音'**
  String changeVoiceTitle(String name);

  /// No description provided for @currentVoice.
  ///
  /// In zh, this message translates to:
  /// **'现在用的是「{voice}」'**
  String currentVoice(String voice);

  /// No description provided for @presetVoices.
  ///
  /// In zh, this message translates to:
  /// **'预设音色'**
  String get presetVoices;

  /// No description provided for @voiceDesign.
  ///
  /// In zh, this message translates to:
  /// **'音色设计'**
  String get voiceDesign;

  /// No description provided for @hearBeforeChoosing.
  ///
  /// In zh, this message translates to:
  /// **'先试听，听过之后才能选用。'**
  String get hearBeforeChoosing;

  /// No description provided for @chooseVoice.
  ///
  /// In zh, this message translates to:
  /// **'选用'**
  String get chooseVoice;

  /// No description provided for @voiceInUse.
  ///
  /// In zh, this message translates to:
  /// **'使用中'**
  String get voiceInUse;

  /// No description provided for @chooseVoiceFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能换上这个声音，请再试一次'**
  String get chooseVoiceFailed;

  /// No description provided for @presetsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能读取预设音色'**
  String get presetsLoadFailed;

  /// No description provided for @presetsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'开启的配音服务商里没有适合这本书语言的预设音色。'**
  String get presetsEmpty;

  /// No description provided for @designProvider.
  ///
  /// In zh, this message translates to:
  /// **'设计服务商'**
  String get designProvider;

  /// No description provided for @voiceDescriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'声音描述'**
  String get voiceDescriptionLabel;

  /// No description provided for @voiceDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：五十岁上下的男声，低沉沙哑，说话慢条斯理'**
  String get voiceDescriptionHint;

  /// No description provided for @designCandidates.
  ///
  /// In zh, this message translates to:
  /// **'生成 3 个候选'**
  String get designCandidates;

  /// No description provided for @designCandidatesAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新生成候选'**
  String get designCandidatesAgain;

  /// No description provided for @designing.
  ///
  /// In zh, this message translates to:
  /// **'正在设计声音，需要一点时间'**
  String get designing;

  /// No description provided for @designFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能设计出声音'**
  String get designFailed;

  /// No description provided for @designFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'描述和服务商都还在，可以直接重试或改一改描述。'**
  String get designFailedBody;

  /// No description provided for @candidates.
  ///
  /// In zh, this message translates to:
  /// **'候选声音'**
  String get candidates;

  /// No description provided for @voiceChanged.
  ///
  /// In zh, this message translates to:
  /// **'已为{name}换上新声音'**
  String voiceChanged(String name);

  /// No description provided for @voiceRebuiltTitle.
  ///
  /// In zh, this message translates to:
  /// **'{name}的声音重建了'**
  String voiceRebuiltTitle(String name);

  /// No description provided for @voiceRebuiltBody.
  ///
  /// In zh, this message translates to:
  /// **'{provider}的声音绑定已重新建立，听起来可能和之前不同，建议重新试听。'**
  String voiceRebuiltBody(String provider);

  /// No description provided for @listenAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新试听'**
  String get listenAgain;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @llm.
  ///
  /// In zh, this message translates to:
  /// **'大模型'**
  String get llm;

  /// No description provided for @voiceRole.
  ///
  /// In zh, this message translates to:
  /// **'配音和音色设计'**
  String get voiceRole;

  /// No description provided for @voiceRoleNoDesign.
  ///
  /// In zh, this message translates to:
  /// **'配音'**
  String get voiceRoleNoDesign;

  /// No description provided for @providerReady.
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get providerReady;

  /// No description provided for @providerNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get providerNotSet;

  /// No description provided for @llmNoModel.
  ///
  /// In zh, this message translates to:
  /// **'缺少模型'**
  String get llmNoModel;

  /// No description provided for @llmNoKey.
  ///
  /// In zh, this message translates to:
  /// **'缺少密钥'**
  String get llmNoKey;

  /// No description provided for @setupTitle.
  ///
  /// In zh, this message translates to:
  /// **'先配置大模型'**
  String get setupTitle;

  /// No description provided for @setupBody.
  ///
  /// In zh, this message translates to:
  /// **'建档和导演要用你自己的大模型账户。'**
  String get setupBody;

  /// No description provided for @setupAction.
  ///
  /// In zh, this message translates to:
  /// **'配置大模型'**
  String get setupAction;

  /// No description provided for @generationSection.
  ///
  /// In zh, this message translates to:
  /// **'边听边生成'**
  String get generationSection;

  /// No description provided for @generationSectionNote.
  ///
  /// In zh, this message translates to:
  /// **'只在收听时生效，静默阅读不会触发。合成提前量不会超过导演提前量，设为 0 即关闭。'**
  String get generationSectionNote;

  /// No description provided for @autoGenerate.
  ///
  /// In zh, this message translates to:
  /// **'自动生成配音'**
  String get autoGenerate;

  /// No description provided for @autoGenerateNote.
  ///
  /// In zh, this message translates to:
  /// **'没有配音的章节直接生成，不再询问'**
  String get autoGenerateNote;

  /// No description provided for @directingAhead.
  ///
  /// In zh, this message translates to:
  /// **'导演提前量'**
  String get directingAhead;

  /// No description provided for @directingAheadNote.
  ///
  /// In zh, this message translates to:
  /// **'先写好后面几章的剧本'**
  String get directingAheadNote;

  /// No description provided for @synthesisAhead.
  ///
  /// In zh, this message translates to:
  /// **'合成提前量'**
  String get synthesisAhead;

  /// No description provided for @synthesisAheadNote.
  ///
  /// In zh, this message translates to:
  /// **'先生成后面几章的配音'**
  String get synthesisAheadNote;

  /// No description provided for @aheadUnit.
  ///
  /// In zh, this message translates to:
  /// **'章'**
  String get aheadUnit;

  /// No description provided for @fewerDirectingAhead.
  ///
  /// In zh, this message translates to:
  /// **'减少导演提前量'**
  String get fewerDirectingAhead;

  /// No description provided for @moreDirectingAhead.
  ///
  /// In zh, this message translates to:
  /// **'增加导演提前量'**
  String get moreDirectingAhead;

  /// No description provided for @fewerSynthesisAhead.
  ///
  /// In zh, this message translates to:
  /// **'减少合成提前量'**
  String get fewerSynthesisAhead;

  /// No description provided for @moreSynthesisAhead.
  ///
  /// In zh, this message translates to:
  /// **'增加合成提前量'**
  String get moreSynthesisAhead;

  /// No description provided for @generationSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能保存生成设置，请再试一次'**
  String get generationSettingsFailed;

  /// No description provided for @castingSection.
  ///
  /// In zh, this message translates to:
  /// **'选角'**
  String get castingSection;

  /// No description provided for @exclusiveVoices.
  ///
  /// In zh, this message translates to:
  /// **'专属音色'**
  String get exclusiveVoices;

  /// No description provided for @exclusiveVoicesValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String exclusiveVoicesValue(int count);

  /// No description provided for @exclusiveVoicesNote.
  ///
  /// In zh, this message translates to:
  /// **'台词最多的角色各有专属音色，其余共用群演音色。'**
  String get exclusiveVoicesNote;

  /// No description provided for @exclusiveVoicesRecastNote.
  ///
  /// In zh, this message translates to:
  /// **'修改后为已建档的书重新选角，换过或设计的音色不变。'**
  String get exclusiveVoicesRecastNote;

  /// No description provided for @fewerVoices.
  ///
  /// In zh, this message translates to:
  /// **'减少专属音色'**
  String get fewerVoices;

  /// No description provided for @moreVoices.
  ///
  /// In zh, this message translates to:
  /// **'增加专属音色'**
  String get moreVoices;

  /// No description provided for @recast.
  ///
  /// In zh, this message translates to:
  /// **'重新选角'**
  String get recast;

  /// No description provided for @recastDone.
  ///
  /// In zh, this message translates to:
  /// **'已按 {count} 个专属音色重新选角'**
  String recastDone(int count);

  /// No description provided for @recastFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能重新选角，请再试一次'**
  String get recastFailed;

  /// No description provided for @appearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceSection;

  /// No description provided for @storageSection.
  ///
  /// In zh, this message translates to:
  /// **'存储'**
  String get storageSection;

  /// No description provided for @storage.
  ///
  /// In zh, this message translates to:
  /// **'存储空间'**
  String get storage;

  /// No description provided for @storageTotal.
  ///
  /// In zh, this message translates to:
  /// **'共占用'**
  String get storageTotal;

  /// No description provided for @storageAudioPart.
  ///
  /// In zh, this message translates to:
  /// **'音频 {size}'**
  String storageAudioPart(String size);

  /// No description provided for @storageOtherPart.
  ///
  /// In zh, this message translates to:
  /// **'正文、剧本等 {size}'**
  String storageOtherPart(String size);

  /// No description provided for @storageBooks.
  ///
  /// In zh, this message translates to:
  /// **'每本书'**
  String get storageBooks;

  /// No description provided for @storageBookLine.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} · 音频 {audio}'**
  String storageBookLine(String total, String audio);

  /// No description provided for @storageBookNoAudio.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} · 没有音频'**
  String storageBookNoAudio(String total);

  /// No description provided for @storageLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能读取存储空间'**
  String get storageLoadFailed;

  /// No description provided for @storageEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有占用空间的书'**
  String get storageEmpty;

  /// No description provided for @storageCountNote.
  ///
  /// In zh, this message translates to:
  /// **'按书统计正文、剧本、演员表和音频文件；数据库的索引和日志由所有书共用，不计入。'**
  String get storageCountNote;

  /// No description provided for @clearAudio.
  ///
  /// In zh, this message translates to:
  /// **'清理音频'**
  String get clearAudio;

  /// No description provided for @clearAudioNote.
  ///
  /// In zh, this message translates to:
  /// **'清理只删除生成的音频、试听和合成缓存；正文、剧本和演员表都会保留，之后播放时再按需重新合成。'**
  String get clearAudioNote;

  /// No description provided for @clearAudioTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理《{title}》的音频？'**
  String clearAudioTitle(String title);

  /// No description provided for @clearAudioBody.
  ///
  /// In zh, this message translates to:
  /// **'将释放 {size}。正文、剧本和演员表会保留；再听这本书时，会按需重新合成音频。'**
  String clearAudioBody(String size);

  /// No description provided for @clearAudioConfirm.
  ///
  /// In zh, this message translates to:
  /// **'清理音频'**
  String get clearAudioConfirm;

  /// No description provided for @clearAudioFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能清理音频，请再试一次'**
  String get clearAudioFailed;

  /// No description provided for @audioCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清理《{title}》的音频'**
  String audioCleared(String title);

  /// No description provided for @feedbackSection.
  ///
  /// In zh, this message translates to:
  /// **'反馈'**
  String get feedbackSection;

  /// No description provided for @exportDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'导出诊断报告'**
  String get exportDiagnostics;

  /// No description provided for @exportDiagnosticsNote.
  ///
  /// In zh, this message translates to:
  /// **'不含密钥和书的正文'**
  String get exportDiagnosticsNote;

  /// No description provided for @exportingDiagnostics.
  ///
  /// In zh, this message translates to:
  /// **'正在准备报告…'**
  String get exportingDiagnostics;

  /// No description provided for @reportProblem.
  ///
  /// In zh, this message translates to:
  /// **'反馈问题'**
  String get reportProblem;

  /// No description provided for @reportProblemNote.
  ///
  /// In zh, this message translates to:
  /// **'在 GitHub 上新建一个问题'**
  String get reportProblemNote;

  /// No description provided for @openingBrowser.
  ///
  /// In zh, this message translates to:
  /// **'正在打开浏览器…'**
  String get openingBrowser;

  /// No description provided for @exportDiagnosticsFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能导出诊断报告'**
  String get exportDiagnosticsFailed;

  /// No description provided for @exportDiagnosticsFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'报告没有生成或没有打开分享，请再试一次。'**
  String get exportDiagnosticsFailedBody;

  /// No description provided for @reportProblemFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能打开反馈页面'**
  String get reportProblemFailed;

  /// No description provided for @reportProblemFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'浏览器没有打开，请检查网络或默认浏览器后再试。'**
  String get reportProblemFailedBody;

  /// No description provided for @feedbackNote.
  ///
  /// In zh, this message translates to:
  /// **'报告包含应用版本、设备信息和近期错误，不会自动上传，只在你从分享里发送时离开手机。'**
  String get feedbackNote;

  /// No description provided for @aboutSection.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutSection;

  /// No description provided for @licenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get licenses;

  /// No description provided for @llmPageNote.
  ///
  /// In zh, this message translates to:
  /// **'建档和导演都由它完成：找出说话人，决定每句台词由谁来念、用什么语气。'**
  String get llmPageNote;

  /// No description provided for @connectionSection.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connectionSection;

  /// No description provided for @baseUrl.
  ///
  /// In zh, this message translates to:
  /// **'接口地址'**
  String get baseUrl;

  /// No description provided for @baseUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入以 https:// 或 http:// 开头的地址'**
  String get baseUrlInvalid;

  /// No description provided for @protocol.
  ///
  /// In zh, this message translates to:
  /// **'接口协议'**
  String get protocol;

  /// No description provided for @protocolChatCompletions.
  ///
  /// In zh, this message translates to:
  /// **'Chat Completions'**
  String get protocolChatCompletions;

  /// No description provided for @protocolResponses.
  ///
  /// In zh, this message translates to:
  /// **'Responses'**
  String get protocolResponses;

  /// No description provided for @apiKey.
  ///
  /// In zh, this message translates to:
  /// **'密钥'**
  String get apiKey;

  /// No description provided for @llmConnectionNote.
  ///
  /// In zh, this message translates to:
  /// **'兼容 OpenAI 接口的服务都可以使用，模型需要支持结构化输出（JSON Schema）。'**
  String get llmConnectionNote;

  /// No description provided for @modelsSection.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get modelsSection;

  /// No description provided for @profileModel.
  ///
  /// In zh, this message translates to:
  /// **'建档模型'**
  String get profileModel;

  /// No description provided for @directorModel.
  ///
  /// In zh, this message translates to:
  /// **'导演模型'**
  String get directorModel;

  /// No description provided for @modelHint.
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get modelHint;

  /// No description provided for @sameAsProfileModel.
  ///
  /// In zh, this message translates to:
  /// **'与建档模型相同'**
  String get sameAsProfileModel;

  /// No description provided for @modelsNote.
  ///
  /// In zh, this message translates to:
  /// **'建档模型分析人物、挑选声音；导演模型逐句分配台词和语气，留空则与建档模型相同。'**
  String get modelsNote;

  /// No description provided for @minimaxPageNote.
  ///
  /// In zh, this message translates to:
  /// **'为角色配音，也可以按描述设计新音色。'**
  String get minimaxPageNote;

  /// No description provided for @minimaxKeyNote.
  ///
  /// In zh, this message translates to:
  /// **'使用 MiniMax 国际版（minimax.io）的密钥。'**
  String get minimaxKeyNote;

  /// No description provided for @bailianPageNote.
  ///
  /// In zh, this message translates to:
  /// **'为角色配音。北京地域还可以按描述设计新音色。'**
  String get bailianPageNote;

  /// No description provided for @region.
  ///
  /// In zh, this message translates to:
  /// **'地域'**
  String get region;

  /// No description provided for @regionBeijing.
  ///
  /// In zh, this message translates to:
  /// **'北京'**
  String get regionBeijing;

  /// No description provided for @regionSingapore.
  ///
  /// In zh, this message translates to:
  /// **'新加坡'**
  String get regionSingapore;

  /// No description provided for @bailianRegionNote.
  ///
  /// In zh, this message translates to:
  /// **'北京和新加坡的密钥不通用，请填写所选地域的密钥。'**
  String get bailianRegionNote;

  /// No description provided for @keyHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴或输入密钥'**
  String get keyHint;

  /// No description provided for @newKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴或输入新密钥'**
  String get newKeyHint;

  /// No description provided for @keySaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get keySaved;

  /// No description provided for @pasteKey.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get pasteKey;

  /// No description provided for @showKey.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get showKey;

  /// No description provided for @hideKey.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get hideKey;

  /// No description provided for @replaceKey.
  ///
  /// In zh, this message translates to:
  /// **'更换'**
  String get replaceKey;

  /// No description provided for @deleteKey.
  ///
  /// In zh, this message translates to:
  /// **'删除密钥'**
  String get deleteKey;

  /// No description provided for @deleteKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除这个密钥？'**
  String get deleteKeyTitle;

  /// No description provided for @deleteLlmKeyBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后，建档和导演会暂停，直到重新填写密钥。'**
  String get deleteLlmKeyBody;

  /// No description provided for @deleteVoiceKeyBody.
  ///
  /// In zh, this message translates to:
  /// **'删除后，用这家服务商音色的角色无法生成配音，直到重新填写密钥或换音色。'**
  String get deleteVoiceKeyBody;

  /// No description provided for @keyDeleted.
  ///
  /// In zh, this message translates to:
  /// **'密钥已删除'**
  String get keyDeleted;

  /// No description provided for @keyDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能删除密钥，请再试一次'**
  String get keyDeleteFailed;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能保存'**
  String get saveFailed;

  /// No description provided for @saveFailedBody.
  ///
  /// In zh, this message translates to:
  /// **'设置没有改变。检查填写的内容后再试一次。'**
  String get saveFailedBody;

  /// No description provided for @discardTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃未保存的修改？'**
  String get discardTitle;

  /// No description provided for @discardConfirm.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get discardConfirm;

  /// No description provided for @keepEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get keepEditing;

  /// No description provided for @llmSection.
  ///
  /// In zh, this message translates to:
  /// **'建档与导演'**
  String get llmSection;

  /// No description provided for @voiceSection.
  ///
  /// In zh, this message translates to:
  /// **'配音'**
  String get voiceSection;

  /// No description provided for @voiceSectionNote.
  ///
  /// In zh, this message translates to:
  /// **'生成配音只用开启的服务商。Edge 不支持情绪和读音指令。密钥加密存在本机，只发给对应的服务商。'**
  String get voiceSectionNote;

  /// No description provided for @edgeRole.
  ///
  /// In zh, this message translates to:
  /// **'免费，无需密钥'**
  String get edgeRole;

  /// No description provided for @voiceNeedsKey.
  ///
  /// In zh, this message translates to:
  /// **'填写密钥后才能开启'**
  String get voiceNeedsKey;

  /// No description provided for @noVoiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有开启配音服务商'**
  String get noVoiceTitle;

  /// No description provided for @noVoiceBody.
  ///
  /// In zh, this message translates to:
  /// **'至少开启一家才能生成配音。Microsoft Edge 免费，无需密钥。'**
  String get noVoiceBody;

  /// No description provided for @turnOnEdge.
  ///
  /// In zh, this message translates to:
  /// **'开启 Microsoft Edge'**
  String get turnOnEdge;

  /// No description provided for @reasonProviderDisabled.
  ///
  /// In zh, this message translates to:
  /// **'这家配音服务商已在设置里关闭'**
  String get reasonProviderDisabled;

  /// No description provided for @reasonNoVoiceProvider.
  ///
  /// In zh, this message translates to:
  /// **'还没有开启配音服务商，请到设置里打开一个'**
  String get reasonNoVoiceProvider;

  /// No description provided for @offProviderTitle.
  ///
  /// In zh, this message translates to:
  /// **'{provider}已关闭'**
  String offProviderTitle(String provider);

  /// No description provided for @offProviderNoKeyTitle.
  ///
  /// In zh, this message translates to:
  /// **'{provider}还没有密钥'**
  String offProviderNoKeyTitle(String provider);

  /// No description provided for @offProviderBody.
  ///
  /// In zh, this message translates to:
  /// **'配音要用到{provider}的音色。打开它，或为用到它的角色换上已开启服务商的音色。'**
  String offProviderBody(String provider);

  /// No description provided for @offProviderSpeakers.
  ///
  /// In zh, this message translates to:
  /// **'{names}用的是{provider}的音色。打开它，或为这些角色换上已开启服务商的音色。'**
  String offProviderSpeakers(String names, String provider);

  /// No description provided for @speakersAndMore.
  ///
  /// In zh, this message translates to:
  /// **'{names}等 {total} 位'**
  String speakersAndMore(String names, int total, int more);

  /// No description provided for @turnOnProvider.
  ///
  /// In zh, this message translates to:
  /// **'打开{provider}'**
  String turnOnProvider(String provider);

  /// No description provided for @addProviderKey.
  ///
  /// In zh, this message translates to:
  /// **'填写{provider}的密钥'**
  String addProviderKey(String provider);

  /// No description provided for @rematchVoices.
  ///
  /// In zh, this message translates to:
  /// **'重新匹配音色'**
  String get rematchVoices;

  /// No description provided for @rematchFailed.
  ///
  /// In zh, this message translates to:
  /// **'没能重新匹配音色，请再试一次'**
  String get rematchFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
