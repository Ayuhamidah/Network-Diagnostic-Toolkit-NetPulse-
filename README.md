# Network Diagnostic Toolkit (NetPulse)

Aplikasi mobile ringan berbasis **Flutter** untuk melakukan *troubleshooting* jaringan dasar, dirancang sebagai jembatan antara keahlian infrastruktur jaringan (**MTCNA / Cisco CCNA**) dan pengembangan aplikasi lintas platform (**Flutter**).

## Live Demo

🔗 **[network-diagnostic-toolkit-netpulse.vercel.app](https://network-diagnostic-toolkit-netpulse.vercel.app/)**

> Demo yang di-host adalah prototipe web interaktif (`preview/index.html`) dari UI aplikasi. Browser tidak bisa mengirim paket ICMP mentah atau request HTTP lintas origin, jadi demo memakai **data simulasi** (ditandai badge *Demo Mode*). Logika aslinya (`lib/services/`) bisa dijalankan secara nyata di lokal lewat `dart tool/web_emulator_server.dart --launch-chrome`.

---

## Fitur Utama

### 1. Dual-Mode Ping & Router Port Probe (`Future` & `Stream`)
- **ICMP Echo Mode**: Streaming paket ping secara *real-time* (`Stream<PingPacketResult>`), lengkap dengan nomor urut (`seq`), TTL, waktu respons (`RTT ms`), serta kalkulasi *live statistics* (**Min / Avg / Max RTT**, **Jitter**, dan **Packet Loss %**).
- **TCP Port Probe Mode (MikroTik & Cisco Presets)**: Menguji keterjangkauan (*reachability*) dan latensi jabat tangan TCP (*3-way handshake*) ke port manajemen router populer:
  - `8291` — MikroTik Winbox
  - `8728` — MikroTik RouterOS API
  - `22` — SSH (Cisco IOS / RouterOS CLI)
  - `53` — DNS Server
  - `80` / `443` — WebFig / HTTP(S) Management
- **Target Presets**: `1.1.1.1` (Cloudflare DNS), `8.8.8.8` (Google DNS), `192.168.88.1` (MikroTik Default Gateway), `192.168.1.1` (Cisco/SOHO Default Gateway).

### 2. IPv4 Subnet & CIDR Calculator (`Bitwise Engine`)
- Kalkulasi instan untuk prefix `/0` hingga `/32` menggunakan operasi bitwise 32-bit murni.
- Menampilkan **Network Address**, **Broadcast Address**, **Subnet Mask**, dan **Wildcard Mask** (siap pakai untuk konfigurasi OSPF network statement atau Access Control List di Cisco/MikroTik).
- Menampilkan rentang **First Usable Host – Last Usable Host** serta **Total Usable Hosts** (termasuk dukungan khusus `/31` Point-to-Point RFC 3021 dan `/32` Host Route).
- Deteksi otomatis kelas IP (**Class A/B/C/D/E**) dan ruang alamat (**Private RFC 1918**, **CGNAT RFC 6598**, **Loopback**, **Link-Local**, **Public Routable**).
- Visualisasi **32-Bit Binary Map** yang membedakan porsi *Network Bits* dan *Host Bits*.

### 3. HTTP Server Status & Latency Checker (`HTTP Requests` & `Error Handling`)
- Mendukung metode `HEAD` (cepat & hemat bandwidth) dan `GET`.
- Mengukur waktu respons server (*Latency / Time-to-First-Byte*) dalam milidetik (`ms`) menggunakan `Stopwatch`.
- Mengklasifikasikan kode status HTTP (`2xx Success`, `3xx Redirection`, `4xx Client Error`, `5xx Server Error`).
- Menampilkan *Response Headers* penting (`server`, `content-type`, `cache-control`, `cf-ray`, dll.).
- **Resilient Error Handling**: Menangani dan menerjemahkan `TimeoutException`, `SocketException` (DNS failure / Connection Refused / Network Unreachable), dan `HandshakeException` (SSL/TLS error) menjadi kartu diagnostik dengan saran *troubleshooting* tingkat jaringan.

---

## Arsitektur & Skill Flutter yang Dipamerkan

```
lib/
├── core/
│   └── network_exceptions.dart       # Custom exception hierarchy & error mapper
├── models/
│   ├── ping_models.dart              # Data models untuk Ping, Port Preset, & Live Stats
│   ├── subnet_models.dart            # Data models untuk CIDR, Wildcard, & Binary Map
│   └── http_check_models.dart        # Data models untuk HTTP Response & Riwayat
├── services/
│   ├── ping_service.dart             # Stream generator untuk ICMP & TCP Socket Probe
│   ├── subnet_calculator_service.dart# Mesin bitwise IPv4 32-bit murni
│   └── http_checker_service.dart     # HTTP client dengan timeout & Stopwatch latency
├── viewmodels/
│   ├── ping_viewmodel.dart           # ChangeNotifier + StreamSubscription lifecycle
│   ├── subnet_viewmodel.dart         # ChangeNotifier untuk kalkulasi CIDR reaktif
│   └── http_checker_viewmodel.dart   # ChangeNotifier untuk async state & riwayat HTTP
├── ui/
│   └── screens/
│       ├── ping_screen.dart          # UI Tab 1: Ping & Port Probe + Live Console
│       ├── subnet_screen.dart        # UI Tab 2: Subnet/CIDR Calculator + Binary View
│       └── http_checker_screen.dart  # UI Tab 3: HTTP Status & Header Inspector
└── main.dart                         # Entry point & NOC Dark Theme Navigation Shell
```

---

## Cara Menjalankan

### 1. Menjalankan Aplikasi Flutter
Pastikan Flutter SDK telah terinstal, lalu jalankan perintah berikut di direktori proyek:
```bash
flutter pub get
flutter run
```

### 2. Menjalankan Unit Test (Dart / Flutter)
Pengujian logika inti (Subnet Calculator, Ping Stream & Jitter/Loss Statistics, serta HTTP Error/Status Classification) dapat dijalankan langsung menggunakan `dart` maupun `flutter test`:
```bash
dart test/network_toolkit_test.dart
```

### 3. Pratinjau Interaktif (Web Preview)
Buka `preview/index.html` di browser untuk mencoba simulasi interaktif seluruh fitur secara langsung.
