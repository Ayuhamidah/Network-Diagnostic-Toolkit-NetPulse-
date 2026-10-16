import '../core/network_exceptions.dart';
import '../models/subnet_models.dart';

/// Mesin kalkulasi IPv4 Subnet & CIDR berbasis operasi bitwise 32-bit.
class SubnetCalculatorService {
  const SubnetCalculatorService();

  /// Menghitung informasi lengkap subnet dari string IP (mis. `192.168.88.1`)
  /// dan panjang prefix CIDR (`0` hingga `32`).
  ///
  /// Juga mendukung input gabungan seperti `192.168.88.1/24` jika [overridePrefix] tidak diisi.
  SubnetInfo calculate(String rawIpInput, {int? overridePrefix}) {
    final trimmed = rawIpInput.trim();
    if (trimmed.isEmpty) {
      throw const NetworkDiagnosticError(
        type: NetworkErrorType.invalidInput,
        title: 'Alamat IP Kosong',
        message: 'Masukkan alamat IPv4 yang valid (contoh: 192.168.88.1).',
        technicalDetail: 'Empty IP string',
        troubleshootingHint: 'Gunakan format 4 oktet desimal (0-255) yang dipisahkan titik.',
      );
    }

    String ipPart = trimmed;
    int prefix = overridePrefix ?? 24;

    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length != 2) {
        throw const NetworkDiagnosticError(
          type: NetworkErrorType.invalidInput,
          title: 'Format CIDR Tidak Valid',
          message: 'Gunakan format IP/Prefix seperti 192.168.88.1/24.',
          technicalDetail: 'Invalid slash count in CIDR input',
          troubleshootingHint: 'Pastikan hanya ada satu tanda garis miring (/) diikuti angka 0-32.',
        );
      }
      ipPart = parts[0].trim();
      final parsedPrefix = int.tryParse(parts[1].trim());
      if (parsedPrefix == null) {
        throw const NetworkDiagnosticError(
          type: NetworkErrorType.invalidInput,
          title: 'Prefix CIDR Tidak Valid',
          message: 'Nilai prefix setelah "/" harus berupa angka antara 0 dan 32.',
          technicalDetail: 'Non-integer CIDR prefix',
          troubleshootingHint: 'Contoh prefix standar: /24 (LAN), /30 (Point-to-Point WAN).',
        );
      }
      if (overridePrefix == null) {
        prefix = parsedPrefix;
      }
    }

    if (prefix < 0 || prefix > 32) {
      throw NetworkDiagnosticError(
        type: NetworkErrorType.invalidInput,
        title: 'Prefix Di Luar Rentang (/0 - /32)',
        message: 'Prefix /$prefix tidak valid untuk IPv4.',
        technicalDetail: 'Prefix out of range: $prefix',
        troubleshootingHint: 'Panjang prefix IPv4 harus berada di antara /0 hingga /32.',
      );
    }

    final octets = _parseIpv4Octets(ipPart);
    final ipInt = _octetsToUint32(octets);

    // Hitung 32-bit subnet mask
    final int maskInt = prefix == 0
        ? 0
        : ((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF);
    final int wildcardInt = (~maskInt) & 0xFFFFFFFF;
    final int networkInt = (ipInt & maskInt) & 0xFFFFFFFF;
    final int broadcastInt = (networkInt | wildcardInt) & 0xFFFFFFFF;

    final int totalAddresses = prefix == 0 ? 4294967296 : (1 << (32 - prefix));

    int usableHosts;
    String firstHost;
    String lastHost;

    if (prefix == 32) {
      usableHosts = 1;
      firstHost = _uint32ToIpv4(networkInt);
      lastHost = _uint32ToIpv4(networkInt);
    } else if (prefix == 31) {
      // RFC 3021: /31 Point-to-Point Links memiliki 2 alamat host yang dapat digunakan tanpa broadcast
      usableHosts = 2;
      firstHost = _uint32ToIpv4(networkInt);
      lastHost = _uint32ToIpv4(broadcastInt);
    } else {
      usableHosts = totalAddresses - 2;
      firstHost = _uint32ToIpv4((networkInt + 1) & 0xFFFFFFFF);
      lastHost = _uint32ToIpv4((broadcastInt - 1) & 0xFFFFFFFF);
    }

    final firstOctet = octets[0];
    final secondOctet = octets[1];

    return SubnetInfo(
      inputIp: _uint32ToIpv4(ipInt),
      prefixLength: prefix,
      networkAddress: _uint32ToIpv4(networkInt),
      broadcastAddress: _uint32ToIpv4(broadcastInt),
      subnetMask: _uint32ToIpv4(maskInt),
      wildcardMask: _uint32ToIpv4(wildcardInt),
      firstUsableHost: firstHost,
      lastUsableHost: lastHost,
      totalAddresses: totalAddresses,
      usableHosts: usableHosts,
      ipClass: _detectIpClass(firstOctet),
      scopeDescription: _detectScope(firstOctet, secondOctet),
      isPrivateRfc1918: _isRfc1918(firstOctet, secondOctet),
      ipBinaryDotted: _uint32ToBinaryDotted(ipInt),
      maskBinaryDotted: _uint32ToBinaryDotted(maskInt),
      networkBinaryDotted: _uint32ToBinaryDotted(networkInt),
    );
  }

  List<int> _parseIpv4Octets(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      throw NetworkDiagnosticError(
        type: NetworkErrorType.invalidInput,
        title: 'Format IPv4 Tidak Valid',
        message: '"$ip" harus terdiri dari 4 oktet yang dipisahkan titik.',
        technicalDetail: 'Expected 4 octets, got ${parts.length}',
        troubleshootingHint: 'Contoh penulisan yang benar: 192.168.88.1 atau 10.0.0.1.',
      );
    }

    final result = <int>[];
    for (int i = 0; i < 4; i++) {
      final rawOctet = parts[i].trim();
      final value = int.tryParse(rawOctet);
      if (value == null || value < 0 || value > 255) {
        throw NetworkDiagnosticError(
          type: NetworkErrorType.invalidInput,
          title: 'Oktet ke-${i + 1} Tidak Valid ("$rawOctet")',
          message: 'Setiap oktet IPv4 harus berupa angka antara 0 hingga 255.',
          technicalDetail: 'Invalid octet at index $i: $rawOctet',
          troubleshootingHint: 'Periksa kembali nilai oktet ke-${i + 1} pada alamat IP Anda.',
        );
      }
      result.add(value);
    }
    return result;
  }

  int _octetsToUint32(List<int> octets) {
    return ((octets[0] & 0xFF) << 24) |
        ((octets[1] & 0xFF) << 16) |
        ((octets[2] & 0xFF) << 8) |
        (octets[3] & 0xFF);
  }

  String _uint32ToIpv4(int value) {
    final o1 = (value >> 24) & 0xFF;
    final o2 = (value >> 16) & 0xFF;
    final o3 = (value >> 8) & 0xFF;
    final o4 = value & 0xFF;
    return '$o1.$o2.$o3.$o4';
  }

  String _uint32ToBinaryDotted(int value) {
    final o1 = ((value >> 24) & 0xFF).toRadixString(2).padLeft(8, '0');
    final o2 = ((value >> 16) & 0xFF).toRadixString(2).padLeft(8, '0');
    final o3 = ((value >> 8) & 0xFF).toRadixString(2).padLeft(8, '0');
    final o4 = (value & 0xFF).toRadixString(2).padLeft(8, '0');
    return '$o1.$o2.$o3.$o4';
  }

  String _detectIpClass(int firstOctet) {
    if (firstOctet >= 1 && firstOctet <= 126) return 'Class A';
    if (firstOctet == 127) return 'Class A (Loopback)';
    if (firstOctet >= 128 && firstOctet <= 191) return 'Class B';
    if (firstOctet >= 192 && firstOctet <= 223) return 'Class C';
    if (firstOctet >= 224 && firstOctet <= 239) return 'Class D (Multicast)';
    return 'Class E (Experimental)';
  }

  bool _isRfc1918(int firstOctet, int secondOctet) {
    if (firstOctet == 10) return true;
    if (firstOctet == 172 && secondOctet >= 16 && secondOctet <= 31) return true;
    if (firstOctet == 192 && secondOctet == 168) return true;
    return false;
  }

  String _detectScope(int firstOctet, int secondOctet) {
    if (_isRfc1918(firstOctet, secondOctet)) {
      return 'Private Network (RFC 1918 — Butuh NAT ke Internet)';
    }
    if (firstOctet == 100 && secondOctet >= 64 && secondOctet <= 127) {
      return 'Carrier-Grade NAT / CGNAT (RFC 6598)';
    }
    if (firstOctet == 127) {
      return 'Loopback Host Address (RFC 1122)';
    }
    if (firstOctet == 169 && secondOctet == 254) {
      return 'APIPA / Link-Local (RFC 3927 — Cek DHCP Server!)';
    }
    if (firstOctet >= 224 && firstOctet <= 239) {
      return 'Multicast Routing Group (OSPF / RIPv2 / PIM)';
    }
    return 'Public Routable Address (Global Internet)';
  }
}
