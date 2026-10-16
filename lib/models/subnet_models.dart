/// Hasil kalkulasi lengkap subnet IPv4 berdasarkan alamat IP dan prefix CIDR.
class SubnetInfo {
  final String inputIp;
  final int prefixLength;
  final String networkAddress;
  final String broadcastAddress;
  final String subnetMask;
  final String wildcardMask;
  final String firstUsableHost;
  final String lastUsableHost;
  final int totalAddresses;
  final int usableHosts;
  final String ipClass;
  final String scopeDescription;
  final bool isPrivateRfc1918;
  final String ipBinaryDotted;
  final String maskBinaryDotted;
  final String networkBinaryDotted;

  const SubnetInfo({
    required this.inputIp,
    required this.prefixLength,
    required this.networkAddress,
    required this.broadcastAddress,
    required this.subnetMask,
    required this.wildcardMask,
    required this.firstUsableHost,
    required this.lastUsableHost,
    required this.totalAddresses,
    required this.usableHosts,
    required this.ipClass,
    required this.scopeDescription,
    required this.isPrivateRfc1918,
    required this.ipBinaryDotted,
    required this.maskBinaryDotted,
    required this.networkBinaryDotted,
  });

  /// Notasi CIDR standar untuk blok jaringan (contoh: `192.168.88.0/24`).
  String get networkCidr => '$networkAddress/$prefixLength';

  /// Contoh sintaks siap pakai untuk konfigurasi OSPF Cisco IOS.
  String get ciscoOspfSnippet =>
      'network $networkAddress $wildcardMask area 0';

  /// Contoh sintaks siap pakai untuk konfigurasi IP Address MikroTik RouterOS.
  String get mikrotikAddressSnippet =>
      '/ip address add address=$firstUsableHost/$prefixLength interface=ether2';
}

/// Preset prefix CIDR yang sering digunakan oleh teknisi MTCNA / Cisco.
class CidrPreset {
  final int prefix;
  final String label;
  final String useCase;

  const CidrPreset({
    required this.prefix,
    required this.label,
    required this.useCase,
  });

  static const List<CidrPreset> commonPresets = <CidrPreset>[
    CidrPreset(
      prefix: 30,
      label: '/30 (P2P WAN)',
      useCase: 'Link Point-to-Point antar Router (2 host)',
    ),
    CidrPreset(
      prefix: 29,
      label: '/29 (Small WAN)',
      useCase: 'Blok IP Publik ISP / Peering (6 host)',
    ),
    CidrPreset(
      prefix: 24,
      label: '/24 (Standard LAN)',
      useCase: 'Segmen VLAN Kantor / Hotspot (254 host)',
    ),
    CidrPreset(
      prefix: 22,
      label: '/22 (Large Wi-Fi)',
      useCase: 'Jaringan Kampus / Event (1.022 host)',
    ),
    CidrPreset(
      prefix: 16,
      label: '/16 (Core Supernet)',
      useCase: 'Agregasi Rute Internal (65.534 host)',
    ),
  ];
}
