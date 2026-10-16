import 'package:flutter/foundation.dart';

import '../core/network_exceptions.dart';
import '../models/http_check_models.dart';
import '../services/http_checker_service.dart';

/// ViewModel untuk layar pengecekan status server HTTP/HTTPS.
class HttpCheckerViewModel extends ChangeNotifier {
  final HttpCheckerService _service;

  HttpCheckerViewModel({HttpCheckerService? service})
      : _service = service ?? const HttpCheckerService();

  String _urlInput = 'https://one.one.one.one';
  HttpCheckMethod _method = HttpCheckMethod.head;
  int _timeoutSeconds = 5;
  bool _isLoading = false;
  HttpCheckResult? _latestResult;
  NetworkDiagnosticError? _inputError;
  final List<HttpCheckResult> _history = <HttpCheckResult>[];

  String get urlInput => _urlInput;
  HttpCheckMethod get method => _method;
  int get timeoutSeconds => _timeoutSeconds;
  bool get isLoading => _isLoading;
  HttpCheckResult? get latestResult => _latestResult;
  NetworkDiagnosticError? get inputError => _inputError;
  List<HttpCheckResult> get history =>
      List<HttpCheckResult>.unmodifiable(_history);

  static const List<String> presetUrls = <String>[
    'https://one.one.one.one',
    'https://dns.google',
    'https://api.github.com',
    'http://192.168.88.1',
  ];

  void updateUrl(String value) {
    _urlInput = value;
    _inputError = null;
    notifyListeners();
  }

  void setMethod(HttpCheckMethod newMethod) {
    _method = newMethod;
    notifyListeners();
  }

  void setTimeoutSeconds(int seconds) {
    _timeoutSeconds = seconds.clamp(1, 30);
    notifyListeners();
  }

  /// Menjalankan pemeriksaan HTTP secara asynchronous.
  Future<void> runCheck() async {
    if (_isLoading) return;

    _inputError = null;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _service.checkServerStatus(
        _urlInput,
        method: _method,
        timeout: Duration(seconds: _timeoutSeconds),
      );
      _latestResult = result;
      _history.insert(0, result);
      if (_history.length > 10) {
        _history.removeLast();
      }
    } on NetworkDiagnosticError catch (e) {
      _inputError = e;
    } catch (e) {
      _inputError = NetworkDiagnosticError.fromException(e, target: _urlInput);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _history.clear();
    _latestResult = null;
    _inputError = null;
    notifyListeners();
  }
}
