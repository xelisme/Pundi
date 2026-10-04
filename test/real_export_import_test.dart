import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/period_summary.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the user's own export through the real importer, unmodified.
///
/// `test/fixtures/real_export.csv` is a byte-for-byte copy of
/// pundi_20261004_185632.csv, the file that surfaced the month-attribution and
/// note-pollution bugs. Every expected number below is derived from that file
/// by hand (see the per-month table in the accompanying bug report), so this
/// test fails if the attribution rule ever changes shape.
///
/// Real file IO needs [WidgetTester.runAsync] semantics; `flutter test` runs the
/// body on a fake clock where `File.readAsStringSync` would hang. Plain `test()`
/// is used here with the sync API instead, which sidesteps that entirely.
void main() {
  late BudgetRepository repo;
  late String csv;

  setUpAll(() {
    csv = File('test/fixtures/real_export.csv').readAsStringSync();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
  });

  test('every row in the real export survives the import', () {
    expect(repo.importFromCsv(csv), 76);
    expect(repo.lastImportFailedLines, isEmpty,
        reason: 'no row in a file this app wrote should be rejected');
    expect(repo.history, hasLength(76));
  });

  test('type split matches the file: 27 income, 49 expense', () {
    repo.importFromCsv(csv);

    final income =
        repo.history.where((t) => t.type == TransactionType.income).toList();
    final expense =
        repo.history.where((t) => t.type == TransactionType.expense).toList();

    expect(income, hasLength(27));
    expect(expense, hasLength(49));
  });

  test('each month totals to its own receipt dates, not its input dates', () {
    repo.importFromCsv(csv);

    // Hand-checked from the file: the 30-Sep receipts that were keyed in on
    // 1 Oct (Kebab 16000, kfc 22000) are September spending, and the 06-Sep /
    // 02-Sep receipts keyed a day later are September too. October therefore
    // holds only what was genuinely spent in October.
    PeriodSummary at(int m) => calculatePeriodSummary(
          repo.history,
          repo.categories,
          month: DateTime(2026, m),
        );

    expect(at(8).totalIncome, 2453000);
    expect(at(8).totalExpenses, 85000);

    expect(at(9).totalIncome, 1064000);
    expect(at(9).totalExpenses, 721000);

    expect(at(10).totalIncome, 0);
    expect(at(10).totalExpenses, 52000);
  });

  test('the four months sum back to the all-time total', () {
    repo.importFromCsv(csv);

    final all = calculatePeriodSummary(repo.history, repo.categories);
    expect(all.totalIncome, 2453000 + 1064000 + 0);
    expect(all.totalExpenses, 85000 + 721000 + 52000);
    expect(all.netIncome, 2659000);

    var income = 0.0, expense = 0.0;
    for (var m = 1; m <= 12; m++) {
      final s = calculatePeriodSummary(repo.history, repo.categories,
          month: DateTime(2026, m));
      income += s.totalIncome;
      expense += s.totalExpenses;
    }
    expect(income, all.totalIncome,
        reason: 'per-month income must reconcile with all-time income');
    expect(expense, all.totalExpenses,
        reason: 'per-month expense must reconcile with all-time expense');
  });

  test('all-time totals equal the sum of the eight row sums in the file', () {
    repo.importFromCsv(csv);

    // Read straight off the file so the expectation is independent of the
    // per-month numbers asserted above.
    final lines = csv.trim().split('\n').skip(1);
    var expectIncome = 0.0, expectExpense = 0.0;
    for (final line in lines) {
      final parts = line.split(',');
      final amount = double.parse(parts[1]);
      if (parts[2].toLowerCase().contains('pemasukan')) {
        expectIncome += amount;
      } else {
        expectExpense += amount;
      }
    }

    final all = calculatePeriodSummary(repo.history, repo.categories);
    expect(all.totalIncome, expectIncome);
    expect(all.totalExpenses, expectExpense);
    expect(all.netIncome, expectIncome - expectExpense);
  });

  test('no income row carries the amount as a user-visible note', () {
    repo.importFromCsv(csv);

    final incomes =
        repo.history.where((t) => t.type == TransactionType.income).toList();

    for (final income in incomes) {
      expect(income.items, isNot(contains('Pemasukan')),
          reason: 'export marker leaked into the note');
      final asNumber = double.tryParse(income.items.trim().replaceAll(',', ''));
      expect(asNumber == null || (asNumber - income.totalAmount).abs() >= 0.005,
          isTrue,
          reason: 'the amount leaked into the note field: "${income.items}"');
    }
  });

  test('the largest income keeps its own keyed-in instant', () {
    repo.importFromCsv(csv);

    // 2100000 keyed at 03:14:11 on 24 Aug, the single biggest row in the file.
    // Receipt and input dates are identical here, so this only proves the
    // time-of-day survives — the date-separation case is covered above by the
    // 30-Sep receipt keyed on 1 Oct.
    final big = repo.history.firstWhere(
        (t) => t.totalAmount == 2100000 && t.type == TransactionType.income);
    expect(
      DateTime.fromMillisecondsSinceEpoch(big.receiptDate),
      DateTime(2026, 8, 24),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(big.timestamp),
      DateTime(2026, 8, 24, 3, 14, 11),
    );
  });

  test('export then re-import preserves every month total', () {
    repo.importFromCsv(csv);
    final before = calculatePeriodSummary(repo.history, repo.categories);

    SharedPreferences.setMockInitialValues({});
    final second = BudgetRepository();
    second.importFromCsv(repo.exportToCsv());

    final after = calculatePeriodSummary(second.history, second.categories);
    expect(after.totalIncome, before.totalIncome);
    expect(after.totalExpenses, before.totalExpenses);

    for (final month in [8, 9, 10]) {
      final b = calculatePeriodSummary(repo.history, repo.categories,
          month: DateTime(2026, month));
      final a = calculatePeriodSummary(second.history, second.categories,
          month: DateTime(2026, month));
      expect(a.totalExpenses, b.totalExpenses,
          reason: 'month $month expenses must survive a round trip');
      expect(a.totalIncome, b.totalIncome,
          reason: 'month $month income must survive a round trip');
    }
  });
}