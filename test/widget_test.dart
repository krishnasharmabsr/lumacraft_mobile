import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/main.dart';

void main() {
  testWidgets('App load smoke test — splash screen renders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LumaCraftApp());
    await tester.pump();

    // Splash screen should show branded text
    expect(find.text('LumaCraft'), findsOneWidget);
    expect(find.text('VIDEO STUDIO'), findsOneWidget);

    // Pump remaining timers to avoid pending timer errors
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
