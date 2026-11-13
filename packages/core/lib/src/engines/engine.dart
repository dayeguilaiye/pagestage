import '../provider_configuration.dart';

/// Where an engine runs. A cloud engine receives book text over the
/// network; a device engine keeps everything on the reader's device.
enum EngineLocality { cloud, device }

/// Whether an engine can be used as configured.
enum EngineReadiness {
  ready,

  /// A required setting, such as a key, is missing.
  needsSetup,

  /// Its model has not been installed on this device.
  notInstalled,

  /// Not offered in this build.
  unavailable,
}

enum EngineFieldKind { secret, text, choice }

/// One setting an engine reads from its own section of the
/// [ProviderConfiguration]. Settings screens are built from these, so an
/// engine never needs a screen of its own.
class EngineField {
  const EngineField.secret(this.name, {this.environmentVariable})
    : kind = EngineFieldKind.secret,
      options = const [],
      fallback = null,
      required = true,
      advanced = false;
  const EngineField.text(
    this.name, {
    this.environmentVariable,
    this.fallback,
    this.required = false,
    this.advanced = false,
  }) : kind = EngineFieldKind.text,
       options = const [];
  const EngineField.choice(
    this.name,
    this.options, {
    this.environmentVariable,
    required String this.fallback,
    this.advanced = false,
  }) : kind = EngineFieldKind.choice,
       required = false;

  final String name;
  final EngineFieldKind kind;

  /// Lets the CLI override the stored value; the app never reads it.
  final String? environmentVariable;
  final List<String> options;

  /// The value used while none is stored.
  final String? fallback;
  final bool required;

  /// Kept out of the app's settings; the CLI configuration still reads it.
  final bool advanced;
}

/// What a language or voice engine has in common: an identity, where it
/// runs, what it needs set up, and where it sends book text.
abstract interface class Engine {
  /// Stable identifier; also the name of its configuration section.
  String get id;
  EngineLocality get locality;
  List<EngineField> get fields;
  EngineReadiness readiness(ProviderConfiguration config);

  /// Where book text is sent, for the reader's consent; null when nothing
  /// leaves the device.
  Uri? endpoint(ProviderConfiguration config);
}

/// Reads [field] of [engine]'s section, falling back to its default.
String? engineValue(ProviderConfiguration config, Engine engine, String field) {
  final declared = engine.fields.where((f) => f.name == field).firstOrNull;
  return config.value(
        engine.id,
        field,
        environmentVariable: declared?.environmentVariable,
      ) ??
      declared?.fallback;
}

/// Ready when every required field has a value.
EngineReadiness fieldsReadiness(ProviderConfiguration config, Engine engine) =>
    engine.fields
        .where((field) => field.required)
        .every((field) => engineValue(config, engine, field.name) != null)
    ? EngineReadiness.ready
    : EngineReadiness.needsSetup;
