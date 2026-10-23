import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pcm_audio.dart';
import '../pronunciation.dart';
import '../models/voice.dart';
import 'provider_exception.dart';
import 'tts_errors.dart';
import 'tts_adapter.dart';
import 'voice_design_adapter.dart';
import 'voice_design_http.dart';

enum BailianRegion { beijing, singapore }

class BailianTtsAdapter implements TtsAdapter, VoiceDesignAdapter {
  BailianTtsAdapter({
    required String apiKey,
    this.region = BailianRegion.beijing,
    this.requestCharacterLimit = 600,
    Uri? baseUrl,
    http.Client? client,
  }) : _apiKey = apiKey,
       _baseUrl =
           baseUrl ??
           Uri.parse(
             region == BailianRegion.beijing
                 ? 'https://dashscope.aliyuncs.com/api/v1'
                 : 'https://dashscope-intl.aliyuncs.com/api/v1',
           ),
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (requestCharacterLimit < 1 ||
        apiKey.trim().isEmpty ||
        !['http', 'https'].contains(_baseUrl.scheme) ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
  }
  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final BailianRegion region;
  final int requestCharacterLimit;
  @override
  String get provider => 'bailian';

  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    const models = {
      'qwen-audio-3.1-tts-flash',
      'qwen-audio-3.1-tts-plus',
      'qwen-audio-3.0-tts-flash',
      'qwen-audio-3.0-tts-plus',
    };
    if (binding.provider != provider ||
        !models.contains(binding.model) ||
        (binding.designed && region != BailianRegion.beijing)) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return TtsCapabilities(
      supportsVoiceDesign: region == BailianRegion.beijing,
      emotionControl: EmotionControl.instruction,
      supportsPronunciation:
          binding.model.startsWith('qwen-audio-3.1-') &&
          !binding.designed &&
          binding.voiceId.endsWith('_v3.1'),
      returnsTimestamps: false,
      maxCharacters: requestCharacterLimit,
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    final capabilities = capabilitiesFor(request.binding);
    if (request.text.trim().isEmpty ||
        request.text.runes.length > capabilities.maxCharacters) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    final matches = pronunciationMatches(
      request.text,
      request.language == 'zh' && capabilities.supportsPronunciation
          ? request.pronunciations
          : [],
    );
    final endpoint = _baseUrl.replace(
      path:
          '${_baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/services/audio/tts/SpeechSynthesizer',
    );
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': request.binding.model,
              'input': {
                'text': matches.isEmpty
                    ? request.text
                    : pronunciationSsml(request.text, matches),
                if (matches.isNotEmpty) 'enable_ssml': true,
                if (request.instruction != null)
                  'instruction': request.instruction,
                'voice': request.binding.voiceId,
                'format': 'wav',
                'sample_rate': 24000,
                'language_hints': [request.language],
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
      final transportError = ttsHttpError(response.statusCode);
      if (transportError != null) {
        throw ProviderException(provider: provider, kind: transportError);
      }
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final code = json['code'];
      if (response.statusCode != 200 || code != null) {
        final kind = ttsErrorCode(
          provider,
          code,
          statusCode: response.statusCode,
        );
        throw ProviderException(provider: provider, kind: kind);
      }
      final output = json['output'] as Map;
      if (output['finish_reason'] != 'stop') {
        throw const FormatException('Incomplete audio.');
      }
      final url = Uri.tryParse((output['audio'] as Map)['url'] as String);
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        throw const FormatException('Invalid audio URL.');
      }
      // The signed download URL is a separate service and receives no API key.
      final audioResponse = await _client
          .get(url)
          .timeout(const Duration(seconds: 90));
      if (audioResponse.statusCode != 200) {
        throw const FormatException('Audio download failed.');
      }
      final audio = PcmAudio.fromWav(audioResponse.bodyBytes);
      if (audio.samples.isEmpty) throw const FormatException('Empty audio.');
      final usage = json['usage'] as Map? ?? {};
      int? count(String field) {
        final value = usage[field];
        if (value == null) return null;
        if (value is! int || value < 0) {
          throw const FormatException('Invalid usage.');
        }
        return value;
      }

      return TtsAudio(
        audio: audio,
        characters: count('characters'),
        inputTokens: count('input_tokens'),
        outputTokens: count('output_tokens'),
        totalTokens: count('total_tokens'),
      );
    } on TimeoutException {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.unavailable,
      );
    } on http.ClientException {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.unavailable,
      );
    } on FormatException {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidResponse,
      );
    } on TypeError {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidResponse,
      );
    }
  }

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) async {
    final binding = VoiceBinding(
      provider: provider,
      model: request.model,
      voiceId: '',
      designed: true,
    );
    if (!capabilitiesFor(binding).supportsVoiceDesign ||
        _baseUrl.host == 'dashscope-intl.aliyuncs.com' ||
        _baseUrl.host.contains('.ap-southeast-')) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return designBailian(
      request,
      apiKey: _apiKey,
      baseUrl: _baseUrl,
      client: _client,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
