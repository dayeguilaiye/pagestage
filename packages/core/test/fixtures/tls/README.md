# Local TLS test fixture

`test-cert.pem` is a self-signed certificate for `metadata.invalid`. Its matching
`test-key.pem` is a public, test-only private key, with no provider credentials or
production use. Transport tests trust this certificate explicitly and verify
that both an untrusted certificate and a hostname mismatch block HTTP requests.

The certificate expires on 2027-10-24. Regenerate it before expiry; a one-year
validity keeps the fixture compatible with macOS certificate verification.

Regenerate from the repository root with:

```sh
openssl req -x509 -newkey rsa:2048 -nodes -keyout packages/core/test/fixtures/tls/test-key.pem -out packages/core/test/fixtures/tls/test-cert.pem -days 365 -subj '/CN=metadata.invalid' -addext 'subjectAltName=DNS:metadata.invalid' -addext 'basicConstraints=critical,CA:FALSE' -addext 'extendedKeyUsage=serverAuth' -addext 'keyUsage=critical,digitalSignature,keyEncipherment'
```
