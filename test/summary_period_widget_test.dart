import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/summary_screen.dart';
import 'package:hyper_budget_flutter/state/ledger_filter_controller.dart';
import 'package:hyper_budget_flutter/state/main_tab_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // main.dart calls this before runApp; any widget test that renders a
  // DateFormat('...', 'id_ID') has to do the same or the build throws
  // LocaleDataException.
  setUpAll(() => initializeDateFormatting('id_ID', null));

  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
  });

  Future<void> pumpSummary(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: repo),
          // Ringkasan publishes its selection here for Riwayat to read, and can
          // ask the tab shell to switch screens. main.dart provides both above
          // the shell, so a widget test has to stand them in.
          ChangeNotifierProvider(create: (_) => LedgerFilterController()),
          ChangeNotifierProvider(create: (_) => MainTabController()),
        ],
        child: const MaterialApp(home: SummaryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header starts in per-month mode', (WidgetTester tester) async {
    await pumpSummary(tester);

    expect(find.text('PER BULAN'), findsOneWidget);
    expect(find.text('SEMUA'), findsOneWidget);
    // Not yet accumulated, so the all-time label is absent.
    expect(find.text('SEMUA PERIODE'), findsNothing);
  });

  testWidgets('switching to SEMUA changes the header and reports the span',
      (WidgetTester tester) async {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    await pumpSummary(tester);

    await tester.tap(find.text('SEMUA'));
    await tester.pumpAndSettle();

    expect(find.text('SEMUA PERIODE'), findsOneWidget);
    // The real span, not a guess — one month with one record here.
    expect(find.text('1 bulan · 1 transaksi'), findsOneWidget);

    // The per-category table follows the same period.
    await tester.scrollUntilVisible(
      find.textContaining('Akumulasi semua periode'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Akumulasi semua periode'), findsOneWidget);
  });

  testWidgets('switching back restores the month view',
      (WidgetTester tester) async {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    await pumpSummary(tester);

    await tester.tap(find.text('SEMUA'));
    await tester.pumpAndSettle();
    expect(find.text('SEMUA PERIODE'), findsOneWidget);

    await tester.tap(find.text('PER BULAN'));
    await tester.pumpAndSettle();
    expect(find.text('SEMUA PERIODE'), findsNothing);
  });

  testWidgets('an empty history shows no span instead of a fake one',
      (WidgetTester tester) async {
    await pumpSummary(tester);

    await tester.tap(find.text('SEMUA'));
    await tester.pumpAndSettle();

    // No records => no "0 bulan · 0 transaksi" claim anywhere.
    expect(find.textContaining('transaksi'), findsNothing);
    expect(find.textContaining('bulan ·'), findsNothing);
  });
}