import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/sync_minimax_voices.dart';

void main() {
  test('explicit address sends TLS before any HTTP credentials', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final endpoint = Uri.parse(
      'https://metadata.invalid:${server.port}/get_voice',
    );
    final client = metadataClient(
      endpoint,
      address: InternetAddress.loopbackIPv4,
    );
    addTearDown(client.close);
    final received = server.first.then((socket) async {
      try {
        return await socket.first;
      } finally {
        socket.destroy();
      }
    });
    final request = expectLater(
      client.get(endpoint, headers: {'Authorization': 'Bearer test-secret'}),
      throwsA(isA<HandshakeException>()),
    );
    final bytes = await received;
    await request;
    expect(
      bytes.first,
      0x16,
      reason: 'The first record must be a TLS handshake',
    );
    expect(latin1.decode(bytes), isNot(contains('test-secret')));
  });

  test(
    'explicit address retains HTTPS hostname and validates its certificate',
    () async {
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext(),
      );
      addTearDown(() => server.close(force: true));
      final endpoint = Uri.parse(
        'https://metadata.invalid:${server.port}/get_voice',
      );
      final client = metadataClient(
        endpoint,
        address: InternetAddress.loopbackIPv4,
        securityContext: trustedContext(),
      );
      addTearDown(client.close);
      final served = server.first.then((request) async {
        expect(
          request.headers.value(HttpHeaders.hostHeader),
          endpoint.authority,
        );
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-secret',
        );
        request.response.write('metadata');
        await request.response.close();
      });
      expect(
        (await client.get(
          endpoint,
          headers: {'Authorization': 'Bearer test-secret'},
        )).body,
        'metadata',
      );
      await served;
      await expectLater(
        client.get(endpoint.replace(host: 'another.invalid')),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        client.get(endpoint.replace(scheme: 'http')),
        throwsA(isA<FormatException>()),
      );
    },
  );

  for (final invalidCertificate in ['untrusted', 'wrong hostname']) {
    test('explicit address rejects $invalidCertificate before HTTP', () async {
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext(),
      );
      addTearDown(() => server.close(force: true));
      var requests = 0;
      server.listen((request) {
        requests++;
        request.response.close();
      }, onError: (Object _) {});
      final hostname = invalidCertificate == 'wrong hostname'
          ? 'another.invalid'
          : 'metadata.invalid';
      final endpoint = Uri.parse('https://$hostname:${server.port}/get_voice');
      final client = metadataClient(
        endpoint,
        address: InternetAddress.loopbackIPv4,
        securityContext: invalidCertificate == 'wrong hostname'
            ? trustedContext()
            : SecurityContext(),
      );
      addTearDown(client.close);
      await expectLater(
        client.get(endpoint, headers: {'Authorization': 'Bearer test-secret'}),
        throwsA(isA<HandshakeException>()),
      );
      expect(requests, 0);
    });
  }

  test('metadata transport rejects plaintext endpoints', () {
    expect(
      () => metadataClient(Uri.parse('http://metadata.invalid')),
      throwsA(isA<FormatException>()),
    );
  });
}

SecurityContext serverContext() => SecurityContext()
  ..useCertificateChain('$tlsFixtureDirectory/test-cert.pem')
  ..usePrivateKey('$tlsFixtureDirectory/test-key.pem');

SecurityContext trustedContext() =>
    SecurityContext()
      ..setTrustedCertificates('$tlsFixtureDirectory/test-cert.pem');

final tlsFixtureDirectory = Directory('test/fixtures/tls').existsSync()
    ? 'test/fixtures/tls'
    : 'packages/core/test/fixtures/tls';
