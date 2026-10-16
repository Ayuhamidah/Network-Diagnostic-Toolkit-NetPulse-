import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/ping_models.dart';
import '../services/ping_service.dart';

/// ViewModel untuk layar Ping & Port Probe menggunakan [ChangeNotifier] bawaan Flutter.
/// Mengelola siklus hidup [StreamSubscription] secara aman agar tidak terjadi memory leak.
class PingViewModel extends ChangeNotifier {
  final PingService _pingService;

  PingViewModel({PingService? pingService})
      : _pingService = pingService ?? const PingService();

  String _host = '1.1.1.1';
  PingMode _mode = PingMode.icmp;
  int _selectedPort = 8291; // Default port Winbox MikroTik saat mode TCP dipilih
  int _maxPackets = 20;
  bool _isRunning = false;
  String? _validationError;

  final List<PingPacketResult> _packets = <PingPacketResult>[];
  PingSummaryStats _stats = PingSummaryStats.empty();
  StreamSubscription<PingPacketResult>? _subscription;

  String get host => _host;
  PingMode get mode => _mode;
  int get selectedPort => _selectedPort;
  int get maxPackets => _maxPackets;
  bool get isRunning => _isRunning;
  String? get validationError => _validationError;
  List<PingPacketResult> get packets => List<PingPacketResult>.unmodifiable(_packets);
  PingSummaryStats get stats => _stats;

  void updateHost(String value) {
    _host = value.trim();
    _validationError = null;
    notifyListeners();
  }

  void selectHostPreset(HostPreset preset) {
    _host = preset.host;
    _selectedPort = preset.suggestedPort;
    _validationError = null;
    notifyListeners();
  }

  void setMode(PingMode newMode) {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();
  }

  void setPort(int port) {
    if (port < 1 || port > 65535) {
      _validationError = 'Port TCP harus berada di rentang 1 - 65535.';
      notifyListeners();
      return;
    }
    _selectedPort = port;
    _validationError = null;
    notifyListeners();
  }

  /// Memulai streaming paket Ping atau TCP Port Probe.
  void startPing() {
    if (_host.isEmpty) {
      _validationError = 'Masukkan alamat IP atau hostname tujuan terlebih dahulu.';
      notifyListeners();
      return;
    }

    stopPing(notify: false);
    _packets.clear();
    _stats = PingSummaryStats.empty();
    _validationError = null;
    _isRunning = true;
    notifyListeners();

    final stream = _pingService.startPingStream(
      host: _host,
      mode: _mode,
      port: _selectedPort,
      maxCount: _maxPackets,
      interval: const Duration(seconds: 1),
      timeout: const Duration(seconds: 3),
    );

    _subscription = stream.listen(
      (packet) {
        _packets.add(packet);
        _stats = PingSummaryStats.fromPackets(_packets);
        notifyListeners();
      },
      onError: (Object error) {
        _validationError = error.toString();
        _isRunning = false;
        notifyListeners();
      },
      onDone: () {
        _isRunning = false;
        notifyListeners();
      },
    );
  }

  /// Menghentikan stream ping yang sedang berjalan.
  void stopPing({bool notify = true}) {
    _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    if (notify) {
      notifyListeners();
    }
  }

  /// Membersihkan log dan statistik.
  void clearResults() {
    stopPing(notify: false);
    _packets.clear();
    _stats = PingSummaryStats.empty();
    _validationError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
