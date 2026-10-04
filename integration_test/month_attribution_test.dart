import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:hyper_budget_flutter/main.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the real Pundi app on the Linux desktop and drives it the way a person
/// would: taps the bottom navigation, reads what the screens actually say.
///
/// This is the Flutter equivalent of a Playwright spec. Playwright itself
/// cannot drive a Flutter desktop app — it only speaks CDP to Chromium — so
/// `integration_test` is the correct harness for this target. It exercises the
/// real widget tree on a real display rather than a synthesised test harness.
///
/// The bug under test: a receipt dated 30 Sep but keyed in on 1 Oct used to be
/// counted as October spending, so September read as short and the file's own
/// months disagreed with what Ringkasan showed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Yesterday, so "today" is unambiguous and a receipt from two months back can
  // never coincide with it.
  final today = DateTime.now();
  final lastMonth = DateTime(today.year, today.month - 1);
  final twoMonthsAgo = DateTime(today.year, today.month - 2);

  /// The hero figure exactly as the app prints it, e.g. "Rp -250.000".
  ///
  /// Asserted with an exact match rather than `textContaining` on purpose. The
  /// per-category rows under the hero also print rupiah amounts, and a 500.000
  /// expense split 50/30/20 produces a 250.000 row — a substring check would
  /// then pass or fail for reasons unrelated to month attribution.
  String net(num v) => 'Rp ${NumberFormat('#,##0', 'id_ID').format(v.round())}';

  /// The summary header renders the month upper-cased, e.g. "AGUSTUS 2026".
  String monthLabel(DateTime d) => _expectedMonthLabel(d).toUpperCase();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('a previous-month receipt is counted in that month, on device',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    // An expense whose receipt is last month but which is only keyed in today,
    // and an expense dated two months ago. Totals are deliberately round so the
    // formatted strings are unambiguous.
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc 250000',
      amount: 250000,
      chargedToCategory: allCategoriesLabel,
      receiptDate: DateTime(lastMonth.year, lastMonth.month, 28).millisecondsSinceEpoch,
    );
    repo.recordExpense(
      merchantName: 'Almaz',
      items: '700000',
      amount: 700000,
      chargedToCategory: allCategoriesLabel,
      receiptDate: DateTime(twoMonthsAgo.year, twoMonthsAgo.month, 15).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(PundiApp(budgetRepository: repo));
    await tester.pumpAndSettle();

    // --- Ringkasan: last month must show the 250000 expense -----------------
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan'), findsWidgets,
        reason: 'sanity: we are on the summary tab');

    expect(_visibleMonthLabel(tester), monthLabel(today),
        reason: 'Ringkasan should open on the current month');
    // "Rp 0" is legitimately printed several times — the income hero plus one row
    // per category — so only its presence matters here.
    expect(find.text(net(0)), findsWidgets,
        reason: 'the current month has no records of its own');
    expect(find.text(net(-250000)), findsNothing,
        reason: 'last month spending must not show up in the current month');

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(_visibleMonthLabel(tester), monthLabel(lastMonth),
        reason: 'one chevron back must land on last month');
    expect(find.text(net(-250000)), findsOneWidget,
        reason: 'the 28th-of-last-month expense must appear under last month');
    expect(find.text(net(-700000)), findsNothing,
        reason: 'the two-months-ago expense must not leak into last month');

    // --- Ringkasan: two months back must show the other expense -----------
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(_visibleMonthLabel(tester), monthLabel(twoMonthsAgo));
    expect(find.text(net(-700000)), findsOneWidget);
    expect(find.text(net(-250000)), findsNothing,
        reason: 'last month spending must not leak into two months ago');

    // --- Riwayat groups the same row under its receipt month ----------------
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    // History dates each row by the same effective date Ringkasan sums on, so the
    // 28th shows as "28 Agu", and today's keying time appears on its own line.
    final receiptStamp = _fmtDate(DateTime(lastMonth.year, lastMonth.month, 28));
    expect(find.text(receiptStamp), findsOneWidget,
        reason: 'Riwayat must date the row by its receipt, not by keying time');

    // Both rows were keyed today, so both carry today's date on the second line.
    expect(find.text('Diinput ${_fmtDate(today)}'), findsNWidgets(2),
        reason: 'the keyed-in date is surfaced separately so the two stay legible');
  });

  testWidgets('the all-time total spans every month with records, on device',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    repo.recordExpense(
      merchantName: 'Almaz',
      items: '3000000',
      amount: 3000000,
      chargedToCategory: allCategoriesLabel,
      receiptDate: DateTime(twoMonthsAgo.year, twoMonthsAgo.month, 15).millisecondsSinceEpoch,
    );
    repo.recordExpense(
      merchantName: 'KFC',
      items: '500000',
      amount: 500000,
      chargedToCategory: allCategoriesLabel,
      receiptDate: DateTime(lastMonth.year, lastMonth.month, 28).millisecondsSinceEpoch,
    );

    await tester.pumpWidget(PundiApp(budgetRepository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();

    // Flip to SEMUA and both months must be counted at once.
    await tester.tap(find.text('SEMUA'));
    await tester.pumpAndSettle();

    // Both months must be inside one view: 3.000.000 + 500.000 of spending,
    // zero income, so a net of -3.500.000.
    expect(find.text('SEMUA PERIODE'), findsOneWidget,
        reason: 'the header must say the view is not month-scoped');
    expect(find.text(net(-3500000)), findsOneWidget,
        reason: 'all-time spans months; it is not capped at one month');

    // The month tabs are inert while all-time is selected, so the header must
    // not still claim a single month.
    expect(find.textContaining(RegExp(r'^[A-Z]+ \d{4}$')), findsNothing);
  });
}

/// Reads the month header out of the summary screen, whichever widget renders it.
///
/// The header is the only text on the screen shaped like "BULAN TAHUN", and the
/// screen itself prints it upper-cased, so the comparison is done in the same
/// case the user sees.
String _visibleMonthLabel(WidgetTester tester) {
  final candidates = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => RegExp(r'^[A-Z]+ \d{4}$').hasMatch(s))
      .toList();
  expect(candidates, isNotEmpty, reason: 'expected a "BULAN TAHUN" header');
  return candidates.first;
}

/// Builds the label the app itself would print, e.g. "Agustus 2026".
String _expectedMonthLabel(DateTime d) =>
    '${_monthName(d.month)} ${d.year}';

String _monthName(int m) => const [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ][m - 1];

/// The exact string History prints for a row's date: `DateFormat('dd MMM')`.
String _fmtDate(DateTime d) => DateFormat('dd MMM', 'id_ID').format(d);