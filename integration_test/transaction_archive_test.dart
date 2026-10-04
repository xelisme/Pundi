import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:hyper_budget_flutter/main.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real app on the Linux desktop: archives a transaction from
/// Riwayat, checks the totals move, then restores it and checks they move back.
///
/// Unit tests can prove the repository maths. Only this proves the screen
/// actually re-reads it — the earlier `context.read`-inside-`build` bug in
/// Pengaturan was invisible to every unit test and obvious the moment a real
/// screen was tapped.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String net(num v) => 'Rp ${NumberFormat('#,##0', 'id_ID').format(v.round())}';

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('archive removes a transaction from the totals, restore puts it back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam 250000',
      amount: 250000,
      chargedToCategory: allCategoriesLabel,
    );

    await tester.pumpWidget(PundiApp(budgetRepository: repo));
    await tester.pumpAndSettle();

    // --- Beranda shows the expense in the overall total --------------------
    await tester.scrollUntilVisible(find.text('TOTAL KESELURUHAN'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(net(-250000)), findsWidgets,
        reason: 'the expense must count before it is archived');

    // --- Riwayat: count is 1 and the row is there --------------------------
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi'), findsOneWidget);

    // --- Archive it from the row menu --------------------------------------
    await tester.tap(find.text('Almaz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan Transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Arsipkan'));
    await tester.pumpAndSettle();

    // Live rows are gone. Riwayat must NOT show the archive — it lives in
    // Pengaturan now, and a leftover section here would mean the move was only
    // half done.
    expect(find.text('0 transaksi'), findsOneWidget,
        reason: 'an archived row must leave the live count');
    expect(find.text('ARSIP TRANSAKSI'), findsNothing,
        reason: 'the archive list belongs to Pengaturan, not Riwayat');

    // --- Beranda total must have moved, not just the row count -------------
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('TOTAL KESELURUHAN'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(net(0)), findsWidgets,
        reason: 'the archived expense must stop counting in the real total');
    expect(find.text(net(-250000)), findsNothing);

    // --- Ringkasan must agree ----------------------------------------------
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.text(net(-250000)), findsNothing,
        reason: 'Ringkasan reads a different list; it must agree with Beranda');
    expect(find.text(net(0)), findsWidgets);

    // --- Restore it, from Pengaturan --------------------------------------
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ARSIP TRANSAKSI'), 200);
    expect(find.text('Tidak dihitung'), findsOneWidget);
    await tester.tap(find.text('PULIHKAN'));
    await tester.pumpAndSettle();

    expect(find.text('ARSIP TRANSAKSI'), findsNothing,
        reason: 'the empty archive section must disappear again');

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi'), findsOneWidget);

    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.text(net(-250000)), findsOneWidget,
        reason: 'restoring must bring the money back into the totals');
  });

  testWidgets('an archived row keeps its own fields and position after restore',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    repo.recordExpense(
        merchantName: 'A', items: 'a', amount: 1000, chargedToCategory: 'Bebas');
    repo.recordExpense(
        merchantName: 'B', items: 'b', amount: 2000, chargedToCategory: 'Bebas');
    repo.recordExpense(
        merchantName: 'C', items: 'c', amount: 3000, chargedToCategory: 'Bebas');

    await tester.pumpWidget(PundiApp(budgetRepository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    // Archive the middle row.
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arsipkan Transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Arsipkan'));
    await tester.pumpAndSettle();

    expect(repo.activeHistory.map((t) => t.merchantName), ['C', 'A']);

    // Restore happens in Pengaturan, not here.
    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ARSIP TRANSAKSI'), 200);
    expect(find.text('B'), findsOneWidget);
    await tester.tap(find.text('PULIHKAN'));
    await tester.pumpAndSettle();

    // Back between C and A, not on top.
    expect(repo.activeHistory.map((t) => t.merchantName), ['C', 'B', 'A']);
    expect(repo.history.first.merchantName, 'C',
        reason: 'restore must not reorder the underlying list');
  });
}