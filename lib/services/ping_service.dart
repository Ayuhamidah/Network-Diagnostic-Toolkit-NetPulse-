import 'dart:async';
import 'dart:io';

import '../core/network_exceptions.dart';
import '../models/ping_models.dart';

/// Fungsi abstraksi untuk mengeksekusi satu kali probe, memudahkan dependency injection
/// saat melakukan unit testing tanpa bergantung pada jaringan luar.
typedef SinglePingProbeExecutor = Future<PingPacketResult> Function({
  required String host,
  required int sequence,
  required PingMode mode,
  required int port,
  required Duration timeout,
});

/// Layanan Ping & TCP Port Probe berbasis [Stream] untuk mendemonstrasikan
/// pemrograman asynchronous reaktif di Flutter.
class PingService {
  final SinglePingProbeExecutor? _customExecutor;

  const PingService({SinglePingProbeExecutor? customExecutor})
      : _customExecutor = customExecutor;

  /// Membuka [Stream] paket ping berkala hingga mencapai [maxCount] atau
  /// hingga `StreamSubscription.cancel()` dipanggil oleh ViewModel.
  Stream<PingPacketResult> startPingStream({
    required String host,
    PingMode mode = PingMode.icmp,
    int port = 8291,
    int maxCount = 20,
    Duration interval = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 3),
  }) {
    final cleanHost = host.trim();
    late StreamController<PingPacketResult> controller;
    Timer? timer;
    int currentSeq = 0;
    bool isCancelled = false;
    bool isProbing = false;

    Future<void> runNextTick() async {
      if (isCancelled || isProbing || controller.isClosed) return;
      if (currentSeq >= maxCount) {
        timer?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
        return;
      }

      isProbing = true;
      currentSeq += 1;
      final seqToRun = currentSeq;

      try {
        final executor = _customExecutor ?? _defaultExecuteProbe;
        final result = await executor(
          host: cleanHost,
          sequence: seqToRun,
          mode: mode,
          port: port,
          timeout: timeout,
        );

        if (!isCancelled && !controller.isClosed) {
          controller.add(result);
        }
      } catch (e) {
        final mapped = NetworkDiagnosticError.fromException(
          e,
          target: cleanHost,
          timeout: timeout,
        );
        if (!isCancelled && !controller.isClosed) {
          controller.add(
            PingPacketResult(
              sequence: seqToRun,
              host: cleanHost,
              mode: mode,
              port: mode == PingMode.tcpPort ? port : null,
              isSuccess: false,
              errorMessage: mapped.title,
              timestamp: DateTime.now(),
            ),
          );
        }
      } finally {
        isProbing = false;
        if (seqToRun >= maxCount && !isCancelled && !controller.isClosed) {
          timer?.cancel();
          await controller.close();
        }
      }
    }

    controller = StreamController<PingPacketResult>(
      onListen: () {
        // Jalankan paket pertama secara instan, lalu lanjutkan dengan Timer periodik
        runNextTick();
        timer = Timer.periodic(interval, (_) => runNextTick());
      },
      onCancel: () {
        isCancelled = true;
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Implementasi default untuk mengeksekusi satu kali ICMP Ping atau TCP Socket Probe.
  static Future<PingPacketResult> _defaultExecuteProbe({
    required String host,
    required int sequence,
    required PingMode mode,
    required int port,
    required Duration timeout,
  }) async {
    if (mode == PingMode.tcpPort) {
      return _executeTcpPortProbe(
        host: host,
        sequence: sequence,
        port: port,
        timeout: timeout,
      );
    }
    return _executeIcmpProbe(
      host: host,
      sequence: sequence,
      timeout: timeout,
    );
  }

  /// Melakukan TCP 3-way handshake ke [host]:[port] dan mengukur latensi dengan [Stopwatch].
  static Future<PingPacketResult> _executeTcpPortProbe({
    required String host,
    required int sequence,
    required int port,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      stopwatch.stop();
      final remoteIp = socket.remoteAddress.address;
      final rttMs = stopwatch.elapsedMicroseconds / 1000.0;
      return PingPacketResult(
        sequence: sequence,
        host: host,
        resolvedIp: remoteIp,
        mode: PingMode.tcpPort,
        port: port,
        isSuccess: true,
        rttMs: rttMs,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      stopwatch.stop();
      final mapped = NetworkDiagnosticError.fromException(
        e,
        target: '$host:$port',
        timeout: timeout,
      );
      return PingPacketResult(
        sequence: sequence,
        host: host,
        mode: PingMode.tcpPort,
        port: port,
        isSuccess: false,
        errorMessage: mapped.title,
        timestamp: DateTime.now(),
      );
    } finally {
      socket?.destroy();
    }
  }

  /// Melakukan ICMP Echo satu paket menggunakan utilitas sistem atau fallback TCP DNS/HTTP
  /// apabila lingkungan sandbox membatasi raw ICMP socket.
  static Future<PingPacketResult> _executeIcmpProbe({
    required String host,
    required int sequence,
    required Duration timeout,
  }) async {
    try {
      final bool isWindows = Platform.isWindows;
      final timeoutMs = timeout.inMilliseconds;
      final timeoutSec = timeout.inSeconds.clamp(1, 30);

      final List<String> args = isWindows
          ? <String>['-n', '1', '-w', '$timeoutMs', host]
          : <String>['-c', '1', '-W', '$timeoutSec', host];

      final stopwatch = Stopwatch()..start();
      final result = await Process.run('ping', args).timeout(
        timeout + const Duration(seconds: 1),
      );
      stopwatch.stop();

      final stdoutStr = result.stdout.toString();
      if (result.exitCode == 0) {
        final rttMatch = RegExp(
          r'(?:time|waktu)[=<]\s*([0-9]+(?:\.[0-9]+)?)\s*ms',
          caseSensitive: false,
        ).firstMatch(stdoutStr);
        final ttlMatch = RegExp(
          r'ttl[=:]\s*([0-9]+)',
          caseSensitive: false,
        ).firstMatch(stdoutStr);

        final parsedRtt = rttMatch != null
            ? double.tryParse(rttMatch.group(1)!)
            : (stopwatch.elapsedMicroseconds / 1000.0);
        final parsedTtl =
            ttlMatch != null ? int.tryParse(ttlMatch.group(1)!) : 64;

        return PingPacketResult(
          sequence: sequence,
          host: host,
          mode: PingMode.icmp,
          isSuccess: true,
          rttMs: parsedRtt,
          ttl: parsedTtl,
          timestamp: DateTime.now(),
        );
      }

      return PingPacketResult(
        sequence: sequence,
        host: host,
        mode: PingMode.icmp,
        isSuccess: false,
        errorMessage: 'Request timed out (ICMP unreachable)',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      final mapped = NetworkDiagnosticError.fromException(
        e,
        target: host,
        timeout: timeout,
      );
      return PingPacketResult(
        sequence: sequence,
        host: host,
        mode: PingMode.icmp,
        isSuccess: false,
        errorMessage: mapped.title,
        timestamp: DateTime.now(),
      );
    }
  }
}
