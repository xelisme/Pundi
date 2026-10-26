import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RFC 4180 CSV parsing (csv package)', () {
    test('embedded newline inside quoted field keeps row intact', () {
      // A quoted "Items" field that spans two physical lines.
      final csv = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
"Toko A",10000,"Baris 1
Baris 2 masih sama item",2026-06-19,2026-08-22,00:25:41,Bebas,
''';
      final rows = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csv.trim());

      // Header + 1 data row, NOT 2 rows.
      expect(rows.length, 2);
      expect(rows[1][2], 'Baris 1\nBaris 2 masih sama item');
    });

    test('embedded comma inside quoted field is not a column split', () {
      final csv = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
"Toko, Satu",10000,"Ayam, Nasi, Sayur",2026-06-19,2026-08-22,00:25:41,Bebas,
''';
      final rows = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csv.trim());

      expect(rows.length, 2);
      expect(rows[1][0], 'Toko, Satu'); // comma inside quotes preserved
      expect(rows[1][2], 'Ayam, Nasi, Sayur');
    });

    test('escaped double-quote "" becomes a single quote', () {
      final csv = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
"Toko ""Promo""",10000,Item A,2026-06-19,2026-08-22,00:25:41,Bebas,
''';
      final rows = const CsvToListConverter(
        fieldDelimiter: ',',
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csv.trim());

      expect(rows[1][0], 'Toko "Promo"');
    });
  });

  group('BudgetRepository.importFromCsv', () {
    late BudgetRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = BudgetRepository();
      await repo.init();
    });

    test('imports real Pundi export with zero silent data loss', () async {
      final file = File('/home/nyaw/Downloads/pundi_20260822_002545.csv');
      // Skip if the fixture isn't present on this machine.
      if (!file.existsSync()) {
        return;
      }
      final content = await file.readAsString();
      final imported = repo.importFromCsv(content);

      // 52 data rows in the fixture; none should be silently dropped.
      expect(imported, 52);
      expect(repo.lastImportFailedLines, isEmpty);
      expect(repo.history.length, 52);
    });

    test('reports failed rows instead of skipping silently', () {
      // 2 columns only -> below the 7-column minimum.
      final bad = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
"Toko A",,
''';
      final imported = repo.importFromCsv(bad);
      expect(imported, 0);
      expect(repo.lastImportFailedLines, isNotEmpty);
      expect(repo.lastImportFailedLines.first, contains('Baris 2'));
    });

    test('embedded newline in quoted item still imports 100%', () {
      final csv = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
"Toko X",25000,"Beli barang
lanjutan barang",2026-06-19,2026-08-22,00:25:41,Bebas,
''';
      final imported = repo.importFromCsv(csv);
      expect(imported, 1);
      expect(repo.lastImportFailedLines, isEmpty);
      expect(repo.history.first.items, 'Beli barang\nlanjutan barang');
    });

    test('income notes round-trip through export and stay income', () async {
      repo.recordIncome(
        amount: 5000000,
        chargedToCategory: allCategoriesLabel,
        notes: 'Gajian bulan Agustus',
      );
      repo.recordExpense(
        merchantName: 'Toko',
        items: 'Belanja',
        amount: 250000,
        chargedToCategory: 'Bebas',
      );

      final exported = repo.exportToCsv();
      // The income row must stay identifiable as income even though its note
      // reads like prose — that is what the marker is for.
      expect(exported, contains('Gajian bulan Agustus (Pemasukan)'));

      final fresh = BudgetRepository();
      SharedPreferences.setMockInitialValues({});
      await fresh.init();
      final imported = fresh.importFromCsv(exported);
      expect(imported, 2);
      expect(fresh.lastImportFailedLines, isEmpty);

      final income = fresh.history.firstWhere(
        (t) => t.type == TransactionType.income,
      );
      expect(income.items, 'Gajian bulan Agustus');
      expect(income.totalAmount, 5000000);
      // The frozen split must survive the trip too.
      expect(
        income.splits.fold<double>(0, (s, sp) => s + sp.allocatedAmount),
        5000000,
      );
    });

    test('an income note containing expense-ish words stays income', () async {
      repo.recordIncome(
        amount: 100000,
        chargedToCategory: 'Tabungan',
        notes: 'uang tunai dari KTP',
      );
      final exported = repo.exportToCsv();

      final fresh = BudgetRepository();
      SharedPreferences.setMockInitialValues({});
      await fresh.init();
      fresh.importFromCsv(exported);
      final back = fresh.history.first;
      expect(back.type, TransactionType.income);
      expect(back.items, 'uang tunai dari KTP');
    });
  });
}
