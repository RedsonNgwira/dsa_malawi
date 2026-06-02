import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_malawi/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DSAApp());
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Loan Calc'), findsOneWidget);
  });
}
