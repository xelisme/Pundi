import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
