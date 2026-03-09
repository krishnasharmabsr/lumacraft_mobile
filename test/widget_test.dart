import 'package:flutter_test/flutter_test.dart';
import 'package:zylencut_mobile/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ZylenCutApp());

    // Verify placeholder text is present
    expect(find.text('ZylenCut Studio'), findsOneWidget);
    expect(find.text('V2 Bootstrap Environment'), findsOneWidget);
  });
}
