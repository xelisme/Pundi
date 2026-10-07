import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/ledger_filter.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:hyper_budget_flutter/screens/history_screen.dart';
import 'package:hyper_budget_flutter/state/ledger_filter_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Riwayat under a period-and-category selection.
///
/// The behaviour under test is that Riwayat shows the same slice Ringkasan
/// totals, and that showing it never turns a view into a second version of the
/// data. The dangerous case is editing: a filtered row carries only its
/// category's share, so anything that writes that amount back would quietly
/// replace the whole receipt. The tests below pin both halves.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID', null));

  late BudgetRepository repo;
  late LedgerFilterController filters;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
    filters = LedgerFilterController();
  });

  String rp(num v) => 'Rp ${NumberFormat('#,##0', 'id_ID').format(v.round())}';

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: repo),
          ChangeNotifierProvider.value(value: filters),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A "Seluruhnya" income, which is what makes the share question matter: one
  /// row, several categories, and the row's own total is larger than any single
  /// category's part of it.
  Future<TransactionRecord> recordSharedIncome(double amount) async {
    repo.recordIncome(
      amount: amount,
      chargedToCategory: allCategoriesLabel,
      notes: 'Gajian',
    );
    return repo.activeHistory.single;
  }

  double shareOf(TransactionRecord record, String category) => record.splits
      .firstWhere((s) => s.category.name == category)
      .allocatedAmount;

  testWidgets('with no filter every active row is listed and no bar is shown',
      (WidgetTester tester) async {
    await recordSharedIncome(600000);
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 50000,
      chargedToCategory: 'Bebas',
    );
    await pumpHistory(tester);

    expect(find.text('2 transaksi'), findsOneWidget);
    expect(find.textContaining('Hapus filter'), findsNothing);
    expect(find.textContaining('semua kategori'), findsNothing);
  });

  testWidgets('a category filter narrows the list to that category\'s share',
      (WidgetTester tester) async {
    final stored = await recordSharedIncome(600000);
    final bebasShare = shareOf(stored, 'Bebas');

    filters.setFilter(LedgerFilter(categoryName: 'Bebas'));
    await pumpHistory(tester);

    // The row shows the share, so the list adds up to the filtered total rather
    // than showing the receipt in full under a category it is not all in.
    expect(find.text(rp(bebasShare)), findsOneWidget);
    expect(find.text(rp(stored.totalAmount)), findsNothing);
  });

  testWidgets('the bar names the selection and clearing brings the rows back',
      (WidgetTester tester) async {
    await recordSharedIncome(600000);
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 50000,
      chargedToCategory: 'Bebas',
    );
    await pumpHistory(tester);

    // Investasi, not Bebas: the shared income carries an Investasi split and the
    // expense is charged to Bebas, so exactly one of the two survives.
    filters.setFilter(LedgerFilter(categoryName: 'Investasi'));
    await tester.pumpAndSettle();
    expect(find.text('Kategori Investasi'), findsOneWidget);
    expect(find.textContaining('bagian Investasi'), findsOneWidget);
    expect(find.text('1 dari 2 transaksi'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(filters.isActive, isFalse);
    expect(find.text('2 transaksi'), findsOneWidget);
  });

  testWidgets('a period filter names the range it is holding',
      (WidgetTester tester) async {
    await recordSharedIncome(600000);
    filters.setFilter(LedgerFilter(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
      categoryName: 'Bebas',
    ));
    await pumpHistory(tester);

    expect(find.textContaining('Bebas · 1 - 30 Sep 2026'), findsOneWidget);
  });

  testWidgets('editing a filtered row edits the whole transaction, not its share',
      (WidgetTester tester) async {
    // This is the regression that the re-scaling in applyLedgerFilter could
    // have introduced. The row on screen holds 120.000; the stored receipt is
    // 600.000 split across three categories. Saving the edit must leave 600.000
    // in the repository, or the user's other two allocations have been destroyed
    // by opening a form.
    final stored = await recordSharedIncome(600000);
    final bebasShare = shareOf(stored, 'Bebas');
    expect(bebasShare, lessThan(stored.totalAmount),
        reason: 'precondition: the share really is a fraction of the receipt');

    filters.setFilter(LedgerFilter(categoryName: 'Bebas'));
    await pumpHistory(tester);

    // The row really is showing the reduced figure.
    expect(find.text(rp(bebasShare)), findsOneWidget);

    await tester.tap(find.text('Gajian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // The form must open on the stored receipt, not on the slice.
    final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nominal'));
    expect(field.controller!.text, '600000.0',
        reason: 'the form has to show the real amount, not the category share');

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    final after = repo.activeHistory.single;
    expect(after.totalAmount, 600000,
        reason: 'saving a filtered row must not overwrite the receipt with a share');
    expect(after.splits.length, stored.splits.length,
        reason: 'the other allocations must survive');
  });

  testWidgets('a filter that matches nothing says so instead of claiming an empty ledger',
      (WidgetTester tester) async {
    await recordSharedIncome(600000);
    filters.setFilter(LedgerFilter(
      from: DateTime(2000, 1, 1),
      to: DateTime(2000, 1, 31),
    ));
    await pumpHistory(tester);

    // There is a transaction on file, so "Belum ada transaksi" would be false.
    expect(find.text('Tidak ada transaksi di pilihan ini'), findsOneWidget);
    expect(find.text('Belum ada transaksi'), findsNothing);

    await tester.tap(find.text('Hapus filter'));
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi'), findsOneWidget);
  });

  // --- the search box -------------------------------------------------------

  testWidgets('search narrows the list and the count says so',
      (WidgetTester tester) async {
    repo.recordExpense(
        merchantName: 'Toko Alpha', items: 'Beras', amount: 100000, chargedToCategory: 'Bebas');
    repo.recordExpense(
        merchantName: 'Toko Beta', items: 'Minyak', amount: 200000, chargedToCategory: 'Bebas');
    await pumpHistory(tester);

    expect(find.text('2 transaksi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    expect(find.text('Toko Alpha'), findsOneWidget);
    expect(find.text('Toko Beta'), findsNothing);
    // A bare count would read as the whole ledger while showing half of it.
    expect(find.text('1 dari 2 transaksi'), findsOneWidget);
  });

  testWidgets('search narrows what the category filter already narrowed',
      (WidgetTester tester) async {
    repo.recordExpense(
        merchantName: 'Toko Alpha', items: 'Beras', amount: 100000, chargedToCategory: 'Bebas');
    repo.recordExpense(
        merchantName: 'Toko Beta', items: 'Minyak', amount: 200000, chargedToCategory: 'Tabungan');
    filters.setCategory('Bebas');
    await pumpHistory(tester);

    // The filter already leaves one of the two.
    expect(find.text('1 dari 2 transaksi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    expect(find.text('Toko Alpha'), findsOneWidget);
    expect(find.text('Toko Beta'), findsNothing);
    expect(find.text('1 dari 2 transaksi'), findsOneWidget);
  });

  testWidgets('a search that matches nothing says so, and releasing it brings '
      'the rows back', (WidgetTester tester) async {
    repo.recordExpense(
        merchantName: 'Toko Alpha', items: 'Beras', amount: 100000, chargedToCategory: 'Bebas');
    await pumpHistory(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada yang cocok dengan pencarian'), findsOneWidget);
    // Blaming an empty ledger when the ledger has rows is the failure this
    // wording exists to avoid.
    expect(find.text('Belum ada transaksi'), findsNothing);

    await tester.tap(find.text('Bersihkan pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('Toko Alpha'), findsOneWidget);
    expect(find.text('1 transaksi'), findsOneWidget);
  });

  testWidgets('typing in the search never reaches Ringkasan',
      (WidgetTester tester) async {
    repo.recordExpense(
        merchantName: 'Toko Alpha', items: 'Beras', amount: 100000, chargedToCategory: 'Bebas');
    await pumpHistory(tester);

    // The three axes are independent. Publishing a search would leave Ringkasan
    // showing one kind of slice and Riwayat a different one, and nothing on
    // Ringkasan would explain either.
    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();
    expect(filters.filter, LedgerFilter.none());

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(filters.filter, LedgerFilter.none());
  });
}