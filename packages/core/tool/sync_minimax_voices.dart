import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pagestage_core/src/provider_configuration.dart';

/// One explicit metadata request, without synthesis, retries or key logging.
Future<void> main(List<String> arguments) async {
  exitCode = await syncMiniMaxVoices(arguments);
}

Future<int> syncMiniMaxVoices(
  List<String> arguments, {
  http.Client? httpClient,
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final parser = ArgParser()
    ..addOption('config', mandatory: true)
    ..addOption(
      'connect-address',
      help:
          'Use a DNS-resolved IP for this request, retaining TLS hostname verification.',
    )
    ..addOption('output', defaultsTo: '.pagestage/minimax-system-voices.json');
  http.Client? client;
  var requests = 0;
  try {
    final args = parser.parse(arguments);
    final config = await ProviderConfiguration.load(
      args['config'] as String,
      environment: const {},
    );
    final key = config.value('minimax', 'key');
    final base = Uri.parse(
      config.value('minimax', 'baseUrl') ?? 'https://api.minimax.io/v1',
    );
    if (key == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const FormatException();
    }
    final uri = base.replace(
      path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/get_voice',
    );
    final addressText = args['connect-address'] as String?;
    final address = addressText == null
        ? null
        : InternetAddress.tryParse(addressText);
    if (addressText != null && address == null) throw const FormatException();
    client = httpClient ?? metadataClient(uri, address: address);
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({'voice_type': 'system'});
    requests++;
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
      throw _SyncFailure('HTTP ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map;
    final code = (json['base_resp'] as Map)['status_code'] as int;
    if (code != 0) {
      throw _SyncFailure('provider status $code');
    }
    final voices = (json['system_voice'] as List).map((value) {
      final voice = value as Map;
      return {
        'voice_id': voice['voice_id'] as String,
        'voice_name': voice['voice_name'] as String,
        'description': (voice['description'] as List).cast<String>(),
      };
    }).toList();
    if (voices.isEmpty) throw const FormatException();
    final docsHost =
        base.host.endsWith('minimax.cn') || base.host.endsWith('minimaxi.com')
        ? 'platform.minimax.cn'
        : 'platform.minimax.io';
    final sourceUrl =
        'https://$docsHost/docs/api-reference/voice-management-get';
    final file = File(args['output'] as String);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({'sourceUrl': sourceUrl, 'retrievedAt': DateTime.now().toUtc().toIso8601String(), 'system_voice': voices})}\n',
    );
    (output ?? stdout).writeln(
      'Saved ${voices.length} system voices. Requests: 1; synthesis: 0; '
      'usage: ${json['usage'] == null ? 'not reported by provider' : 'reported by provider'}.',
    );
    return 0;
  } catch (error) {
    // Never print raw exceptions: network errors may include credentials.
    final reason = switch (error) {
      _SyncFailure() => error.reason,
      TimeoutException() => 'request timed out after 45 seconds',
      HandshakeException() =>
        'TLS handshake or certificate verification failed',
      SocketException() || http.ClientException() => 'connection failed',
      FileSystemException() => 'local file access failed',
      FormatException() || TypeError() => 'invalid configuration or metadata',
      _ => 'unexpected local failure',
    };
    (errorOutput ?? stderr).writeln(
      'Voice metadata sync failed ($reason). Request attempts: $requests; '
      'no retry was attempted. Provider usage unavailable.',
    );
    return 1;
  } finally {
    (client ?? httpClient)?.close();
  }
}

http.Client metadataClient(
  Uri endpoint, {
  InternetAddress? address,
  SecurityContext? securityContext,
}) {
  if (endpoint.scheme != 'https') throw const FormatException();
  final transport = HttpClient(context: securityContext);
  if (address != null) {
    transport.connectionFactory = (target, proxyHost, proxyPort) async {
      if (target.scheme != 'https' ||
          target.host != endpoint.host ||
          target.port != endpoint.port ||
          proxyHost != null) {
        throw const FormatException();
      }
      final connection = await Socket.startConnect(address, target.port);
      // A custom connectionFactory must supply the TLS socket itself.
      // The original hostname controls SNI and certificate verification.
      return ConnectionTask.fromSocket(
        connection.socket.then(
          (socket) => SecureSocket.secure(
            socket,
            host: target.host,
            context: securityContext,
          ),
        ),
        connection.cancel,
      );
    };
  }
  return IOClient(transport);
}

class _SyncFailure implements Exception {
  const _SyncFailure(this.reason);
  final String reason;
}
