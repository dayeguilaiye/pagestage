/// A provider-specific implementation of a voice. Contains no credentials.
class VoiceBinding {
  const VoiceBinding({
    required this.provider,
    required this.model,
    required this.voiceId,
    this.parameters = const {},
    this.designed = false,
  });
  final String provider;
  final String model;
  final String voiceId;
  final bool designed;
  final Map<String, Object?> parameters;
  Map<String, Object?> toJson() => {
    'provider': provider,
    'model': model,
    'voiceId': voiceId,
    'parameters': parameters,
    'designed': designed,
  };
  factory VoiceBinding.fromJson(Map<String, Object?> json) => VoiceBinding(
    provider: json['provider'] as String,
    model: json['model'] as String,
    voiceId: json['voiceId'] as String,
    designed: json['designed'] as bool? ?? false,
    parameters: Map<String, Object?>.from(json['parameters'] as Map),
  );
}

/// A stable, provider-independent voice selected for a book.
/// The cast owns the reference, so character merges can retain this record.
class Voice {
  const Voice({
    required this.id,
    required this.bookId,
    required this.description,
    required this.binding,
    this.samplePath,
    this.manuallySelected = false,
    this.inheritedFromPersonaId,
  });
  final String id;
  final String bookId;
  final String description;
  final VoiceBinding binding;
  final String? samplePath;
  final bool manuallySelected;
  final String? inheritedFromPersonaId;

  Voice copyWith({
    String? description,
    VoiceBinding? binding,
    String? samplePath,
    bool? manuallySelected,
  }) => Voice(
    id: id,
    bookId: bookId,
    description: description ?? this.description,
    binding: binding ?? this.binding,
    samplePath: samplePath ?? this.samplePath,
    manuallySelected: manuallySelected ?? this.manuallySelected,
    inheritedFromPersonaId: inheritedFromPersonaId,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'bookId': bookId,
    'description': description,
    'binding': binding.toJson(),
    'samplePath': samplePath,
    'manuallySelected': manuallySelected,
    'inheritedFromPersonaId': inheritedFromPersonaId,
  };
  factory Voice.fromJson(Map<String, Object?> json) => Voice(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    description: json['description'] as String,
    binding: VoiceBinding.fromJson(
      Map<String, Object?>.from(json['binding'] as Map),
    ),
    samplePath: json['samplePath'] as String?,
    manuallySelected: json['manuallySelected'] as bool? ?? false,
    inheritedFromPersonaId: json['inheritedFromPersonaId'] as String?,
  );
}
