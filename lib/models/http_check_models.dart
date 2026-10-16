import '../core/network_exceptions.dart';

/// Kategori status respons HTTP berdasarkan standar RFC 9110.
enum HttpStatusCategory {
  informational, // 100-199
  success, // 200-299
  redirection, // 300-399
  clientError, // 400-499
  serverError, // 500-599
  unknown,
}

/// Metode HTTP yang digunakan saat melakukan pengecekan status server.
enum HttpCheckMethod {
  head,
  get,
}

/// Hasil pengecekan sebuah endpoint HTTP/HTTPS.
class HttpCheckResult {
  final String url;
  final HttpCheckMethod method;
  final int? statusCode;
  final String? reasonPhrase;
  final HttpStatusCategory category;
  final int responseTimeMs;
  final int? contentLengthBytes;
  final Map<String, String> headers;
  final DateTime checkedAt;
  final NetworkDiagnosticError? error;

  const HttpCheckResult({
    required this.url,
    required this.method,
    this.statusCode,
    this.reasonPhrase,
    required this.category,
    required this.responseTimeMs,
    this.contentLengthBytes,
    this.headers = const <String, String>{},
    required this.checkedAt,
    this.error,
  });

  bool get isReachable => error == null && statusCode != null;

  bool get isHealthy =>
      isReachable &&
      (category == HttpStatusCategory.success ||
          category == HttpStatusCategory.redirection);

  /// Menentukan kategori berdasarkan kode status HTTP.
  static HttpStatusCategory classifyStatusCode(int? code) {
    if (code == null) return HttpStatusCategory.unknown;
    if (code >= 100 && code < 200) return HttpStatusCategory.informational;
    if (code >= 200 && code < 300) return HttpStatusCategory.success;
    if (code >= 300 && code < 400) return HttpStatusCategory.redirection;
    if (code >= 400 && code < 500) return HttpStatusCategory.clientError;
    if (code >= 500 && code < 600) return HttpStatusCategory.serverError;
    return HttpStatusCategory.unknown;
  }

  /// Mendapatkan deskripsi singkat arti kode status HTTP yang umum dijumpai saat troubleshooting.
  static String describeStatusCode(int? code) {
    switch (code) {
      case 200:
        return 'OK — Server merespons dengan normal.';
      case 201:
        return 'Created — Resource berhasil dibuat.';
      case 204:
        return 'No Content — Server merespons sukses tanpa isi body.';
      case 301:
        return 'Moved Permanently — Endpoint dialihkan permanen ke URL baru.';
      case 302:
        return 'Found — Pengalihan sementara (Temporary Redirect).';
      case 304:
        return 'Not Modified — Konten tidak berubah (Cache valid).';
      case 400:
        return 'Bad Request — Format request tidak diterima oleh server.';
      case 401:
        return 'Unauthorized — Membutuhkan autentikasi (Token / Basic Auth).';
      case 403:
        return 'Forbidden — Akses ditolak oleh WAF / Firewall / ACL server.';
      case 404:
        return 'Not Found — Server aktif, tetapi path/endpoint tidak ditemukan.';
      case 429:
        return 'Too Many Requests — Terkena pembatasan Rate Limiting.';
      case 500:
        return 'Internal Server Error — Kesalahan pada aplikasi backend.';
      case 502:
        return 'Bad Gateway — Reverse Proxy (Nginx/Cloudflare) gagal menghubungi upstream.';
      case 503:
        return 'Service Unavailable — Server sedang overload atau maintenance.';
      case 504:
        return 'Gateway Timeout — Upstream server tidak merespons tepat waktu.';
      default:
        if (code == null) return 'Tidak ada kode status HTTP.';
        if (code >= 200 && code < 300) return 'Respons sukses ($code).';
        if (code >= 300 && code < 400) return 'Respons pengalihan ($code).';
        if (code >= 400 && code < 500) return 'Kesalahan sisi klien ($code).';
        if (code >= 500 && code < 600) return 'Kesalahan sisi server ($code).';
        return 'Kode status HTTP $code.';
    }
  }
}
