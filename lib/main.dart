import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/di/service_locator.dart';
import 'providers/app_state.dart';
import 'services/connectivity_service.dart';
import 'services/cloud_backup_service.dart';
import 'screens/scanner_screen.dart';
import 'screens/loan_calc_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/about_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..initialize()),
        ChangeNotifierProvider(create: (_) => sl<ConnectivityService>()),
        ChangeNotifierProvider(create: (_) => sl<CloudBackupService>()),
        ChangeNotifierProvider(create: (_) => sl<ScannerController>()),
      ],
      child: const DSAApp(),
    ),
  );
}

class DSAApp extends StatelessWidget {
  const DSAApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'DSA Malawi',
      debugShowCheckedModeBanner: false,
      themeMode: appState.initialized ? appState.themeMode : ThemeMode.system,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _screens = const [
    ScannerScreen(), LoanCalcScreen(), DocumentsScreen(), AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: AppTheme.normal,
        switchInCurve: AppTheme.easeOut,
        switchOutCurve: AppTheme.easeInOut,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(_currentIndex), child: _screens[_currentIndex]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        animationDuration: AppTheme.fast,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.document_scanner_outlined), selectedIcon: Icon(Icons.document_scanner), label: 'Scanner'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Loan Calc'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Documents'),
          NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'About'),
        ],
      ),
      bottomSheet: connectivity.initialized && !connectivity.isOnline
          ? Container(
              width: double.infinity, color: Colors.orange.shade800,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.md, vertical: AppTheme.sm - 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.wifi_off, size: 14, color: Colors.white),
                const SizedBox(width: AppTheme.sm),
                const Text('You are offline', style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            )
          : null,
    );
  }
}
