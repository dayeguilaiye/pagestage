/// A provider-specific implementation of a voice. Contains no credentials.
class VoiceBinding {
  const VoiceBinding({
    required this.provider,
    required this.model,
    required this.voiceId,
    this.parameters = const {},
  });
  final String provider;
  final String model;
  final String voiceId;
  final Map<String, Object?> parameters;
  Map<String, Object?> toJson() => {
    'provider': provider,
    'model': model,
    'voiceId': voiceId,
    'parameters': parameters,
  };
  factory VoiceBinding.fromJson(Map<String, Object?> json) => VoiceBinding(
    provider: json['provider'] as String,
    model: json['model'] as String,
    voiceId: json['voiceId'] as String,
    parameters: Map<String, Object?>.from(json['parameters'] as Map),
  );
}
