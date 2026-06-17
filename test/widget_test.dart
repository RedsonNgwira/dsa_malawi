import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dsa_malawi/main.dart';
import 'package:dsa_malawi/providers/app_state.dart';
import 'package:dsa_malawi/services/connectivity_service.dart';
import 'package:dsa_malawi/services/cloud_backup_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppState()),
          ChangeNotifierProvider(create: (_) => ConnectivityService()),
          ChangeNotifierProvider(create: (_) => CloudBackupService()),
        ],
        child: const DSAApp(),
      ),
    );

    // Verify the navigation bar renders with all four tabs
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Loan Calc'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}
