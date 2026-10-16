import 'dart:async';
import 'dart:io';

import '../lib/core/network_exceptions.dart';
import '../lib/models/http_check_models.dart';
import '../lib/models/ping_models.dart';
import '../lib/services/http_checker_service.dart';
import '../lib/services/ping_service.dart';
import '../lib/services/subnet_calculator_service.dart';

int _passed = 0;
int _failed = 0;

void expectEqual(Object? actual, Object? expected, String description) {
  if (actual != expected) {
    _failed++;
    stderr.writeln('  [FAIL] $description');
    stderr.writeln('         Expected: $expected');
    stderr.writeln('         Actual  : $actual');
    throw StateError('Assertion failed: $description');
  }
}

void expectTrue(bool condition, String description) {
  if (!condition) {
    _failed++;
    stderr.writeln('  [FAIL] $description');
    throw StateError('Assertion failed: $description');
  }
}

Future<void> runTest(String name, FutureOr<void> Function() body) async {
  try {
    await body();
    _passed++;
    stdout.writeln('  [PASS] $name');
  } catch (e) {
    stderr.writeln('  [ERROR] $name -> $e');
  }
}

Future<void> main() async {
  stdout.writeln('==============================================================');
  stdout.writeln(' NetPulse — Network Diagnostic Toolkit Automated Unit Tests');
  stdout.writeln('==============================================================\n');

  const subnetService = SubnetCalculatorService();

  stdout.writeln('--- 1. IPv4 Subnet & CIDR Calculator Tests ---');

  await runTest('Standard MikroTik LAN 192.168.88.1/24 calculation', () {
    final info = subnetService.calculate('192.168.88.1', overridePrefix: 24);
    expectEqual(info.networkAddress, '192.168.88.0', 'Network ID');
    expectEqual(info.broadcastAddress, '192.168.88.255', 'Broadcast Address');
    expectEqual(info.subnetMask, '255.255.255.0', 'Subnet Mask');
    expectEqual(info.wildcardMask, '0.0.0.255', 'Wildcard Mask for OSPF/ACL');
    expectEqual(info.firstUsableHost, '192.168.88.1', 'First Usable Host');
    expectEqual(info.lastUsableHost, '192.168.88.254', 'Last Usable Host');
    expectEqual(info.usableHosts, 254, 'Usable Hosts');
    expectTrue(info.isPrivateRfc1918, 'Should detect RFC 1918 Private IP');
    expectEqual(info.ipClass, 'Class C', 'IP Class');
  });

  await runTest('Cisco Point-to-Point WAN Link 10.10.20.5/30 calculation', () {
    final info = subnetService.calculate('10.10.20.5/30');
    expectEqual(info.prefixLength, 30, 'Prefix Length');
    expectEqual(info.networkAddress, '10.10.20.4', 'Network ID');
    expectEqual(info.broadcastAddress, '10.10.20.7', 'Broadcast Address');
    expectEqual(info.subnetMask, '255.255.255.252', 'Subnet Mask');
    expectEqual(info.wildcardMask, '0.0.0.3', 'Wildcard Mask');
    expectEqual(info.firstUsableHost, '10.10.20.5', 'First Host');
    expectEqual(info.lastUsableHost, '10.10.20.6', 'Last Host');
    expectEqual(info.usableHosts, 2, 'Usable Hosts in /30');
    expectEqual(
      info.ciscoOspfSnippet,
      'network 10.10.20.4 0.0.0.3 area 0',
      'Cisco OSPF CLI Snippet',
    );
  });

  await runTest('RFC 3021 /31 Point-to-Point & /32 Host Route edge cases', () {
    final p31 = subnetService.calculate('172.16.0.10', overridePrefix: 31);
    expectEqual(p31.usableHosts, 2, '/31 Usable Hosts');
    expectEqual(p31.firstUsableHost, '172.16.0.10', '/31 First Host');
    expectEqual(p31.lastUsableHost, '172.16.0.11', '/31 Last Host');
    expectTrue(p31.isPrivateRfc1918, '172.16.0.0/12 is RFC 1918');

    final p32 = subnetService.calculate('1.1.1.1', overridePrefix: 32);
    expectEqual(p32.usableHosts, 1, '/32 Host Route Usable Hosts');
    expectEqual(p32.wildcardMask, '0.0.0.0', '/32 Wildcard Mask');
    expectTrue(!p32.isPrivateRfc1918, '1.1.1.1 is Public IP');
  });

  await runTest('Invalid IPv4 format throws NetworkDiagnosticError', () {
    bool caught = false;
    try {
      subnetService.calculate('192.168.300.1/24');
    } on NetworkDiagnosticError catch (e) {
      caught = true;
      expectEqual(e.type, NetworkErrorType.invalidInput, 'Error type');
    }
    expectTrue(caught, 'Should throw NetworkDiagnosticError for octet > 255');
  });

  stdout.writeln('\n--- 2. Asynchronous Ping Stream & Jitter/Loss Statistics Tests ---');

  await runTest('PingService emits stream packets and computes accurate stats', () async {
    final simulatedRtts = <double?>[12.0, 16.0, null, 14.0]; // 1 packet loss out of 4
    final service = PingService(
      customExecutor: ({
        required String host,
        required int sequence,
        required PingMode mode,
        required int port,
        required Duration timeout,
      }) async {
        final rtt = simulatedRtts[sequence - 1];
        return PingPacketResult(
          sequence: sequence,
          host: host,
          mode: mode,
          port: port,
          isSuccess: rtt != null,
          rttMs: rtt,
          ttl: 58,
          errorMessage: rtt == null ? 'Request timed out' : null,
          timestamp: DateTime.now(),
        );
      },
    );

    final collected = await service
        .startPingStream(
          host: '192.168.88.1',
          mode: PingMode.tcpPort,
          port: 8291,
          maxCount: 4,
          interval: const Duration(milliseconds: 20),
        )
        .toList();

    expectEqual(collected.length, 4, 'Should emit exactly 4 packets');
    final stats = PingSummaryStats.fromPackets(collected);
    expectEqual(stats.transmitted, 4, 'Transmitted count');
    expectEqual(stats.received, 3, 'Received count');
    expectEqual(stats.lost, 1, 'Lost count');
    expectEqual(stats.lossPercentage, 25.0, '25% Packet Loss');
    expectEqual(stats.minRttMs, 12.0, 'Min RTT');
    expectEqual(stats.maxRttMs, 16.0, 'Max RTT');
    expectEqual(stats.avgRttMs, 14.0, 'Avg RTT ((12+16+14)/3)');
    expectEqual(stats.jitterMs, 3.0, 'Jitter ((|16-12| + |14-16|)/2 = 3.0)');
  });

  stdout.writeln('\n--- 3. HTTP Status Checker & Resilient Error Handling Tests ---');

  await runTest('HttpCheckerService normalizes URLs and classifies HTTP 200 OK', () async {
    final httpService = HttpCheckerService(
      customTransport: ({
        required Uri uri,
        required HttpCheckMethod method,
        required Duration timeout,
      }) async {
        return HttpCheckResult(
          url: uri.toString(),
          method: method,
          statusCode: 200,
          reasonPhrase: 'OK',
          category: HttpCheckResult.classifyStatusCode(200),
          responseTimeMs: 42,
          headers: const <String, String>{
            'server': 'cloudflare',
            'content-type': 'text/html',
          },
          checkedAt: DateTime.now(),
        );
      },
    );

    final result = await httpService.checkServerStatus('one.one.one.one');
    expectEqual(result.url, 'https://one.one.one.one', 'Auto-prefix https://');
    expectTrue(result.isReachable, 'Should be reachable');
    expectTrue(result.isHealthy, 'HTTP 200 should be healthy');
    expectEqual(result.category, HttpStatusCategory.success, '2xx category');
  });

  await runTest('HttpCheckerService catches TimeoutException and maps troubleshooting hint', () async {
    final timeoutService = HttpCheckerService(
      customTransport: ({
        required Uri uri,
        required HttpCheckMethod method,
        required Duration timeout,
      }) async {
        throw TimeoutException('Server did not respond in time', timeout);
      },
    );

    final result = await timeoutService.checkServerStatus(
      'https://192.168.88.250',
      timeout: const Duration(seconds: 3),
    );
    expectTrue(!result.isReachable, 'Should not be reachable on timeout');
    expectTrue(result.error != null, 'Error object should be populated');
    expectEqual(
      result.error!.type,
      NetworkErrorType.timeout,
      'Mapped to NetworkErrorType.timeout',
    );
  });

  await runTest('SocketException DNS and Connection Refused mapping', () {
    final dnsError = NetworkDiagnosticError.fromException(
      const SocketException('Failed host lookup: unknown.router.lan'),
      target: 'unknown.router.lan',
    );
    expectEqual(dnsError.type, NetworkErrorType.dnsLookupFailed, 'DNS error type');

    final refusedError = NetworkDiagnosticError.fromException(
      const SocketException('Connection refused'),
      target: '192.168.88.1:8291',
    );
    expectEqual(
      refusedError.type,
      NetworkErrorType.connectionRefused,
      'Connection refused error type',
    );
  });

  stdout.writeln('\n==============================================================');
  stdout.writeln(' Summary: $_passed passed, $_failed failed');
  stdout.writeln('==============================================================');

  if (_failed > 0) {
    exit(1);
  }
}
