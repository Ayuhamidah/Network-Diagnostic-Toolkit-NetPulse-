import 'dart:math' as math;

/// Mode pengujian keterjangkauan host.
enum PingMode {
  /// ICMP Echo Request standar (mengukur RTT & TTL Layer 3).
  icmp,

  /// TCP 3-Way Handshake Probe ke port spesifik (berguna untuk cek layanan MikroTik/Cisco).
  tcpPort,
}

/// Preset port populer untuk administrasi router & server (MikroTik / Cisco / Infrastruktur).
class PortPreset {
  final int port;
  final String label;
  final String protocolNote;

  const PortPreset({
    required this.port,
    required this.label,
    required this.protocolNote,
  });

  static const List<PortPreset> defaultPresets = <PortPreset>[
    PortPreset(
      port: 8291,
      label: 'Winbox (8291)',
      protocolNote: 'MikroTik RouterOS Winbox Management',
    ),
    PortPreset(
      port: 8728,
      label: 'RouterOS API (8728)',
      protocolNote: 'MikroTik API Automation Port',
    ),
    PortPreset(
      port: 22,
      label: 'SSH (22)',
      protocolNote: 'Cisco IOS / RouterOS / Linux Secure Shell',
    ),
    PortPreset(
      port: 53,
      label: 'DNS (53)',
      protocolNote: 'Domain Name System Resolver',
    ),
    PortPreset(
      port: 80,
      label: 'HTTP (80)',
      protocolNote: 'WebFig / HTTP Web Server',
    ),
    PortPreset(
      port: 443,
      label: 'HTTPS (443)',
      protocolNote: 'TLS Secure Web / RESTCONF',
    ),
  ];
}

/// Preset host cepat untuk pengujian jaringan sehari-hari.
class HostPreset {
  final String host;
  final String label;
  final String description;
  final int suggestedPort;

  const HostPreset({
    required this.host,
    required this.label,
    required this.description,
    this.suggestedPort = 53,
  });

  static const List<HostPreset> defaultPresets = <HostPreset>[
    HostPreset(
      host: '1.1.1.1',
      label: 'Cloudflare DNS',
      description: 'Anycast Public DNS (1.1.1.1)',
      suggestedPort: 53,
    ),
    HostPreset(
      host: '8.8.8.8',
      label: 'Google DNS',
      description: 'Public Resolver (8.8.8.8)',
      suggestedPort: 53,
    ),
    HostPreset(
      host: '192.168.88.1',
      label: 'MikroTik Default',
      description: 'RouterOS Default LAN Gateway',
      suggestedPort: 8291,
    ),
    HostPreset(
      host: '192.168.1.1',
      label: 'Cisco / CPE Gateway',
      description: 'Standard SOHO / Branch Gateway',
      suggestedPort: 22,
    ),
  ];
}

/// Hasil satu sekuens paket Ping atau TCP Port Probe.
class PingPacketResult {
  final int sequence;
  final String host;
  final String? resolvedIp;
  final PingMode mode;
  final int? port;
  final bool isSuccess;
  final double? rttMs;
  final int? ttl;
  final String? errorMessage;
  final DateTime timestamp;

  const PingPacketResult({
    required this.sequence,
    required this.host,
    this.resolvedIp,
    required this.mode,
    this.port,
    required this.isSuccess,
    this.rttMs,
    this.ttl,
    this.errorMessage,
    required this.timestamp,
  });

  /// Format baris log ala terminal router / CLI.
  String toCliLogLine() {
    if (!isSuccess) {
      final targetInfo = mode == PingMode.tcpPort ? '$host:$port' : host;
      return 'seq=$sequence target=$targetInfo status=TIMEOUT (${errorMessage ?? "Request timed out"})';
    }
    final rttFormatted = rttMs != null ? '${rttMs!.toStringAsFixed(1)} ms' : '-';
    if (mode == PingMode.tcpPort) {
      return 'seq=$sequence tcp://$host:${port ?? 80} connected time=$rttFormatted';
    }
    final ttlInfo = ttl != null ? 'ttl=$ttl ' : '';
    final ipInfo = resolvedIp != null && resolvedIp != host ? ' ($resolvedIp)' : '';
    return '64 bytes from $host$ipInfo: icmp_seq=$sequence ${ttlInfo}time=$rttFormatted';
  }
}

/// Statistik agregat dari rangkaian paket Ping yang telah dikirim.
class PingSummaryStats {
  final int transmitted;
  final int received;
  final int lost;
  final double lossPercentage;
  final double? minRttMs;
  final double? avgRttMs;
  final double? maxRttMs;
  final double? jitterMs;

  const PingSummaryStats({
    required this.transmitted,
    required this.received,
    required this.lost,
    required this.lossPercentage,
    this.minRttMs,
    this.avgRttMs,
    this.maxRttMs,
    this.jitterMs,
  });

  factory PingSummaryStats.empty() {
    return const PingSummaryStats(
      transmitted: 0,
      received: 0,
      lost: 0,
      lossPercentage: 0.0,
    );
  }

  /// Menghitung statistik lengkap (termasuk Jitter rata-rata selisih antar-paket)
  /// dari daftar hasil paket.
  factory PingSummaryStats.fromPackets(List<PingPacketResult> packets) {
    if (packets.isEmpty) {
      return PingSummaryStats.empty();
    }

    final transmitted = packets.length;
    final successfulRtts = packets
        .where((p) => p.isSuccess && p.rttMs != null)
        .map((p) => p.rttMs!)
        .toList();
    final received = successfulRtts.length;
    final lost = transmitted - received;
    final lossPercentage = (lost / transmitted) * 100.0;

    if (successfulRtts.isEmpty) {
      return PingSummaryStats(
        transmitted: transmitted,
        received: 0,
        lost: lost,
        lossPercentage: lossPercentage,
      );
    }

    final minRtt = successfulRtts.reduce(math.min);
    final maxRtt = successfulRtts.reduce(math.max);
    final sumRtt = successfulRtts.fold<double>(0.0, (acc, val) => acc + val);
    final avgRtt = sumRtt / successfulRtts.length;

    // Jitter dihitung sebagai rata-rata selisih absolut RTT antar paket berurutan (RFC 3550 style approximation)
    double jitter = 0.0;
    if (successfulRtts.length > 1) {
      double diffSum = 0.0;
      for (int i = 1; i < successfulRtts.length; i++) {
        diffSum += (successfulRtts[i] - successfulRtts[i - 1]).abs();
      }
      jitter = diffSum / (successfulRtts.length - 1);
    }

    return PingSummaryStats(
      transmitted: transmitted,
      received: received,
      lost: lost,
      lossPercentage: lossPercentage,
      minRttMs: minRtt,
      avgRttMs: avgRtt,
      maxRttMs: maxRtt,
      jitterMs: jitter,
    );
  }

  /// Penilaian kualitas link jaringan berdasarkan RTT dan Packet Loss.
  String get linkQualityLabel {
    if (transmitted == 0) return 'Belum Diuji';
    if (lossPercentage >= 100.0) return 'Down / Unreachable';
    if (lossPercentage > 5.0) return 'Degraded (Packet Loss)';
    final avg = avgRttMs ?? 0.0;
    if (avg < 30.0) return 'Excellent (Low Latency)';
    if (avg < 100.0) return 'Good (Stable)';
    return 'High Latency';
  }
}
