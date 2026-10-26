import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:hyper_budget_flutter/main.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the real Pundi app on the Linux desktop and pins the boundary between
/// the two tabs.
///
/// Widget tests already cover the filter and the period machine, and the two
/// other specs cover month attribution and the archive. What is only observable
/// on a device is the shell: browsing periods in Ringkasan must never reach
/// across and narrow Riwayat behind the user's back — Riwayat's filter is its
/// own, set from its own bar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  String rp(num v) => 'Rp ${NumberFormat('#,##0', 'id_ID').format(v.round())}';

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('Riwayat is untouched by Ringkasan browsing',
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
    // a tab the user has not opened. It did once: stepping the period here made
    // Riwayat hide the receipt that month_attribution_test expects to find.
    // Switching to Semua really changes Ringkasan's own view first.
    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();

    expect(find.text('SEMUA PERIODE'), findsOneWidget,
        reason: 'Ringkasan must actually be in a different period first');

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
