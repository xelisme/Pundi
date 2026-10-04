import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/period_summary.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';

/// Build a record with an explicit timestamp so the month window is testable
/// without reaching into a repository.
TransactionRecord _tx({
  required TransactionType type,
  required double amount,
  required DateTime at,
  String chargedTo = 'Tabungan',
}) {
  final category = AllocationCategory(
    name: chargedTo,
    percentage: 50,
    colorHex: '#10B981',
  );
  return TransactionRecord(
    rawInput: amount.toString(),
    totalAmount: amount,
    splits: [CategorySplitResult(category: category, allocatedAmount: amount)],
    type: type,
    merchantName: type == TransactionType.expense ? 'Toko' : '',
    receiptDate: at.millisecondsSinceEpoch,
    chargedTo: chargedTo,
    allocationSnapshot: const {},
    timestamp: at.millisecondsSinceEpoch,
  );
}

void main() {
  final categories = [
    AllocationCategory(name: 'Tabungan', percentage: 50, colorHex: '#10B981'),
    AllocationCategory(name: 'Bebas', percentage: 20, colorHex: '#F59E0B'),
  ];

  // Three months with activity, deliberately not consecutive.
  final history = [
    _tx(type: TransactionType.income, amount: 100000, at: DateTime(2026, 6, 10)),
    _tx(type: TransactionType.expense, amount: 40000, at: DateTime(2026, 6, 20), chargedTo: 'Bebas'),
    _tx(type: TransactionType.income, amount: 200000, at: DateTime(2026, 8, 5)),
    _tx(type: TransactionType.expense, amount: 70000, at: DateTime(2026, 10, 12), chargedTo: 'Bebas'),
    _tx(type: TransactionType.expense, amount: 30000, at: DateTime(2026, 10, 28), chargedTo: 'Tabungan'),
  ];

  group('single-month period', () {
    test('sums only the records inside that month', () {
      final august = calculatePeriodSummary(
        history,
        categories,
        month: DateTime(2026, 8, 1),
      );

      expect(august.totalIncome, 200000);
      expect(august.totalExpenses, 0);
      expect(august.netIncome, 200000);
      expect(august.recordCount, 1);
      expect(august.monthCount, 1);
    });

    test('a month with no records is empty, not a zero-filled mistake', () {
      final july = calculatePeriodSummary(
        history,
        categories,
        month: DateTime(2026, 7, 1),
      );

      expect(july.hasRecords, false);
      expect(july.totalIncome, 0);
      expect(july.totalExpenses, 0);
      expect(july.netIncome, 0);
      expect(july.monthCount, 0);
    });

    test('October splits correctly across two categories', () {
      final october = calculatePeriodSummary(
        history,
        categories,
        month: DateTime(2026, 10, 1),
      );

      expect(october.totalExpenses, 100000);
      final bebas = october.categoryBalances.firstWhere((b) => b.name == 'Bebas');
      final tabungan = october.categoryBalances.firstWhere((b) => b.name == 'Tabungan');
      expect(bebas.expense, 70000);
      expect(tabungan.expense, 30000);
      expect(bebas.balance, -70000);
      expect(tabungan.balance, -30000);
    });

    test('month boundaries are half-open, so the last day is included', () {
      final lastInstant = DateTime(2026, 6, 30, 23, 59, 59);
      final summary = calculatePeriodSummary(
        [_tx(type: TransactionType.income, amount: 5000, at: lastInstant)],
        categories,
        month: DateTime(2026, 6, 1),
      );
      expect(summary.totalIncome, 5000);
    });

    test('a record one minute into the next month is excluded', () {
      final justAfter = DateTime(2026, 7, 1, 0, 1);
      final summary = calculatePeriodSummary(
        [_tx(type: TransactionType.income, amount: 5000, at: justAfter)],
        categories,
        month: DateTime(2026, 6, 1),
      );
      expect(summary.hasRecords, false);
    });
  });

  group('all-time period', () {
    test('accumulates every month with no ceiling', () {
      final all = calculatePeriodSummary(history, categories);

      expect(all.totalIncome, 300000);
      expect(all.totalExpenses, 140000);
      expect(all.netIncome, 160000);
      expect(all.recordCount, 5);
    });

    test('reports the real number of distinct months covered', () {
      // June, August and October — three months, not "since June".
      expect(calculatePeriodSummary(history, categories).monthCount, 3);
    });

    test('per-category totals span the whole history', () {
      final all = calculatePeriodSummary(history, categories);

      final bebas = all.categoryBalances.firstWhere((b) => b.name == 'Bebas');
      expect(bebas.expense, 110000, reason: '40k in June + 70k in October');
      expect(bebas.income, 0);
      expect(bebas.balance, -110000);

      final tabungan = all.categoryBalances.firstWhere((b) => b.name == 'Tabungan');
      expect(tabungan.income, 300000, reason: '100k in June + 200k in August');
      expect(tabungan.expense, 30000);
      expect(tabungan.balance, 270000);
    });

    test('every category keeps a row even with no activity', () {
      final all = calculatePeriodSummary(
        history,
        [
          ...categories,
          AllocationCategory(name: 'Kosong', percentage: 30, colorHex: '#123456'),
        ],
      );
      final kosong = all.categoryBalances.firstWhere((b) => b.name == 'Kosong');
      expect(kosong.isEmpty, true);
      expect(kosong.balance, 0);
      // Present, so the table does not reflow when money finally lands there.
      expect(all.categoryBalances.length, 3);
    });

    test('the all-time net equals the sum of the per-month nets', () {
      final months = <String>{};
      for (final record in history) {
        final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
        months.add('${date.year}-${date.month}');
      }

      var summed = 0;
      for (final key in months) {
        final parts = key.split('-');
        summed += calculatePeriodSummary(
          history,
          categories,
          month: DateTime(int.parse(parts[0]), int.parse(parts[1]), 1),
        ).netIncome;
      }

      expect(summed, calculatePeriodSummary(history, categories).netIncome);
    });

    test('an empty history yields an empty, non-negative summary', () {
      final none = calculatePeriodSummary([], categories);
      expect(none.hasRecords, false);
      expect(none.netIncome, 0);
      expect(none.categoryBalances.length, 2);
      expect(none.categoryBalances.every((b) => b.isEmpty), true);
    });

    test('a transaction on 31 December is not dropped by a year boundary', () {
      final newYearsEve =
          _tx(type: TransactionType.income, amount: 999, at: DateTime(2025, 12, 31, 22, 0));
      final all = calculatePeriodSummary([newYearsEve], categories);
      expect(all.totalIncome, 999);
      expect(all.monthCount, 1);
    });
  });

  test('an archived category still reports its historical money', () {
    final archived = [
      AllocationCategory(
        name: 'Bebas',
        percentage: 20,
        colorHex: '#F59E0B',
        isActive: false,
        isArchived: true,
      ),
    ];

    final all = calculatePeriodSummary(
      [
        _tx(type: TransactionType.expense, amount: 40000,
            at: DateTime(2026, 6, 20), chargedTo: 'Bebas'),
      ],
      archived,
    );

    final bebas = all.categoryBalances.first;
    expect(bebas.expense, 40000, reason: 'archived money must stay visible');
    expect(bebas.balance, -40000);
    expect(bebas.isActive, false);
    expect(bebas.isArchived, true);
  });

  test('income and expense breakdown maps follow the splits', () {
    final all = calculatePeriodSummary(history, categories);
    expect(all.incomeBreakdown['Tabungan'], 300000);
    expect(all.expenseBreakdown['Bebas'], 110000);
    expect(all.expenseBreakdown['Tabungan'], 30000);
  });
}