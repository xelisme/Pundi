import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/settings_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan is meant to stay a fixed list of settings, so the archive is one
/// row with a count rather than a list that grows inline. These tests pin that
/// arrangement down: the row's count tracks reality, the destination screen
/// holds the records, and the one irreversible action is guarded.
void main() {
  setUpAll(() async {
    // The archive screen formats receipt dates with DateFormat(..., 'id_ID'),
    // which throws without locale data initialised.
    await initializeDateFormatting('id_ID', null);
  });

  Future<BudgetRepository> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = BudgetRepository();
    await repo.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> openArchive(WidgetTester tester) async {
    await tester.tap(find.text('Arsip'));
    await tester.pumpAndSettle();
  }

  testWidgets('the nonaktif category card still appears and disappears live',
      (tester) async {
    final repo = await pumpSettings(tester);
    expect(find.text('KATEGORI NONAKTIF'), findsNothing);

    repo.deleteCategory(repo.categories.firstWhere((c) => c.name == 'Bebas').id);
    await tester.pumpAndSettle();
    expect(find.text('KATEGORI NONAKTIF'), findsOneWidget);
    expect(find.text('PULIHKAN'), findsOneWidget);

    expect(
        repo.restoreCategory(
            repo.categories.firstWhere((c) => c.name == 'Bebas').id),
        true);
    await tester.pumpAndSettle();
    expect(find.text('KATEGORI NONAKTIF'), findsNothing);
  });

  testWidgets('Pengaturan shows one archive row whose count tracks deletions',
      (tester) async {
    final repo = await pumpSettings(tester);

    // Present even when empty: a row that appears only once something is
    // archived would hide the feature, and a row that grows would be the junk
    // drawer the user complained about.
    expect(find.text('Arsip'), findsOneWidget);
    expect(find.text('Belum ada yang dihapus'), findsOneWidget);

    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 700000,
      chargedToCategory: 'Bebas',
    );
    repo.archiveTransaction(repo.history.single.id);
    await tester.pumpAndSettle();
    expect(find.text('1 catatan bisa dipulihkan'), findsOneWidget);

    // A second deletion changes the count, not the row's presence or size.
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc',
      amount: 300000,
      chargedToCategory: 'Bebas',
    );
    repo.archiveTransaction(repo.history.first.id);
    await tester.pumpAndSettle();
    expect(find.text('2 catatan bisa dipulihkan'), findsOneWidget);

    // Categories count toward the same total.
    repo.archiveCategory(
        repo.categories.firstWhere((c) => c.name == 'Investasi').id);
    await tester.pumpAndSettle();
    expect(find.text('3 catatan bisa dipulihkan'), findsOneWidget);

    // Pengaturan itself never grows a list: no record names leak onto it.
    expect(find.text('Almaz'), findsNothing);
    expect(find.text('KFC'), findsNothing);
    expect(find.text('Investasi'), findsNothing);
  });

  testWidgets('an empty archive shows an empty state, not a blank screen',
      (tester) async {
    await pumpSettings(tester);
    await openArchive(tester);

    expect(find.text('Arsip kosong'), findsOneWidget);
    expect(find.text('Kosongkan Arsip'), findsNothing,
        reason: 'nothing to purge, so the destructive action stays hidden');
  });

  testWidgets('the archive screen keeps transactions and categories apart',
      (tester) async {
    final repo = await pumpSettings(tester);

    // Charged to Tabungan so archiving Bebas does not trip the reassign
    // dialog, which is not what this test is about.
    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 700000,
      chargedToCategory: 'Tabungan',
    );
    repo.archiveTransaction(repo.history.single.id);
    repo.archiveCategory(
        repo.categories.firstWhere((c) => c.name == 'Bebas').id);
    await tester.pumpAndSettle();

    await openArchive(tester);

    expect(find.text('TRANSAKSI'), findsOneWidget);
    expect(find.text('KATEGORI'), findsOneWidget);
    expect(find.text('Almaz'), findsOneWidget);
    expect(find.text('Bebas'), findsWidgets);
    // 700k never collides with a category percentage split, so an exact match
    // is the archived amount.
    expect(find.text('Rp 700.000'), findsOneWidget);
    expect(find.text('Tidak masuk perhitungan'), findsOneWidget);
    expect(find.text('PULIHKAN'), findsNWidgets(2));
  });

  testWidgets('restoring from the archive screen empties it again',
      (tester) async {
    final repo = await pumpSettings(tester);

    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 700000,
      chargedToCategory: 'Bebas',
    );
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc',
      amount: 300000,
      chargedToCategory: 'Bebas',
    );
    repo.archiveTransaction(repo.history.first.id);
    await tester.pumpAndSettle();

    await openArchive(tester);
    expect(find.text('1 catatan dihapus dan tidak dihitung. Semuanya masih di '
        'sini sampai kamu mengosongkan arsip.'), findsOneWidget);

    await tester.tap(find.text('PULIHKAN'));
    await tester.pumpAndSettle();

    expect(find.text('Arsip kosong'), findsOneWidget,
        reason: 'the empty state replaces the sections once nothing is left');
    expect(repo.archivedHistory, isEmpty);
    expect(repo.activeHistory, hasLength(2));
    expect(repo.activeHistory.first.merchantName, 'KFC',
        reason: 'it returns to its own slot, not the top of the list');
  });

  testWidgets('purging is destructive, confirmed, and actually removes rows',
      (tester) async {
    final repo = await pumpSettings(tester);

    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 700000,
      chargedToCategory: 'Tabungan',
    );
    repo.recordIncome(
      amount: 500000,
      chargedToCategory: 'Tabungan',
      notes: 'Gajian',
    );
    repo.archiveTransaction(repo.history.first.id);
    repo.archiveTransaction(repo.history.last.id);
    repo.archiveCategory(
        repo.categories.firstWhere((c) => c.name == 'Bebas').id);
    await tester.pumpAndSettle();

    await openArchive(tester);
    expect(repo.history, hasLength(2),
        reason: 'archiving alone never removes a row');

    // The dialog must name the exact loss, not ask generically.
    await tester.tap(find.text('Kosongkan Arsip'));
    await tester.pumpAndSettle();
    expect(find.text('Kosongkan Arsip?'), findsOneWidget);
    expect(
        find.textContaining('3 catatan akan dihapus permanen'), findsOneWidget);
    expect(find.textContaining('2 transaksi'), findsOneWidget);
    expect(find.textContaining('1 kategori'), findsOneWidget);

    // Backing out changes nothing.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(repo.history, hasLength(2));

    await tester.tap(find.text('Kosongkan Arsip'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus permanen'));
    await tester.pumpAndSettle();

    expect(repo.history, isEmpty);
    expect(repo.archivedHistory, isEmpty);
    expect(find.text('Arsip kosong'), findsOneWidget);

    // And Pengaturan's row must fall back to its empty wording.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Belum ada yang dihapus'), findsOneWidget);
  });
}
