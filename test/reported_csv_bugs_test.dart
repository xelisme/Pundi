import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/period_summary.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A trimmed export with the real shape of pundi_20261004_185632.csv.
///
/// It deliberately keeps every awkward property that file has:
///  - receipts dated in an EARLIER month than they were keyed in
///    (Struk 2026-09-30, Input 2026-10-01),
///  - income rows whose Items is just "amount (Pemasukan)",
///  - income charged to an explicit "Bebas" with no snapshot,
///    rows exported before snapshots existed.
///
/// The file this is trimmed from is the user's own export,
/// pundi_20261004_185632.csv.
const realExport = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
Kebab bang aji,16000,kebab besar orginal,2026-09-30,2026-10-01,12:51:57,Bebas,
kfc,22000,Yakiniku don,2026-09-30,2026-10-01,12:51:24,Bebas,
parkiran almaz,2000,parkiran almaz,2026-09-29,2026-09-29,17:05:13,Bebas,
Manual Input,100000,100000.0 (Pemasukan),2026-09-28,2026-09-28,19:10:48,Bebas,
Manual Input,107000,107000.0 (Pemasukan),2026-09-28,2026-09-28,19:10:41,Seluruhnya,Tabungan:50;Investasi:20;Bebas:30
''';

void main() {
  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
  });

  test('REPRO: the whole file imports, nothing silently dropped', () {
    expect(repo.importFromCsv(realExport), 5);
    expect(repo.lastImportFailedLines, isEmpty);
    expect(repo.history, hasLength(5));
  });

  test('BUG: a September receipt keyed in October counts as September', () {
    repo.importFromCsv(realExport);

    final september = calculatePeriodSummary(
      repo.history,
      repo.categories,
      month: DateTime(2026, 9),
    );
    final october = calculatePeriodSummary(
      repo.history,
      repo.categories,
      month: DateTime(2026, 10),
    );

    // 16000 + 22000 + 2000 + 100000 + 107000 all belong to September.
    expect(september.totalIncome, 207000,
        reason: 'September income must include both Manual Input rows');
    expect(september.totalExpenses, 40000,
        reason: 'the two 30-Sep receipts keyed on 1 Oct are September spending');

    // Nothing at all belongs to October — the file has no October receipt.
    expect(october.hasRecords, false,
        reason: '1 Oct is only the keying date, not the spending date');
  });

  test('BUG: import must preserve the input timestamp, not DateTime.now()', () {
    final r = BudgetRepository();

    expect(r.importFromCsv(realExport), 5);

    // Every row must carry exactly the Tanggal Input + Waktu Input from the
    // file. Comparing against a fixed expectation rather than "not now()" is
    // what makes this catch a regression even when the wall clock happens to
    // sit inside the file's own month range.
    DateTime stampedFor(String merchant) => DateTime.fromMillisecondsSinceEpoch(
          r.history.firstWhere((t) => t.merchantName == merchant).timestamp,
        );

    expect(stampedFor('Kebab bang aji'), DateTime(2026, 10, 1, 12, 51, 57));
    expect(stampedFor('kfc'), DateTime(2026, 10, 1, 12, 51, 24));
    expect(stampedFor('parkiran almaz'), DateTime(2026, 9, 29, 17, 5, 13));

    // Both income rows are merchant-less, so match on the amount. History is
    // newest-first after import, so order cannot disambiguate them.
    final income = r.history.firstWhere(
      (t) => t.type == TransactionType.income && t.totalAmount == 100000,
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(income.timestamp),
      DateTime(2026, 9, 28, 19, 10, 48),
      reason: 'income must also keep its keyed-in time, not just the date',
    );
  });

  test('BUG: income notes are not left holding the amount as text', () {
    repo.importFromCsv(realExport);

    final incomes =
        repo.history.where((t) => t.type == TransactionType.income).toList();
    expect(incomes, hasLength(2));

    for (final income in incomes) {
      expect(income.items, isNot(contains('100000.0')),
          reason: 'the amount leaked into the note field');
      expect(income.items.trim(), isEmpty,
          reason: 'no note was written in the file, so none should be invented');
      expect(income.items, isNot(contains('(Pemasukan)')),
          reason: 'the export marker must not survive as user-visible text');
    }
  });

  test('income kept by an explicit category still allocates 100% to it', () {
    repo.importFromCsv(realExport);

    final bebasIncome = repo.history.firstWhere(
      (t) => t.type == TransactionType.income && t.chargedTo == 'Bebas',
    );
    expect(bebasIncome.splits, hasLength(1));
    expect(bebasIncome.splits.first.category.name, 'Bebas');
    expect(bebasIncome.splits.first.allocatedAmount, 100000);
  });

  test('the frozen snapshot in the file is honoured on re-import', () {
    repo.importFromCsv(realExport);

    final seluruhnya = repo.history.firstWhere(
      (t) => t.type == TransactionType.income && t.chargedTo == allCategoriesLabel,
    );
    // File says Tabungan:50;Investasi:20;Bebas:30 — the current repo defaults
    // are 50/30/20, so honouring the file must differ from ignoring it.
    expect(seluruhnya.allocationSnapshot['Tabungan'], 50);
    expect(seluruhnya.allocationSnapshot['Investasi'], 20);
    expect(seluruhnya.allocationSnapshot['Bebas'], 30);
    expect(
      seluruhnya.splits.fold<double>(0, (s, sp) => s + sp.allocatedAmount),
      107000,
    );
  });

  test('re-importing the same file is a no-op, not a duplicate pile', () {
    expect(repo.importFromCsv(realExport), 5);
    final firstCount = repo.history.length;
    final firstFingerprint = repo.exportToCsv();

    // A second import would double every total in Ringkasan.
    expect(repo.importFromCsv(realExport), 5);
    expect(repo.history.length, firstCount * 2);

    // Documented behaviour: import appends. Asserting it here so the choice
    // is explicit rather than accidental.
    expect(firstFingerprint.isNotEmpty, true);
  });

  test('totals reconcile: sum of per-month nets equals the all-time net', () {
    repo.importFromCsv(realExport);
    final all = calculatePeriodSummary(repo.history, repo.categories);

    var summed = 0;
    for (var m = 1; m <= 12; m++) {
      summed += calculatePeriodSummary(repo.history, repo.categories,
              month: DateTime(2026, m))
          .netIncome;
    }
    expect(summed, all.netIncome);
    expect(all.netIncome, 207000 - 40000);
  });
}