
import 'package:flutter_test/flutter_test.dart';
import 'package:promptly/main.dart';

void main() {
  testWidgets('App renders Editor Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PromptlyApp());

    // Verify that the title is there
    expect(find.text('Promptly Editor'), findsOneWidget);
  });
}
