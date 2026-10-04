import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('recovery sections appear + disappear live',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('KATEGORI NONAKTIF'), findsNothing);
    expect(find.text('ARSIP'), findsNothing);

    // Stage 1: soft-delete -> nonaktif section appears.
    repo.deleteCategory(repo.categories.firstWhere((c) => c.name == 'Bebas').id);
    await tester.pumpAndSettle();
    expect(find.text('KATEGORI NONAKTIF'), findsOneWidget);
    expect(find.text('ARSIP'), findsNothing);
    expect(find.text('PULIHKAN'), findsOneWidget);

    // Restore it -> section disappears again.
    expect(
        repo.restoreCategory(
            repo.categories.firstWhere((c) => c.name == 'Bebas').id),
        true);
    await tester.pumpAndSettle();
    expect(find.text('KATEGORI NONAKTIF'), findsNothing);

    // Stage 2: archive (no history, so no reassign needed) -> Arsip appears.
    final beb = repo.categories.firstWhere((c) => c.name == 'Bebas').id;
    repo.archiveCategory(beb);
    await tester.pumpAndSettle();
    expect(find.text('ARSIP'), findsOneWidget);
    expect(find.text('KATEGORI NONAKTIF'), findsNothing);
    expect(find.text('PULIHKAN'), findsOneWidget);

    // Pull it back out of the archive -> gone.
    repo.restoreCategory(beb);
    await tester.pumpAndSettle();
    expect(find.text('ARSIP'), findsNothing);
    expect(
        repo.categories.firstWhere((c) => c.name == 'Bebas').isActive,
        true);
  });
}
