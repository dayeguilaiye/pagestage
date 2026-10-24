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

  /// No description provided for @chapterUnprofiled.
  ///
  /// In zh, this message translates to:
  /// **'未建档'**
  String get chapterUnprofiled;

  /// No description provided for @chapterUndirected.
  ///
  /// In zh, this message translates to:
  /// **'未导演'**
  String get chapterUndirected;

  /// No description provided for @chapterDirected.
  ///
  /// In zh, this message translates to:
  /// **'已导演'**
  String get chapterDirected;

  /// No description provided for @chapterSynthesized.
  ///
  /// In zh, this message translates to:
  /// **'已合成'**
  String get chapterSynthesized;

  /// No description provided for @chapterWorking.
  ///
  /// In zh, this message translates to:
  /// **'生成中'**
  String get chapterWorking;

  /// No description provided for @chapterFailed.
  ///
  /// In zh, this message translates to:
  /// **'出错'**
  String get chapterFailed;

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
  /// **'导入手机里的 TXT 小说，就可以在这里读和听。'**
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
  /// **'「{file}」不是 TXT 文件'**
  String importUnsupportedTitle(String file);

  /// No description provided for @importUnsupportedBody.
  ///
  /// In zh, this message translates to:
  /// **'目前只能导入 TXT 文本文件，书架没有变化。'**
  String get importUnsupportedBody;

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
  /// **'文件可能损坏了，或者不是 UTF-8、GBK 编码。书架没有变化。'**
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
