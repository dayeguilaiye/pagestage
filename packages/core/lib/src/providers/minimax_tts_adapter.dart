import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pcm_audio.dart';
import '../pronunciation.dart';
import '../models/voice.dart';
import 'hex_audio.dart';
import 'provider_exception.dart';
import 'tts_http.dart';
import 'tts_adapter.dart';
import 'voice_design_adapter.dart';

class MiniMaxTtsAdapter implements TtsAdapter, VoiceDesignAdapter {
  MiniMaxTtsAdapter({required String apiKey, Uri? baseUrl, http.Client? client})
    : _apiKey = apiKey,
      _baseUrl = baseUrl ?? Uri.parse('https://api.minimax.io/v1'),
      _client = client ?? http.Client(),
      _ownsClient = client == null {
    if (apiKey.trim().isEmpty ||
        !['http', 'https'].contains(_baseUrl.scheme) ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
  }
  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  @override
  String get provider => 'minimax';

  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    if (binding.provider != provider) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return const TtsCapabilities(
      supportsPronunciation: true,
      maxCharacters: 9999,
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    final capabilities = capabilitiesFor(request.binding);
    if (request.text.trim().isEmpty ||
        request.text.runes.length > capabilities.maxCharacters) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    final pronunciations = matchedPronunciations(
      pronunciationMatches(
        request.text,
        request.language == 'zh' ? request.pronunciations : [],
      ),
    );
    return withTtsErrors(provider, () async {
      final json = await _post('t2a_v2', {
        'model': request.binding.model,
        'text': request.text,
        if (pronunciations.isNotEmpty)
          'pronunciation_dict': {
            'tone': [
              for (final entry in pronunciations)
                '${entry.term}/${entry.pinyin.split(' ').map((s) => '($s)').join()}',
            ],
          },
        'stream': false,
        'output_format': 'hex',
        'language_boost': request.language == 'zh' ? 'Chinese' : 'English',
        'voice_setting': {
          'voice_id': request.binding.voiceId,
          'speed': 1,
          'vol': 1,
          'pitch': 0,
          'emotion': request.direction.emotion.name,
        },
        'audio_setting': {'sample_rate': 24000, 'format': 'wav', 'channel': 1},
      });
      final data = json['data'] as Map;
      if (data['status'] != 2) throw const FormatException('Incomplete audio.');
      final hex = data['audio'] as String;
      final audio = PcmAudio.fromWav(decodeHexAudio(hex));
      if (audio.samples.isEmpty) throw const FormatException('Empty audio.');
      final characters = (json['extra_info'] as Map)['usage_characters'] as int;
      if (characters < 0) throw const FormatException('Invalid usage.');
      return TtsAudio(audio: audio, characters: characters);
    });
  }

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) async {
    if (request.description.trim().isEmpty ||
        request.previewText.trim().isEmpty ||
        request.previewText.runes.length > 500 ||
        request.model.trim().isEmpty ||
        !['zh', 'en'].contains(request.language)) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return withTtsErrors(provider, () async {
      final json = await _post('voice_design', {
        'prompt': request.description,
        'preview_text': request.previewText,
      }, timeout: const Duration(seconds: 120));
      final voiceId = json['voice_id'] as String;
      final hex = json['trial_audio'] as String;
      if (voiceId.trim().isEmpty) {
        throw const FormatException('Invalid design response.');
      }
      return DesignedVoice(
        binding: VoiceBinding(
          provider: provider,
          model: request.model,
          voiceId: voiceId,
          designed: true,
        ),
        preview: VoicePreview.detect(decodeHexAudio(hex)),
      );
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final response = await _client
        .post(
          _baseUrl.replace(
            path: '${_baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/$path',
          ),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final transportError = ttsHttpError(response.statusCode);
    if (transportError != null) {
      throw ProviderException(provider: provider, kind: transportError);
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final status = (json['base_resp'] as Map)['status_code'];
    if (response.statusCode != 200 || status != 0) {
      throw ProviderException(
        provider: provider,
        kind: _errorKind(status, response.statusCode),
        code: status is int ? status.toString() : null,
      );
    }
    return json;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

ProviderErrorKind _errorKind(Object? code, int statusCode) => switch (code) {
  1004 || 2049 => ProviderErrorKind.invalidKey,
  1008 || 2053 => ProviderErrorKind.insufficientBalance,
  1002 || 1039 || 1045 => ProviderErrorKind.rateLimited,
  1000 || 1001 || 1024 || 1033 => ProviderErrorKind.unavailable,
  20132 || 2042 || 2043 || 2054 => ProviderErrorKind.invalidVoice,
  _ =>
    statusCode == 403
        ? ProviderErrorKind.invalidConfiguration
        : ProviderErrorKind.invalidResponse,
};
