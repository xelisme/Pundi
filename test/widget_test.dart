import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetAIApp());
    expect(find.text('BudgetAI'), findsOneWidget);
  });
}
