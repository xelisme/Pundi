import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Symbol safety of the export/import loop: spaces, commas, quotes, embedded
/// newlines, percent/colon/semicolon inside category names, decimal
/// percentages. Every hole here once silently bent money on a round-trip.
void main() {
  // The wallet needs room for the pathological pockets: shrink the defaults,
  // then add categories that violate every CSV/snapshot delimiter.
  Future<BudgetRepository> buildUglyRepo() async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();

    final bebas = repo.activeCategories.firstWhere((c) => c.name == 'Bebas');
    final investasi = repo.activeCategories.firstWhere(
      (c) => c.name == 'Investasi',
    );
    repo.updateCategory(bebas.id, bebas.copyWith(percentage: 5));
    repo.updateCategory(investasi.id, investasi.copyWith(percentage: 25));

    void add(String name, double pct) => repo.addCategory(
      AllocationCategory(name: name, percentage: pct, colorHex: '#888888'),
    );

    add('A, B', 5); // comma -> the CSV cell must quote itself
    add('a:b', 5); // colon -> the snapshot name/pct separator
    add('a;b', 5); // semicolon -> the snapshot pair separator
    add('Diskon 50%', 5); // percent -> the snapshot escape marker itself
    return repo;
  }

  Future<BudgetRepository> buildFreshSameShape() async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();
    final bebas = repo.activeCategories.firstWhere((c) => c.name == 'Bebas');
    final investasi = repo.activeCategories.firstWhere(
      (c) => c.name == 'Investasi',
    );
    repo.updateCategory(bebas.id, bebas.copyWith(percentage: 5));
    repo.updateCategory(investasi.id, investasi.copyWith(percentage: 25));
    void add(String name, double pct) => repo.addCategory(
      AllocationCategory(name: name, percentage: pct, colorHex: '#888888'),
    );
    add('A, B', 5);
    add('a:b', 5);
    add('a;b', 5);
    add('Diskon 50%', 5);
    return repo;
  }

  test(
    'full round-trip survives delimiters, line breaks and decimal percent',
    () async {
      final repo = await buildUglyRepo();

      // A shared receipt across every pathological pocket, with symbols all
      // over the free-text columns.
      repo.recordExpense(
        merchantName: 'Toko "Spesial", kedai',
        items: 'Ayam, nasi\ndan sambal',
        amount: 100000,
        chargedToCategory: allCategoriesLabel,
      );
      repo.recordIncome(
        amount: 700000,
        chargedToCategory: allCategoriesLabel,
        notes: 'Hadiah ulangtahun "besar", akhirnya',
      );

      final exported = repo.exportToCsv();

      final fresh = await buildFreshSameShape();
      final imported = fresh.importFromCsv(exported);
      expect(imported, 2, reason: 'no row may be dropped by the symbols');
      expect(fresh.lastImportFailedLines, isEmpty);

      double close(Map<String, double> a, Map<String, double> b) {
        final keys = {...a.keys, ...b.keys};
        for (final k in keys) {
          final x = a[k] ?? double.nan;
          final y = b[k] ?? double.nan;
          if ((x - y).abs() > 1e-6) return x - y;
        }
        return 0;
      }

      for (final original in repo.history) {
        final back = fresh.history.firstWhere(
          (t) =>
              t.totalAmount == original.totalAmount &&
              t.type == original.type &&
              t.items == original.items &&
              t.merchantName == original.merchantName,
        );
        // The allocation snapshot: percent kept with its decimals, names kept
        // with their ':' ';' '%' characters.
        expect(
          close(back.allocationSnapshot, original.allocationSnapshot),
          0,
          reason: 'snapshot must round-trip exactly: ${original.chargedTo}',
        );
        // Money fully allocated, in the same pockets as before.
        final sum = back.splits.fold<double>(
          0,
          (s, sp) => s + sp.allocatedAmount,
        );
        expect(sum, original.totalAmount, reason: 'money is never lost');
        expect(back.chargedTo, original.chargedTo);
        expect(back.isArchived, isFalse);
      }
    },
  );

  test(
    'an explicit category whose name holds a comma routes 100% to it',
    () async {
      final repo = await buildUglyRepo();
      repo.recordExpense(
        merchantName: 'Warung',
        items: 'Bumbu',
        amount: 30000,
        chargedToCategory: 'A, B',
      );
      final exported = repo.exportToCsv();

      final fresh = await buildFreshSameShape();
      expect(fresh.importFromCsv(exported), 1);
      expect(fresh.lastImportFailedLines, isEmpty);

      final back = fresh.history.first;
      expect(back.chargedTo, 'A, B');
      // Explicit label -> the whole amount goes to that pocket alone.
      expect(back.splits.single.category.name, 'A, B');
      expect(back.splits.single.allocatedAmount, 30000);
    },
  );

  test(
    'legacy exports (raw names, integer percents) still import unchanged',
    () async {
      final repo = await buildFreshSameShape();
      // Hand-written in the pre-fix format: names un-escaped, snapshot kept to
      // integer percentages, no metode/arsip columns at all.
      final legacy = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
"Theo: warung tua",15000,"Kopi, roti",2026-06-19,2026-08-22,00:25:41,Bebas,
Toko Biasa,10000,Uang tunai,2026-06-20,2026-08-22,01:00:00,Seluruhnya,Tabungan:50;Investasi:25;Bebas:5
''';
      expect(repo.importFromCsv(legacy), 2);
      expect(repo.lastImportFailedLines, isEmpty);

      // Row 1: explicit Bebas, merchant name kept with its ':'.
      final bebasRow = repo.history.firstWhere((t) => t.chargedTo == 'Bebas');
      expect(bebasRow.merchantName, 'Theo: warung tua');
      expect(bebasRow.splits.single.category.name, 'Bebas');
      expect(bebasRow.splits.single.allocatedAmount, 15000);

      // Row 2: legacy snapshot splits the whole amount, money complete.
      final shared = repo.history.firstWhere(
        (t) => t.type == TransactionType.income,
      );
      final sum = shared.splits.fold<double>(
        0,
        (s, sp) => s + sp.allocatedAmount,
      );
      expect(sum, 10000);
      expect(shared.allocationSnapshot['Tabungan'], 50);
      expect(shared.allocationSnapshot['Investasi'], 25);
      expect(shared.allocationSnapshot['Bebas'], 5);
    },
  );

  test('decimal percentages survive the snapshot round-trip', () async {
    final repo = await buildUglyRepo();
    // Make room, then rebalance to decimals: shrink 'A, B' first, then
    // Tabungan 50.34 + Bebas 5.66, so non-integer percents are involved.
    final ab = repo.activeCategories.firstWhere((c) => c.name == 'A, B');
    repo.updateCategory(ab.id, ab.copyWith(percentage: 4));
    final t = repo.activeCategories.firstWhere((c) => c.name == 'Tabungan');
    repo.updateCategory(t.id, t.copyWith(percentage: 50.34));
    final b = repo.activeCategories.firstWhere((c) => c.name == 'Bebas');
    repo.updateCategory(b.id, b.copyWith(percentage: 5.66));

    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 990000,
      chargedToCategory: allCategoriesLabel,
    );
    final exported = repo.exportToCsv();
    expect(
      exported,
      contains('Tabungan:50.34'),
      reason: 'the percent must not be truncated to an int',
    );

    final fresh = await buildFreshSameShape();
    // The fresh shape has the old integer percents; the snapshot alone must
    // still drive the split with the decimal figures.
    fresh.importFromCsv(exported);
    final back = fresh.history.first;
    final sum = back.splits.fold<double>(0, (s, sp) => s + sp.allocatedAmount);
    expect(sum, 990000);
    expect(back.allocationSnapshot['Tabungan']!, closeTo(50.34, 1e-6));
    expect(back.allocationSnapshot['Bebas']!, closeTo(5.66, 1e-6));
  });
}
