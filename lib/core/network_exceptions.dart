import 'dart:async';
import 'dart:io';

/// Kategori error jaringan untuk mempermudah troubleshooting oleh Network Engineer.
enum NetworkErrorType {
  timeout,
  dnsLookupFailed,
  connectionRefused,
  sslHandshakeFailed,
  networkUnreachable,
  invalidInput,
  unknown,
}

/// Representasi terstruktur dari kegagalan koneksi jaringan beserta saran diagnostik.
class NetworkDiagnosticError implements Exception {
  final NetworkErrorType type;
  final String title;
  final String message;
  final String technicalDetail;
  final String troubleshootingHint;

  const NetworkDiagnosticError({
    required this.type,
    required this.title,
    required this.message,
    required this.technicalDetail,
    required this.troubleshootingHint,
  });

  /// Memetakan exception mentah (SocketException, TimeoutException, dll.)
  /// menjadi pesan diagnostik yang informatif.
  factory NetworkDiagnosticError.fromException(
    Object error, {
    String target = '',
    Duration? timeout,
  }) {
    if (error is NetworkDiagnosticError) {
      return error;
    }

    if (error is TimeoutException) {
      final timeoutSec = timeout != null ? '${timeout.inSeconds} detik' : 'batas waktu';
      return NetworkDiagnosticError(
        type: NetworkErrorType.timeout,
        title: 'Request Timed Out (RTO)',
        message: 'Target $target tidak merespons dalam $timeoutSec.',
        technicalDetail: error.toString(),
        troubleshootingHint:
            'Periksa aturan firewall (drop rule pada chain input/forward), routing table menuju gateway, atau kondisi kongesti link.',
      );
    }

    if (error is HandshakeException || error is TlsException) {
      return NetworkDiagnosticError(
        type: NetworkErrorType.sslHandshakeFailed,
        title: 'Kegagalan Jabat Tangan SSL/TLS',
        message: 'Tidak dapat memverifikasi sertifikat keamanan pada $target.',
        technicalDetail: error.toString(),
        troubleshootingHint:
            'Pastikan jam sistem akurat, sertifikat SSL server belum kedaluwarsa, dan tidak ada inspeksi HTTPS (MITM proxy) yang memblokir koneksi.',
      );
    }

    if (error is SocketException) {
      final msg = error.message.toLowerCase();
      final osMsg = (error.osError?.message ?? '').toLowerCase();
      final combined = '$msg $osMsg';

      if (combined.contains('failed host lookup') ||
          combined.contains('no address associated') ||
          combined.contains('getaddrinfo') ||
          error.osError?.errorCode == 11001 ||
          error.osError?.errorCode == 7) {
        return NetworkDiagnosticError(
          type: NetworkErrorType.dnsLookupFailed,
          title: 'DNS Lookup Failed (NXDOMAIN / Timeout)',
          message: 'Gagal menerjemahkan nama domain "$target" ke alamat IP.',
          technicalDetail: error.toString(),
          troubleshootingHint:
              'Coba lakukan ping ke IP langsung (mis. 1.1.1.1 atau 8.8.8.8). Jika berhasil, periksa konfigurasi IP > DNS pada router Anda.',
        );
      }

      if (combined.contains('connection refused') ||
          error.osError?.errorCode == 10061 ||
          error.osError?.errorCode == 111) {
        return NetworkDiagnosticError(
          type: NetworkErrorType.connectionRefused,
          title: 'Connection Refused (TCP RST)',
          message: 'Host $target aktif tetapi menolak koneksi pada port tujuan.',
          technicalDetail: error.toString(),
          troubleshootingHint:
              'Host dapat dijangkau di Layer 3, namun layanan (daemon) tidak berjalan di port tersebut atau diblokir oleh firewall reject (TCP Reset).',
        );
      }

      if (combined.contains('network is unreachable') ||
          combined.contains('no route to host') ||
          error.osError?.errorCode == 10051 ||
          error.osError?.errorCode == 10065 ||
          error.osError?.errorCode == 101 ||
          error.osError?.errorCode == 113) {
        return NetworkDiagnosticError(
          type: NetworkErrorType.networkUnreachable,
          title: 'Network / Host Unreachable',
          message: 'Tidak ada rute jaringan menuju $target.',
          technicalDetail: error.toString(),
          troubleshootingHint:
              'Periksa status antarmuka (Wi-Fi/Seluler), default gateway (0.0.0.0/0), atau tabel ARP/routing pada router lokal.',
        );
      }

      return NetworkDiagnosticError(
        type: NetworkErrorType.networkUnreachable,
        title: 'Kesalahan Soket Jaringan (SocketException)',
        message: 'Koneksi ke $target terputus atau gagal dibuat.',
        technicalDetail: error.toString(),
        troubleshootingHint:
            'Pastikan perangkat memiliki koneksi internet/LAN aktif dan target tidak memblokir trafik keluar.',
      );
    }

    if (error is FormatException) {
      return NetworkDiagnosticError(
        type: NetworkErrorType.invalidInput,
        title: 'Format Input Tidak Valid',
        message: error.message,
        technicalDetail: error.toString(),
        troubleshootingHint:
            'Periksa kembali penulisan alamat IPv4 (contoh: 192.168.88.1), prefix CIDR (/0 - /32), atau format URL (https://example.com).',
      );
    }

    return NetworkDiagnosticError(
      type: NetworkErrorType.unknown,
      title: 'Kesalahan Diagnostik Tidak Terduga',
      message: 'Terjadi kesalahan saat menghubungi $target.',
      technicalDetail: error.toString(),
      troubleshootingHint:
          'Periksa parameter input dan coba ulangi pengujian beberapa saat lagi.',
    );
  }

  @override
  String toString() => '$title: $message ($troubleshootingHint)';
}
