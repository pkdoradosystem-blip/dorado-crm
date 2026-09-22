import 'package:flutter_test/flutter_test.dart';
import 'package:dorado_crm/main.dart';

void main() {
  testWidgets('Dorado CRM starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DoradoCRM());

    expect(find.text('Dorado CRM'), findsWidgets);
  });
}