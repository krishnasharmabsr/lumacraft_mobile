import 'package:flutter_test/flutter_test.dart';
import 'package:lumacraft_mobile/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LumaCraftApp());

    // Verify branded home screen elements
    expect(find.text('LumaCraft'), findsOneWidget);
    expect(find.text('Video Studio'), findsOneWidget);
    expect(find.text('Import Video'), findsOneWidget);
  });
}
