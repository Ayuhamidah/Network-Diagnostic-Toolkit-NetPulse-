import 'package:flutter/material.dart';

import 'ui/screens/http_checker_screen.dart';
import 'ui/screens/ping_screen.dart';
import 'ui/screens/subnet_screen.dart';
import 'viewmodels/http_checker_viewmodel.dart';
import 'viewmodels/ping_viewmodel.dart';
import 'viewmodels/subnet_viewmodel.dart';

void main() {
  runApp(const NetworkDiagnosticApp());
}

/// Palet warna khusus tema Network Operations Center (NOC).
class NocColors {
  static const Color background = Color(0xFF0B1120);
  static const Color surface = Color(0xFF151F32);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color border = Color(0xFF334155);
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color emeraldSuccess = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color crimsonError = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
}

class NetworkDiagnosticApp extends StatelessWidget {
  const NetworkDiagnosticApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetPulse — Network Diagnostic Toolkit',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NocColors.background,
        primaryColor: NocColors.cyanAccent,
        colorScheme: const ColorScheme.dark(
          primary: NocColors.cyanAccent,
          secondary: NocColors.emeraldSuccess,
          surface: NocColors.surface,
          error: NocColors.crimsonError,
        ),
        cardColor: NocColors.surface,
        dividerColor: NocColors.border,
        appBarTheme: const AppBarTheme(
          backgroundColor: NocColors.background,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  late final PingViewModel _pingViewModel;
  late final SubnetViewModel _subnetViewModel;
  late final HttpCheckerViewModel _httpViewModel;

  @override
  void initState() {
    super.initState();
    _pingViewModel = PingViewModel();
    _subnetViewModel = SubnetViewModel();
    _httpViewModel = HttpCheckerViewModel();
  }

  @override
  void dispose() {
    _pingViewModel.dispose();
    _subnetViewModel.dispose();
    _httpViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      PingScreen(viewModel: _pingViewModel),
      SubnetScreen(viewModel: _subnetViewModel),
      HttpCheckerScreen(viewModel: _httpViewModel),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NocColors.cyanAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: NocColors.cyanAccent.withOpacity(0.4),
                ),
              ),
              child: const Icon(
                Icons.router_outlined,
                color: NocColors.cyanAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text(
                  'NetPulse Toolkit',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: NocColors.textPrimary,
                  ),
                ),
                Text(
                  'MTCNA / Cisco Field Utility',
                  style: TextStyle(
                    fontSize: 11,
                    color: NocColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: NocColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: NocColors.surface,
          selectedItemColor: NocColors.cyanAccent,
          unselectedItemColor: NocColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.network_ping),
              label: 'Ping & Probe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              label: 'Subnet / CIDR',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.http),
              label: 'HTTP Status',
            ),
          ],
        ),
      ),
    );
  }
}
