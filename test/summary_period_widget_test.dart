import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/summary_screen.dart';
import 'package:hyper_budget_flutter/state/ledger_filter_controller.dart';
import 'package:hyper_budget_flutter/state/main_tab_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
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

  // --- the calendar button in the header is where the period is set ---------

  testWidgets('the header calendar opens the range picker',
      (WidgetTester tester) async {
    await pumpSummary(tester);

    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(find.text('Rentang periode'), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Rentang periode'), findsOneWidget);
    // The presets moved into the sheet rather than disappearing with the chip
    // row — "last 30 days" should not cost two date picks now.
    expect(find.text('30 hari'), findsOneWidget);
  });

  testWidgets('a preset range from the sheet applies and marks the calendar',
      (WidgetTester tester) async {
    await pumpSummary(tester);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30 hari'));
    await tester.pumpAndSettle();

    // Sheet dismissed and the calendar now carries the "a range is set" state,
    // so a hand-picked period is not mistaken for a stepped month.
    expect(find.text('Rentang periode'), findsNothing);
    expect(find.byIcon(Icons.event_available), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
  });

  testWidgets('the Semua preset means the SEMUA mode, not a 2000-2100 range',
      (WidgetTester tester) async {
    await pumpSummary(tester);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();

    // "Semua" appears twice once the sheet is open: as this preset and as the
    // all-categories chip behind it. The presets are the ones in a Wrap.
    final semuaPreset =
        find.descendant(of: find.byType(Wrap), matching: find.text('Semua'));
    expect(semuaPreset, findsOneWidget);
    await tester.tap(semuaPreset);
    await tester.pumpAndSettle();

    // The header has to say so in the words the toggle uses. Taken literally as
    // a range it printed "1 JAN 2000 - 31 DES 2100" and lit neither half of
    // PER BULAN/SEMUA.
    expect(find.text('SEMUA PERIODE'), findsOneWidget);
    expect(find.textContaining('2100'), findsNothing);
    expect(find.byIcon(Icons.event_available), findsNothing,
        reason: 'all-time is not a custom range, so no range marker');
  });

  testWidgets('picking Bulan ini hands the chevrons back',
      (WidgetTester tester) async {
    await pumpSummary(tester);

    // Go off to a custom range first, so returning to a month is a real change.
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 hari'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.event_available), findsOneWidget);

    // The calendar icon reports that a range is set, so that is the one to press
    // now — reopening the sheet is the only way back to a month.
    await tester.tap(find.byIcon(Icons.event_available));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulan ini'));
    await tester.pumpAndSettle();

    // Back in month mode: the arrows work again and the header reads as a month
    // rather than a span of days.
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(
      find.text(
          DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now()).toUpperCase()),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final previous = DateTime.now().month == 1
        ? DateTime(DateTime.now().year - 1, 12)
        : DateTime(DateTime.now().year, DateTime.now().month - 1);
    expect(
      find.text(
          DateFormat('MMMM yyyy', 'id_ID').format(previous).toUpperCase()),
      findsOneWidget,
      reason: 'the chevrons must be live again, not inert after a range',
    );
  });
}