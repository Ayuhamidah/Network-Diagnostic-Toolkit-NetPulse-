import 'dart:async';
import 'dart:io';

import '../core/network_exceptions.dart';
import '../models/http_check_models.dart';

/// Abstraksi eksekutor HTTP agar layanan dapat diuji secara deterministik di unit test.
typedef HttpProbeTransport = Future<HttpCheckResult> Function({
  required Uri uri,
  required HttpCheckMethod method,
  required Duration timeout,
});

/// Layanan untuk memeriksa status kode HTTP (`2xx`, `3xx`, `4xx`, `5xx`),
/// waktu respons server (*latency*), serta header respons.
class HttpCheckerService {
  final HttpProbeTransport? _customTransport;

  const HttpCheckerService({HttpProbeTransport? customTransport})
      : _customTransport = customTransport;

  /// Menormalkan input URL pengguna (menambahkan `https://` jika belum memiliki skema).
  Uri normalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw const NetworkDiagnosticError(
        type: NetworkErrorType.invalidInput,
        title: 'URL Kosong',
        message: 'Masukkan alamat URL atau IP server yang ingin diperiksa.',
        technicalDetail: 'Empty URL input',
        troubleshootingHint: 'Contoh: https://cloudflare.com atau http://192.168.88.1',
      );
    }

    final withScheme = (trimmed.startsWith('http://') ||
            trimmed.startsWith('https://'))
        ? trimmed
        : 'https://$trimmed';

    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      throw NetworkDiagnosticError(
        type: NetworkErrorType.invalidInput,
        title: 'Format URL Tidak Valid',
        message: 'URL "$rawUrl" tidak memiliki host yang valid.',
        technicalDetail: 'Invalid URI host in $withScheme',
        troubleshootingHint:
            'Pastikan penulisan nama domain atau alamat IP sudah benar (contoh: https://api.github.com).',
      );
    }

    return uri;
  }

  /// Melakukan pengecekan HTTP ke [rawUrl] dengan batas waktu [timeout].
  /// Mengembalikan [HttpCheckResult] yang berisi kode status atau detail error diagnostik.
  Future<HttpCheckResult> checkServerStatus(
    String rawUrl, {
    HttpCheckMethod method = HttpCheckMethod.head,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final Uri uri = normalizeUrl(rawUrl);
    final transport = _customTransport ?? _defaultHttpTransport;

    final stopwatch = Stopwatch()..start();
    try {
      return await transport(
        uri: uri,
        method: method,
        timeout: timeout,
      );
    } catch (e) {
      stopwatch.stop();
      final diagnosticError = NetworkDiagnosticError.fromException(
        e,
        target: uri.host,
        timeout: timeout,
      );
      return HttpCheckResult(
        url: uri.toString(),
        method: method,
        category: HttpStatusCategory.unknown,
        responseTimeMs: stopwatch.elapsedMilliseconds,
        checkedAt: DateTime.now(),
        error: diagnosticError,
      );
    }
  }

  static Future<HttpCheckResult> _defaultHttpTransport({
    required Uri uri,
    required HttpCheckMethod method,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final stopwatch = Stopwatch()..start();

    try {
      final HttpClientRequest request = method == HttpCheckMethod.head
          ? await client.headUrl(uri).timeout(timeout)
          : await client.getUrl(uri).timeout(timeout);

      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'NetPulse-DiagnosticToolkit/1.0 (Flutter; MTCNA/Cisco Utility)',
      );

      final HttpClientResponse response =
          await request.close().timeout(timeout);
      // Drain body agar koneksi bersih
      await response.drain<void>().timeout(timeout);
      stopwatch.stop();

      final headersMap = <String, String>{};
      response.headers.forEach((name, values) {
        headersMap[name] = values.join(', ');
      });

      final statusCode = response.statusCode;
      return HttpCheckResult(
        url: uri.toString(),
        method: method,
        statusCode: statusCode,
        reasonPhrase: response.reasonPhrase,
        category: HttpCheckResult.classifyStatusCode(statusCode),
        responseTimeMs: stopwatch.elapsedMilliseconds,
        contentLengthBytes:
            response.contentLength >= 0 ? response.contentLength : null,
        headers: headersMap,
        checkedAt: DateTime.now(),
      );
    } finally {
      client.close(force: true);
    }
  }
}
