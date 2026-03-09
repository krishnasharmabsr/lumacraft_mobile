import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const LumaCraftApp());

    // Verify placeholder text is present
    expect(find.text('LumaCraft Studio'), findsOneWidget);
    expect(find.text('V2 Bootstrap Environment'), findsOneWidget);
  });
}
