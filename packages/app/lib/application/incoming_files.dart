import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Files other apps open in pagestage: "Open in…" on iOS, "Open with" and
/// "Share" on Android.
///
/// The platform copies each file into a private inbox, at
/// `incoming/<id>/<its own name>`, and hands the copy's path over
/// [channel]. It keeps the paths until Dart calls `ready`, so a file that
/// launched the app waits while Flutter starts. `ready` is asked again
/// whenever the app comes back to the front, for anything that could not be
/// handed over before, as when Android started Flutter for playback before
/// any screen.
class IncomingFiles {
  IncomingFiles({this.channel = const MethodChannel('pagestage/incoming')});

  final MethodChannel channel;

  /// Each copy's path once: first those that arrived before anything
  /// listened, then each one as it arrives. Listen only once.
  late final Stream<String> paths = _paths();

  Stream<String> _paths() {
    late final StreamController<String> paths;
    AppLifecycleListener? lifecycle;
    void add(String path) {
      if (!paths.isClosed) paths.add(path);
    }

    Future<void> ready() async {
      try {
        (await channel.invokeListMethod<String>('ready'))?.forEach(add);
      } on MissingPluginException {
        // No platform side yet, or none at all: tests and the gallery.
      } on PlatformException {
        // Nothing that waited can be handed over.
      }
    }

    paths = StreamController(
      onListen: () {
        channel.setMethodCallHandler((call) async {
          // The platform keeps what nobody takes for the next `ready`.
          if (call.method != 'open' || paths.isClosed) {
            throw MissingPluginException();
          }
          if (call.arguments case final String path) add(path);
        });
        lifecycle = AppLifecycleListener(onResume: ready);
        ready();
      },
      onCancel: () {
        lifecycle?.dispose();
        channel.setMethodCallHandler(null);
        return paths.close();
      },
    );
    return paths.stream;
  }

  /// Removes the copy at [path] once it has been imported, or has failed to
  /// be. The library keeps a book's text in its own store and unpacks
  /// packages into app storage, so nothing reads the copy afterwards. Only a
  /// copy inside an inbox is touched.
  void discard(String path) {
    final file = File(path);
    final folder = file.parent;
    if (_name(folder.parent.path) != 'incoming') return;
    try {
      file.deleteSync();
    } on FileSystemException {
      // Never copied, or already gone.
    }
    try {
      folder.deleteSync();
    } on FileSystemException {
      // Not empty, or already gone; the system clears caches in time.
    }
  }
}

String _name(String path) => path.substring(path.lastIndexOf('/') + 1);
