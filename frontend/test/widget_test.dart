import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App renders splash screen branding', (WidgetTester tester) async {
    await tester.pumpWidget(const BusinessCardScannerApp());
    expect(find.text('CardScanner Pro'), findsOneWidget);
    expect(find.text('Smart Business Card Scanner & Contact CRM'), findsOneWidget);
  });
}
