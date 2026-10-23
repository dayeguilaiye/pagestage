import 'dart:convert';
import 'dart:io';

/// Reads local provider settings with explicit environment overrides.
/// It intentionally has no JSON/logging representation containing credentials.
class ProviderConfiguration {
  ProviderConfiguration._(this._sections, this._environment);
  final Map<String, Object?> _sections;
  final Map<String, String> _environment;

  static Future<ProviderConfiguration> load(
    String? path, {
    Map<String, String>? environment,
  }) async {
    Map<String, Object?> sections = {};
    if (path != null) {
      try {
        final value = jsonDecode(await File(path).readAsString());
        if (value is! Map<String, dynamic>) throw const FormatException();
        sections = Map<String, Object?>.from(value);
      } on FormatException {
        throw const FormatException(
          'The provider configuration must be a valid JSON object.',
        );
      }
    }
    return ProviderConfiguration._(
      sections,
      Map.unmodifiable(environment ?? Platform.environment),
    );
  }

  String? value(String section, String field, {String? environmentVariable}) {
    final override = environmentVariable == null
        ? null
        : _environment[environmentVariable];
    if (override != null && override.trim().isNotEmpty) return override.trim();
    final values = _sections[section];
    if (values == null) return null;
    if (values is! Map) {
      throw const FormatException('Provider settings must be JSON objects.');
    }
    final value = values[field];
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Provider settings must be strings.');
    }
    return value.trim().isEmpty ? null : value.trim();
  }
}
