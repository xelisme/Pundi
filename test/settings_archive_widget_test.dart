import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/settings_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
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
    expect(find.text('ARSIP KATEGORI'), findsNothing);

    // Stage 1: soft-delete -> nonaktif section appears.
    repo.deleteCategory(repo.categories.firstWhere((c) => c.name == 'Bebas').id);
    await tester.pumpAndSettle();
    expect(find.text('KATEGORI NONAKTIF'), findsOneWidget);
    expect(find.text('ARSIP KATEGORI'), findsNothing);
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
    expect(find.text('ARSIP KATEGORI'), findsOneWidget);
    expect(find.text('KATEGORI NONAKTIF'), findsNothing);
    expect(find.text('PULIHKAN'), findsOneWidget);

    // Pull it back out of the archive -> gone.
    repo.restoreCategory(beb);
    await tester.pumpAndSettle();
    expect(find.text('ARSIP KATEGORI'), findsNothing);
    expect(
        repo.categories.firstWhere((c) => c.name == 'Bebas').isActive,
        true);
  });

  testWidgets('the transaction archive lives in Pengaturan and restores in place',
      (WidgetTester tester) async {
    // The card renders DateFormat(..., 'id_ID'), which needs locale data
    // initialised before the first pump or it throws.
    await initializeDateFormatting('id_ID', null);

    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 700000,
      chargedToCategory: 'Bebas',
    );
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc',
      amount: 300000,
      chargedToCategory: 'Bebas',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing archived yet: the section must not exist at all, not sit there
    // empty.
    expect(find.text('ARSIP TRANSAKSI'), findsNothing);

    final kfc = repo.history.firstWhere((t) => t.merchantName == 'KFC');
    repo.archiveTransaction(kfc.id);
    await tester.pumpAndSettle();

    expect(find.text('ARSIP TRANSAKSI'), findsOneWidget);
    expect(find.text('Tidak dihitung'), findsOneWidget);
    expect(find.text('KFC'), findsOneWidget);
    expect(find.text('Almaz'), findsNothing,
        reason: 'only the archived row belongs in the archive');
    // 700k/300k never collide with a category split, so an exact match here is
    // the amount and not a coincidence.
    expect(find.text('Rp 300.000'), findsOneWidget);

    // Restore from Pengaturan.
    await tester.tap(find.text('PULIHKAN'));
    await tester.pumpAndSettle();

    expect(find.text('ARSIP TRANSAKSI'), findsNothing,
        reason: 'the section must disappear again once empty');
    expect(repo.archivedHistory, isEmpty);
    expect(repo.activeHistory, hasLength(2));
    expect(repo.activeHistory.first.merchantName, 'KFC',
        reason: 'KFC returns to the top, its original slot in a newest-first list');
  });

  testWidgets('both archives render together and stay distinguishable',
      (WidgetTester tester) async {
    // Two things both wanting to be called "ARSIP" is the whole reason the
    // category card was renamed. If these ever collapse back into one label,
    // this test fails.
    await initializeDateFormatting('id_ID', null);

    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    // Charged to Tabungan, not Bebas: archiving a category that still has
    // transactions routes through a reassign dialog instead, which is not what
    // this test is about.
    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 700000,
      chargedToCategory: 'Tabungan',
    );
    repo.archiveTransaction(repo.history.single.id);
    repo.archiveCategory(
        repo.categories.firstWhere((c) => c.name == 'Bebas').id);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ARSIP KATEGORI'), findsOneWidget);
    expect(find.text('ARSIP TRANSAKSI'), findsOneWidget);
    expect(find.text('PULIHKAN'), findsNWidgets(2));
    expect(find.text('Bebas'), findsWidgets);
    expect(find.text('Almaz'), findsOneWidget);
  });
}
