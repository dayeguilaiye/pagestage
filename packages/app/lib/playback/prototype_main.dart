import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'chapter_player.dart';
import 'just_audio_engine.dart';
import 'playback_handler.dart';
import 'prototype_fixture.dart';
import 'prototype_page.dart';
import 'soloud_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlaybackFixture? fixture;
  ChapterPlayer? player;
  try {
    fixture = await PlaybackFixture.load();
  } on Exception {
    // A developer can install the fixture into the app container, then rerun.
  }
  if (fixture != null) {
    const engine = String.fromEnvironment(
      'PLAYBACK_ENGINE',
      defaultValue: 'just_audio',
    );
    player = ChapterPlayer(
      engine == 'soloud' ? SoloudEngine() : JustAudioEngine(),
      fixture.queue,
    );
    await (await AudioSession.instance).configure(
      const AudioSessionConfiguration.speech(),
    );
    await player.load(fixture.path);
    final current = player;
    final data = fixture;
    await AudioService.init(
      builder: () => PlaybackHandler(
        current,
        bookId: data.script.bookId,
        title: data.title,
        chapterTitle: data.chapter.title,
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'pagestage.playback',
        androidNotificationChannelName: 'pagestage',
        androidNotificationOngoing: true,
      ),
    );
  }
  final currentPlayer = player;
  final data = fixture;
  runApp(
    MaterialApp(
      theme: PsTheme.light,
      darkTheme: PsTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: PagestageApp.locales,
      localeListResolutionCallback: PagestageApp.resolveLocale,
      home: currentPlayer != null && data != null
          ? PlaybackPrototypePage(
              player: currentPlayer,
              chapter: data.chapter,
              script: data.script,
              title: data.title,
            )
          : Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: Text(
                    AppLocalizations.of(context).playbackFixtureMissing,
                  ),
                ),
              ),
            ),
    ),
  );
}
