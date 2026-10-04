import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:hyper_budget_flutter/main.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the real Pundi app on the Linux desktop and walks the path a person
/// takes to answer "how much went to this category, and which transactions were
/// it?".
///
/// Widget tests already cover the filter, and the two existing specs cover month
/// attribution and the archive. What is only observable on a device is the join
/// between them: Ringkasan states a total, the link carries that exact selection
/// across the tab shell, and Riwayat arrives already narrowed — with the list
/// adding up to the figure that was tapped.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String rp(num v) => 'Rp ${NumberFormat('#,##0', 'id_ID').format(v.round())}';

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets(
      'a category total hands Riwayat the same slice, showing that category\'s share',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    // One shared income so the category view has to divide it: 600.000 split
    // 50/30/20 gives Investasi a 180.000 share of a 600.000 receipt. Plus an
    // expense that belongs to another category and must not follow it across.
    repo.recordIncome(
      amount: 600000,
      chargedToCategory: allCategoriesLabel,
      notes: 'Gajian',
    );
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 50000,
      chargedToCategory: 'Bebas',
    );

    await tester.pumpWidget(PundiApp(budgetRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();

    // Pick the Investments pocket. The name appears twice on screen — once as a
    // filter chip, once as a table row — and the filter section is built first,
    // so the first match is the chip.
    await tester.tap(find.text('Investasi').first);
    await tester.pumpAndSettle();

    // The hero is now about that pocket alone: 180.000 in, nothing out. It shows
    // three times — the Sisa Bersih hero, the Pemasukan metric, and the
    // Investments row's Sisa — and all three are correct at that figure. The
    // claim worth pinning is the one below: the full receipt must not appear.
    expect(find.text(rp(180000)), findsWidgets);
    expect(find.text(rp(600000)), findsNothing,
        reason: 'the full receipt must not stand in for the category share');

    // The link counts what actually matches, which is one row: the shared
    // income. The Bebas expense is not in this pocket.
    await tester.scrollUntilVisible(
      find.textContaining('Lihat'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Lihat'));
    await tester.pumpAndSettle();

    // Arrived in Riwayat, already narrowed, and it says so. Both axes come
    // across, because that is what Ringkasan was showing: the Investments pocket
    // within the selected month, not the pocket over all time.
    expect(find.textContaining('Investasi ·'), findsOneWidget);
    expect(find.textContaining('bagian Investasi'), findsOneWidget);

    // The row carries the category's share, which is what makes the list add up
    // to the total that was tapped — and the full receipt must be gone.
    expect(find.text(rp(180000)), findsOneWidget);
    expect(find.text(rp(600000)), findsNothing,
        reason: 'a shared row must not show its full amount under one category');

    // Clearing puts the whole ledger back, the other expense included.
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Kategori Investasi'), findsNothing);
    expect(find.text(rp(600000)), findsOneWidget);
    expect(find.text(rp(50000)), findsOneWidget);
  });

  testWidgets('Riwayat is untouched by Ringkasan browsing unless it is asked for',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 75000,
      chargedToCategory: 'Bebas',
    );

    await tester.pumpWidget(PundiApp(budgetRepository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();

    // Browsing periods on Ringkasan must not reach across the shell and narrow
    // a tab the user has not opened. It did once: stepping back a month here made
    // Riwayat hide the receipt that month_attribution_test expects to find.
    await tester.tap(find.text('Bebas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEMUA'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    // No filter bar, and nothing in the list removed. Ringkasan browsing must not
    // reach across the shell and narrow a tab the user never asked to narrow.
    expect(find.text('Hapus'), findsNothing,
        reason: 'Ringkasan browsing must not filter Riwayat behind the user');
    expect(find.text('1 transaksi'), findsOneWidget);
    expect(find.text(rp(75000)), findsOneWidget);
  });
}