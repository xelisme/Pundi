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

  // --- the transactions behind the figures, on the same screen -------------

  /// A viewport tall enough to lay out the whole summary at once.
  ///
  /// The default 800x600 surface puts the inline rows below the fold, and
  /// slivers do not build what is out of view — so "this row is not shown" and
  /// "this row was never laid out" would be indistinguishable, and every
  /// absence assertion below would pass for the wrong reason.
  Future<void> pumpSummaryTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpSummary(tester);
  }

  int dayMs(int day) =>
      DateTime(DateTime.now().year, DateTime.now().month, day)
          .millisecondsSinceEpoch;

  testWidgets('picking a category puts its rows on this screen',
      (WidgetTester tester) async {
    repo.recordExpense(
      merchantName: 'Toko A',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
      receiptDate: dayMs(1),
    );
    repo.recordExpense(
      merchantName: 'Toko B',
      items: 'Barang',
      amount: 200000,
      chargedToCategory: 'Bebas',
      receiptDate: dayMs(2),
    );
    repo.recordExpense(
      merchantName: 'Toko C',
      items: 'Barang',
      amount: 300000,
      chargedToCategory: 'Tabungan',
      receiptDate: dayMs(3),
    );
    await pumpSummaryTall(tester);

    // The default month is not a selection, so nothing opens uninvited.
    expect(find.text('TRANSAKSI'), findsNothing);

    await tester.tap(find.text('Bebas').first);
    await tester.pumpAndSettle();

    // One tap. The rows behind the figure are here, not behind a second one.
    expect(find.text('TRANSAKSI'), findsOneWidget);
    expect(find.text('Toko A'), findsOneWidget);
    expect(find.text('Toko B'), findsOneWidget);
    // The other pocket stays out of the narrowed view.
    expect(find.text('Toko C'), findsNothing);
  });

  testWidgets('a long category stops at five rows and hands over',
      (WidgetTester tester) async {
    for (var day = 1; day <= 7; day++) {
      repo.recordExpense(
        merchantName: 'Toko $day',
        items: 'Barang',
        amount: 100000,
        chargedToCategory: 'Bebas',
        receiptDate: dayMs(day),
      );
    }
    await pumpSummaryTall(tester);
    await tester.tap(find.text('Bebas').first);
    await tester.pumpAndSettle();

    // Newest first: days 7..3 fit, days 2 and 1 do not.
    expect(find.text('Toko 7'), findsOneWidget);
    expect(find.text('Toko 3'), findsOneWidget);
    expect(find.text('Toko 2'), findsNothing);
    expect(find.text('Toko 1'), findsNothing);

    // The caption still reports all seven, not the five on screen, and the link
    // below is what makes reporting seven honest.
    expect(find.textContaining('7 transaksi'), findsOneWidget);
    expect(find.text('Lihat semua di Riwayat'), findsOneWidget);
  });

  testWidgets('a picked range surfaces the rows too',
      (WidgetTester tester) async {
    repo.recordExpense(
      merchantName: 'Toko A',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    await pumpSummaryTall(tester);
    expect(find.text('TRANSAKSI'), findsNothing);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 hari'));
    await tester.pumpAndSettle();

    // No category was chosen, yet the rows are here. Narrowing the period is the
    // same request as narrowing the category, so it gets the same answer.
    expect(find.text('TRANSAKSI'), findsOneWidget);
    expect(find.text('Toko A'), findsOneWidget);
  });

  testWidgets('inline amounts are the attributed share, not the whole receipt',
      (WidgetTester tester) async {
    // One shared "Seluruhnya" income. The totals, the per-category table and
    // these rows must all agree on what Bebas is worth; showing the full receipt
    // here would contradict both.
    repo.recordIncome(amount: 300000, chargedToCategory: 'Seluruhnya');
    await pumpSummaryTall(tester);
    await tester.tap(find.text('Bebas').first);
    await tester.pumpAndSettle();

    expect(find.text('TRANSAKSI'), findsOneWidget);
    // Bebas is 20% of the frozen 50/30/20 split, so 300.000 contributes 60.000
    // to it. Printing the whole receipt would contradict both the total above
    // and the per-category table, and would make the two look broken.
    expect(find.text('+Rp 60.000'), findsOneWidget);
    expect(find.text('+Rp 300.000'), findsNothing);
    // The section says so out loud, since the row is otherwise surprising.
    expect(find.text('Nominal mengikuti bagian Bebas saja.'), findsOneWidget);
  });
}