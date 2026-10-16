import 'package:flutter/foundation.dart';

import '../core/network_exceptions.dart';
import '../models/subnet_models.dart';
import '../services/subnet_calculator_service.dart';

/// ViewModel untuk layar Kalkulator Subnet / CIDR menggunakan [ChangeNotifier].
class SubnetViewModel extends ChangeNotifier {
  final SubnetCalculatorService _calculator;

  SubnetViewModel({SubnetCalculatorService? calculator})
      : _calculator = calculator ?? const SubnetCalculatorService() {
    _recalculate();
  }

  String _ipInput = '192.168.88.1';
  int _prefixLength = 24;
  SubnetInfo? _subnetInfo;
  NetworkDiagnosticError? _error;

  String get ipInput => _ipInput;
  int get prefixLength => _prefixLength;
  SubnetInfo? get subnetInfo => _subnetInfo;
  NetworkDiagnosticError? get error => _error;

  void updateIpInput(String newIp) {
    _ipInput = newIp;
    _recalculate();
  }

  void updatePrefixLength(int newPrefix) {
    _prefixLength = newPrefix.clamp(0, 32);
    _recalculate();
  }

  void applyPreset({String? ip, required int prefix}) {
    if (ip != null) {
      _ipInput = ip;
    }
    _prefixLength = prefix.clamp(0, 32);
    _recalculate();
  }

  void _recalculate() {
    try {
      // Jika pengguna mengetikkan notasi CIDR langsung di kolom IP (misal 10.10.20.1/30)
      if (_ipInput.contains('/')) {
        final info = _calculator.calculate(_ipInput);
        _prefixLength = info.prefixLength;
        _subnetInfo = info;
      } else {
        _subnetInfo = _calculator.calculate(
          _ipInput,
          overridePrefix: _prefixLength,
        );
      }
      _error = null;
    } on NetworkDiagnosticError catch (e) {
      _error = e;
    } catch (e) {
      _error = NetworkDiagnosticError.fromException(e, target: _ipInput);
    }
    notifyListeners();
  }
}
