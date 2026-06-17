import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dsa_malawi/main.dart';
import 'package:dsa_malawi/providers/app_state.dart';
import 'package:dsa_malawi/services/connectivity_service.dart';
import 'package:dsa_malawi/services/cloud_backup_service.dart';
import 'package:dsa_malawi/features/scanner/providers/scanner_controller.dart';
import 'package:dsa_malawi/services/export_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
          ChangeNotifierProvider(create: (_) => CloudBackupService()),
          ChangeNotifierProvider(create: (_) => ScannerController(
            exportService: ExportService(),
          )),
        ],
        child: const DSAApp(),
      ),
    );

    expect(find.text('Scanner'), findsWidgets);
    expect(find.text('Loan Calc'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
