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

    // No toggle: the month pill and the chevrons own the header.
    expect(find.text('PER BULAN'), findsNothing);
    expect(find.text('SEMUA'), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsWidgets);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
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

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();

    expect(find.text('SEMUA PERIODE'), findsOneWidget);
    // The real span, not a guess — one month with one record here.
    expect(find.text('1 bulan · 1 transaksi'), findsOneWidget);

    // The parked PER KATEGORI table would show the same period, but it is
    // switched off for now — the header and scope note carry the span.
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

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.text('SEMUA PERIODE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulan ini'));
    await tester.pumpAndSettle();
    expect(find.text('SEMUA PERIODE'), findsNothing);
  });

  testWidgets('an empty history shows no span instead of a fake one',
      (WidgetTester tester) async {
    await pumpSummary(tester);

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();

    // No records => no "0 bulan · 0 transaksi" claim anywhere.
    expect(find.textContaining('transaksi'), findsNothing);
    expect(find.textContaining('bulan ·'), findsNothing);
  });

  // --- the month name is the way into a custom range -----------------------

  /// What the header pill currently claims the period is.
  String labelText(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('periodLabel')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  String monthName(DateTime d) =>
      DateFormat('MMMM yyyy', 'id_ID').format(d).toUpperCase();

  testWidgets('the month name opens the range picker',
      (WidgetTester tester) async {
    await pumpSummary(tester);

    // The corner calendar is gone; the label is the only way in.
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    expect(find.byIcon(Icons.event_available), findsNothing);
    expect(find.text('Rentang periode'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();

    expect(find.text('Rentang periode'), findsOneWidget);
    // Presets stayed inside the sheet rather than going with the chip row, so
    // "last 7 days" still costs one tap.
    expect(find.text('7 hari'), findsOneWidget);
  });

  testWidgets('a preset range replaces the month name and stills the arrows',
      (WidgetTester tester) async {
    await pumpSummary(tester);
    final month = monthName(DateTime.now());
    expect(labelText(tester), month);

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 hari'));
    await tester.pumpAndSettle();

    // The label says what is actually on screen, so a hand-picked span is not
    // mistakable for the month it started in.
    expect(labelText(tester), isNot(month));
    expect(labelText(tester), contains('-'));

    // And the arrows go inert instead of quietly walking a span that is not one
    // month wide.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(labelText(tester), contains('-'),
        reason: 'stepping months under a range would move a span silently');
  });

  testWidgets('the Semua preset means the SEMUA mode, not a 2000-2100 range',
      (WidgetTester tester) async {
    await pumpSummary(tester);
    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();

    // The preset alone: the toggle is gone, so 'Semua' here can only mean
    // the sheet preset.
    expect(find.text('Semua'), findsOneWidget);
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();

    // Taken literally as a range this printed "1 JAN 2000 - 31 DES 2100";
    // the bounds now resolve to the recordings instead.
    expect(find.text('SEMUA PERIODE'), findsOneWidget);
    expect(find.textContaining('2100'), findsNothing);
    expect(labelText(tester), 'SEMUA PERIODE');
  });

  testWidgets('picking Bulan ini hands the chevrons back',
      (WidgetTester tester) async {
    await pumpSummary(tester);

    // Go off to a range first, so returning to a month is a real change.
    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 hari'));
    await tester.pumpAndSettle();
    expect(labelText(tester), contains('-'));

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulan ini'));
    await tester.pumpAndSettle();

    // Back in month mode: the label reads as a month and the arrows work again.
    expect(labelText(tester), monthName(DateTime.now()));

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final previous = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);
    expect(labelText(tester), monthName(previous),
        reason: 'the chevrons must be live again, not inert after a range');
  });

  // --- the transactions behind the figures, on the same screen -------------

  testWidgets('no transaction list sneaks onto the screen, narrowed or not',
      (WidgetTester tester) async {
    repo.recordExpense(
      merchantName: 'Toko A',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    // A viewport tall enough to lay out the whole summary at once, so an
    // absence here cannot just mean "below the fold".
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpSummary(tester);

    // The inline TRANSAKSI list and its "Lihat semua di Riwayat" link are
    // gone with the parked table. Ringkasan is totals and nothing else.
    expect(find.text('TRANSAKSI'), findsNothing);
    expect(find.text('Lihat semua di Riwayat'), findsNothing);
    expect(find.text('Toko A'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('periodLabel')));
    await tester.pumpAndSettle();
    // "7 hari", not "30 hari": a 30-day span ending on the 30th of a 30-day
    // month is exactly that month, which snaps back to month mode and would
    // make this test pass or fail depending on the day it runs.
    await tester.tap(find.text('7 hari'));
    await tester.pumpAndSettle();

    // Even narrowed to a range, the screen stays a summary. 'Lihat semua di
    // Riwayat' existed only as that list's tail.
    expect(find.text('TRANSAKSI'), findsNothing);
    expect(find.text('Toko A'), findsNothing);
    expect(find.text('Lihat semua di Riwayat'), findsNothing);
  });

  testWidgets('category rows are read-only, no narrowing on tap',
      (WidgetTester tester) async {
    repo.recordIncome(amount: 300000, chargedToCategory: 'Seluruhnya');

    // The table can sit below the fold; slivers do not build what is out of
    // view, so lay everything out before aiming at a row.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpSummary(tester);

    // Nothing narrowed, and tapping a row changes nothing: the hero keeps
    // counting the whole receipt and the caption stays period-shaped. The
    // menyaring feature is gone; the table only states balances.
    expect(find.text('Rp 300.000'), findsWidgets);
    await tester.tap(find.text('Bebas'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Rp 300.000'), findsWidgets);
    expect(find.textContaining('Kategori Bebas'), findsNothing);
  });
}