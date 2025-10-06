// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:m2shelpers/main.dart';

void main() {
  testWidgets('App launches properly', (WidgetTester tester) async {
    await tester.pumpWidget(const M2sTigres());
    expect(find.textContaining('Terransible'), findsWidgets);
  });
}
