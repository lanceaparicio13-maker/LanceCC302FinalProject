import 'package:flutter_test/flutter_test.dart';
import 'package:medbook/main.dart';

void main() {
  testWidgets('MedBook app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MedBookApp());
    await tester.pump();

    expect(find.byType(MedBookApp), findsOneWidget);
  });
}
