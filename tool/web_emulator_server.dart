import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lib/core/network_exceptions.dart';
import '../lib/models/http_check_models.dart';
import '../lib/models/ping_models.dart';
import '../lib/services/http_checker_service.dart';
import '../lib/services/ping_service.dart';
import '../lib/services/subnet_calculator_service.dart';

const SubnetCalculatorService _subnetService = SubnetCalculatorService();
const PingService _pingService = PingService();
const HttpCheckerService _httpCheckerService = HttpCheckerService();

Future<void> main(List<String> args) async {
  final int requestedPort = 8080;
  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, requestedPort);
  } catch (_) {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  }

  final String url = 'http://localhost:${server.port}';
  stdout.writeln('==============================================================');
  stdout.writeln(' NetPulse — Dart Web Emulator Server Running');
  stdout.writeln(' URL: $url');
  stdout.writeln('==============================================================');

  if (args.contains('--launch-chrome')) {
    _launchChrome(url);
  }

  await for (final HttpRequest request in server) {
    _handleRequest(request, url);
  }
}

void _launchChrome(String url) {
  final List<String> candidates = <String>[
    r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
  ];

  for (final path in candidates) {
    if (File(path).existsSync()) {
      Process.start(
        path,
        <String>['--app=$url', '--window-size=480,920'],
        mode: ProcessStartMode.detached,
      );
      stdout.writeln('Launched Google Chrome Web Emulator -> $url');
      return;
    }
  }
}

Future<void> _handleRequest(HttpRequest request, String serverBaseUrl) async {
  final response = request.response;
  response.headers.set('Access-Control-Allow-Origin', '*');

  final String path = request.uri.path;
  final Map<String, String> query = request.uri.queryParameters;

  try {
    if (path == '/' || path == '/index.html') {
      final File htmlFile = File('preview/index.html');
      if (await htmlFile.exists()) {
        response.headers.contentType = ContentType.html;
        response.write(await htmlFile.readAsString());
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write('preview/index.html not found');
      }
      await response.close();
      return;
    }

    if (path == '/api/health') {
      _sendJson(response, <String, Object>{
        'status': 'ok',
        'engine': 'Dart ${Platform.version.split(" ").first}',
        'service': 'NetPulse Diagnostic Engine',
      });
      return;
    }

    if (path == '/api/subnet') {
      final String ip = query['ip'] ?? '192.168.88.1';
      final int prefix = int.tryParse(query['prefix'] ?? '24') ?? 24;
      try {
        final info = _subnetService.calculate(ip, overridePrefix: prefix);
        _sendJson(response, <String, Object>{
          'inputIp': info.inputIp,
          'prefixLength': info.prefixLength,
          'networkCidr': info.networkCidr,
          'networkAddress': info.networkAddress,
          'broadcastAddress': info.broadcastAddress,
          'subnetMask': info.subnetMask,
          'wildcardMask': info.wildcardMask,
          'firstUsableHost': info.firstUsableHost,
          'lastUsableHost': info.lastUsableHost,
          'totalAddresses': info.totalAddresses,
          'usableHosts': info.usableHosts,
          'ipClass': info.ipClass,
          'scopeDescription': info.scopeDescription,
          'isPrivateRfc1918': info.isPrivateRfc1918,
          'ciscoOspfSnippet': info.ciscoOspfSnippet,
          'mikrotikAddressSnippet': info.mikrotikAddressSnippet,
        });
      } on NetworkDiagnosticError catch (e) {
        _sendJson(
          response,
          <String, Object>{'error': '${e.title}: ${e.message}'},
          statusCode: HttpStatus.badRequest,
        );
      }
      return;
    }

    if (path == '/api/ping') {
      final String host = query['host'] ?? '127.0.0.1';
      final String modeStr = query['mode'] ?? 'icmp';
      final int port = int.tryParse(query['port'] ?? '8291') ?? 8291;
      final int seq = int.tryParse(query['seq'] ?? '1') ?? 1;
      final PingMode mode =
          modeStr == 'tcpPort' ? PingMode.tcpPort : PingMode.icmp;

      final PingPacketResult pkt = await _pingService
          .startPingStream(
            host: host,
            mode: mode,
            port: port,
            maxCount: 1,
            timeout: const Duration(seconds: 2),
          )
          .first;

      final PingPacketResult adjusted = PingPacketResult(
        sequence: seq,
        host: pkt.host,
        resolvedIp: pkt.resolvedIp,
        mode: pkt.mode,
        port: pkt.port,
        isSuccess: pkt.isSuccess,
        rttMs: pkt.rttMs,
        ttl: pkt.ttl,
        errorMessage: pkt.errorMessage,
        timestamp: pkt.timestamp,
      );

      _sendJson(response, <String, Object?>{
        'sequence': adjusted.sequence,
        'host': adjusted.host,
        'mode': modeStr,
        'port': adjusted.port,
        'isSuccess': adjusted.isSuccess,
        'rttMs': adjusted.rttMs,
        'ttl': adjusted.ttl,
        'errorMessage': adjusted.errorMessage,
        'cliLine': adjusted.toCliLogLine(),
      });
      return;
    }

    if (path == '/api/http-check') {
      final String rawUrl = query['url'] ?? '$serverBaseUrl/api/health';
      final String methodStr = (query['method'] ?? 'HEAD').toUpperCase();
      final int timeoutSec = int.tryParse(query['timeout'] ?? '5') ?? 5;
      final HttpCheckMethod method = methodStr == 'GET'
          ? HttpCheckMethod.get
          : HttpCheckMethod.head;

      final HttpCheckResult res = await _httpCheckerService.checkServerStatus(
        rawUrl,
        method: method,
        timeout: Duration(seconds: timeoutSec.clamp(1, 15)),
      );

      _sendJson(response, <String, Object?>{
        'url': res.url,
        'statusCode': res.statusCode,
        'reasonPhrase': res.reasonPhrase,
        'responseTimeMs': res.responseTimeMs,
        'description': HttpCheckResult.describeStatusCode(res.statusCode),
        'headers': res.headers,
        'errorTitle': res.error?.title,
        'errorMessage': res.error?.message,
        'troubleshootingHint': res.error?.troubleshootingHint,
      });
      return;
    }

    response.statusCode = HttpStatus.notFound;
    response.write('Not Found');
    await response.close();
  } catch (e) {
    _sendJson(
      response,
      <String, Object>{'error': e.toString()},
      statusCode: HttpStatus.internalServerError,
    );
  }
}

Future<void> _sendJson(
  HttpResponse response,
  Map<String, Object?> data, {
  int statusCode = HttpStatus.ok,
}) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(data));
  await response.close();
}
