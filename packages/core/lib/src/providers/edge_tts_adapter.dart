import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_decode/audio_decode.dart' as codec;

import '../models/voice.dart';
import '../pcm_audio.dart';
import 'edge_gec.dart';
import 'provider_exception.dart';
import 'tts_adapter.dart';
import 'usage_ledger.dart';

/// Edge Read Aloud's private WebSocket protocol, based on
/// https://github.com/dayeguilaiye/tts-api/blob/main/internal/edge/client.go.
/// A request contains one voice and one prosody element. Direction and
/// pronunciation instructions are intentionally not sent to this service.
class EdgeTtsAdapter implements TtsAdapter {
  EdgeTtsAdapter({
    Uri? endpoint,
    this.timeout = const Duration(seconds: 90),
    DateTime Function()? clock,
    UsageLedger? usageLedger,
  }) : _endpoint = endpoint ?? Uri.parse(defaultEndpoint),
       _clock = clock ?? DateTime.now,
       _usageLedger = usageLedger {
    if (!['ws', 'wss'].contains(_endpoint.scheme) ||
        _endpoint.host.isEmpty ||
        _endpoint.userInfo.isNotEmpty ||
        _endpoint.hasQuery ||
        _endpoint.hasFragment ||
        timeout <= Duration.zero) {
      throw _error(ProviderErrorKind.invalidConfiguration);
    }
  }

  static const defaultEndpoint =
      'wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1';
  static const model = 'edge-read-aloud';
  static const _token = edgeTrustedClientToken;
  static const _version = '143.0.3650.75';
  final Uri _endpoint;
  final Duration timeout;
  final DateTime Function() _clock;
  final UsageLedger? _usageLedger;
  final _clients = <HttpClient>{};
  final _sockets = <WebSocket>{};
  bool _closed = false;

  @override
  String get provider => 'edge';

  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    if (binding.provider != provider ||
        binding.model != model ||
        binding.designed ||
        !RegExp(
          r'^[a-z]{2,3}-[A-Z]{2}(?:-[A-Za-z0-9]+)+Neural$',
        ).hasMatch(binding.voiceId)) {
      throw _error(ProviderErrorKind.invalidConfiguration);
    }
    // Even six-byte XML escapes fit within the reference client's 4096-byte
    // text budget. Synthesizer splits long utterances without losing text.
    return const TtsCapabilities(
      supportsPronunciation: false,
      maxCharacters: 600,
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    final capabilities = capabilitiesFor(request.binding);
    final text = request.text.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'),
      ' ',
    );
    if (_closed ||
        text.trim().isEmpty ||
        request.text.runes.length > capabilities.maxCharacters) {
      throw _error(ProviderErrorKind.invalidConfiguration);
    }
    final parameters = request.binding.parameters;
    String prosody(String name, String fallback, String unit) {
      final value = parameters[name] ?? fallback;
      if (value is! String || !RegExp('^[+-][0-9]+$unit\$').hasMatch(value)) {
        throw _error(ProviderErrorKind.invalidConfiguration);
      }
      return value;
    }

    final rate = prosody('rate', '+0%', '%');
    final volume = prosody('volume', '+0%', '%');
    final pitch = prosody('pitch', '+0Hz', 'Hz');
    final ssml =
        '<speak version="1.0" '
        'xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">'
        '<voice name="${_escape(_voiceName(request.binding.voiceId))}">'
        '<prosody pitch="$pitch" rate="$rate" volume="$volume">'
        '${_escape(text)}</prosody></voice></speak>';
    // WebSocket.connect adds the supplied headers to HttpClient's defaults.
    // Clear Dart's default agent so Edge receives exactly one browser agent.
    final client = HttpClient()
      ..userAgent = null
      ..connectionTimeout = timeout;
    _clients.add(client);
    WebSocket? socket;
    try {
      final now = _clock().toUtc();
      final connectionId = _randomId();
      final uri = _endpoint.replace(
        queryParameters: {
          'TrustedClientToken': _token,
          'ConnectionId': connectionId,
          'Sec-MS-GEC': edgeSecMsGec(now),
          'Sec-MS-GEC-Version': '2-$_version',
        },
      );
      // The total deadline also closes a stalled handshake or audio stream.
      final mp3 = await (() async {
        final connected = await WebSocket.connect(
          uri.toString(),
          customClient: client,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0',
            'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
            'Accept-Language': 'en-US,en;q=0.9',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache',
            'Cookie': 'muid=${_randomId()};',
          },
        );
        socket = connected;
        if (_closed || !_clients.contains(client)) {
          unawaited(connected.close());
          throw _error(ProviderErrorKind.unavailable);
        }
        _sockets.add(connected);
        final timestamp = _timestamp(now);
        connected.add(
          'X-Timestamp:$timestamp\r\n'
          'Content-Type:application/json; charset=utf-8\r\n'
          'Path:speech.config\r\n\r\n'
          '{"context":{"synthesis":{"audio":{"metadataoptions":'
          '{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},'
          '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}\r\n',
        );
        connected.add(
          'X-RequestId:$connectionId\r\n'
          'Content-Type:application/ssml+xml\r\n'
          'X-Timestamp:${timestamp}Z\r\nPath:ssml\r\n\r\n$ssml',
        );
        return _receive(connected);
      })().timeout(timeout);
      final audio = await _decodeAsync(mp3);
      _usageLedger?.record(
        UsageRecord(
          provider: provider,
          endpoint: _endpoint.toString(),
          model: model,
          requestId: connectionId,
          usage: const {}, // Edge reports no billing or token usage.
        ),
      );
      return TtsAudio(audio: audio);
    } on TimeoutException {
      throw _error(ProviderErrorKind.unavailable, code: 'timeout');
    } on SocketException {
      throw _error(ProviderErrorKind.unavailable, code: 'connection_error');
    } on HandshakeException {
      throw _error(ProviderErrorKind.unavailable, code: 'tls_handshake');
    } on HttpException {
      throw _error(ProviderErrorKind.unavailable, code: 'http_error');
    } on WebSocketException catch (error) {
      throw _error(
        error.httpStatusCode == 429
            ? ProviderErrorKind.rateLimited
            : ProviderErrorKind.unavailable,
        code: error.httpStatusCode == null
            ? 'websocket_error'
            : 'http_${error.httpStatusCode}',
      );
    } on FormatException {
      throw _error(ProviderErrorKind.invalidResponse);
    } finally {
      if (socket != null) {
        _sockets.remove(socket);
        unawaited(socket!.close());
      }
      _clients.remove(client);
      client.close(force: true);
    }
  }

  Future<Uint8List> _receive(WebSocket socket) async {
    final audio = BytesBuilder(copy: false);
    await for (final frame in socket) {
      if (frame is String) {
        final headers = _headers(frame.split('\r\n\r\n').first);
        if (headers['Path'] == 'turn.end') {
          if (audio.isEmpty) throw const FormatException('Empty audio.');
          return audio.takeBytes();
        }
        if (![
          'turn.start',
          'response',
          'audio.metadata',
        ].contains(headers['Path'])) {
          throw const FormatException('Unexpected Edge message.');
        }
      } else if (frame is List<int>) {
        if (frame.length < 2) {
          throw const FormatException('Missing frame header.');
        }
        final end = 2 + (frame[0] << 8) + frame[1];
        if (end > frame.length) throw const FormatException('Truncated frame.');
        final headers = _headers(utf8.decode(frame.sublist(2, end)));
        if (headers['Path'] != 'audio' ||
            (end < frame.length && headers['Content-Type'] != 'audio/mpeg')) {
          throw const FormatException('Unexpected audio format.');
        }
        audio.add(frame.sublist(end));
        if (audio.length > 16 * 1024 * 1024) {
          throw const FormatException('Audio exceeds request budget.');
        }
      } else {
        throw const FormatException('Unexpected frame.');
      }
    }
    // Do not cache partial audio when the connection closes before turn.end.
    throw _error(ProviderErrorKind.unavailable, code: 'interrupted_stream');
  }

  void close() {
    _closed = true;
    for (final socket in _sockets) {
      unawaited(socket.close());
    }
    for (final client in _clients) {
      client.close(force: true);
    }
    _sockets.clear();
    _clients.clear();
  }
}

ProviderException _error(ProviderErrorKind kind, {String? code}) =>
    ProviderException(provider: 'edge', kind: kind, code: code);

// Keep the isolate closure outside the request scope so it captures only bytes,
// never the active WebSocket or HttpClient.
Future<PcmAudio> _decodeAsync(Uint8List bytes) =>
    Isolate.run(() => _decode(bytes));

PcmAudio _decode(Uint8List bytes) {
  try {
    final decoded = codec.toSpeechPcm(
      codec.decodeMp3(bytes),
      sampleRate: 24000,
    );
    if (decoded.samples.isEmpty) throw const FormatException('Empty MP3.');
    return PcmAudio(samples: decoded.samples);
  } on codec.AudioDecodeException {
    throw const FormatException('Invalid MP3.');
  }
}

Map<String, String> _headers(String text) => {
  for (final line in text.split('\r\n'))
    if (line.indexOf(':') case final index when index > 0)
      line.substring(0, index): line.substring(index + 1).trim(),
};

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _voiceName(String shortName) {
  final parts = shortName.split('-');
  return 'Microsoft Server Speech Text to Speech Voice '
      '(${parts.take(parts.length - 1).join('-')}, ${parts.last})';
}

String _randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join().toUpperCase();
}

String _timestamp(DateTime now) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${days[now.weekday - 1]} ${months[now.month - 1]} ${pad(now.day)} '
      '${now.year} ${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)} '
      'GMT+0000 (Coordinated Universal Time)';
}
