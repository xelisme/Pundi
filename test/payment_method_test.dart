import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
  });

  test('expense and income both store the chosen payment method', () async {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
      paymentMethod: 'QRIS',
    );
    repo.recordIncome(
      amount: 5000000,
      chargedToCategory: allCategoriesLabel,
      paymentMethod: 'Transfer Bank',
    );

    expect(repo.history.firstWhere((t) => t.type == TransactionType.income)
        .paymentMethod, 'Transfer Bank');
    expect(repo.history.firstWhere((t) => t.type == TransactionType.expense)
        .paymentMethod, 'QRIS');
  });

  test('payment method defaults when not specified', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 1000,
      chargedToCategory: 'Bebas',
    );
    expect(repo.history.first.paymentMethod, defaultPaymentMethod);
    expect(paymentMethods, contains(defaultPaymentMethod));
  });

  test('payment method survives archiving and transaction reassignment', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 250000,
      chargedToCategory: 'Investasi',
      paymentMethod: 'Kartu Kredit',
    );
    repo.recordExpense(
      merchantName: 'Warung',
      items: 'Makan',
      amount: 50000,
      chargedToCategory: 'Investasi',
      paymentMethod: 'E-Wallet',
    );

    final inv =
        repo.categories.firstWhere((c) => c.name == 'Investasi').id;
    expect(repo.archiveCategory(inv, reassignTo: 'Tabungan'), true);

    // Both records were rewritten by the archive — neither may lose the method.
    expect(repo.transactionCountForCategory('Investasi'), 0);
    final methods =
        repo.history.map((t) => t.paymentMethod).toSet().toList()..sort();
    expect(methods, ['E-Wallet', 'Kartu Kredit']);
  });

  test('payment method survives a "Seluruhnya" re-split on archive', () {
    repo.recordIncome(
      amount: 800000,
      chargedToCategory: allCategoriesLabel,
      paymentMethod: 'Transfer Bank',
    );
    final beb = repo.categories.firstWhere((c) => c.name == 'Bebas').id;

    expect(repo.archiveCategory(beb, reassignTo: 'Tabungan'), true);

    final record = repo.history.first;
    expect(record.paymentMethod, 'Transfer Bank');
    expect(record.chargedTo, 'Tabungan');
    expect(record.splits.fold<double>(0, (s, sp) => s + sp.allocatedAmount), 800000);
    expect(record.splits.any((sp) => sp.category.name == 'Bebas'), false);
  });

  test('updating the charged category keeps the payment method', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
      paymentMethod: 'QRIS',
    );
    repo.updateTransactionChargedTo(repo.history.first.id, 'Tabungan');
    expect(repo.history.first.chargedTo, 'Tabungan');
    expect(repo.history.first.paymentMethod, 'QRIS');
  });

  test('editing a transaction can change the payment method', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
      paymentMethod: 'QRIS',
    );
    repo.updateTransaction(transactionId: repo.history.first.id,
        newPaymentMethod: 'Tunai');
    expect(repo.history.first.paymentMethod, 'Tunai');

    // An edit that does not mention the method must leave it alone.
    repo.updateTransaction(
        transactionId: repo.history.first.id, newMerchantName: 'Toko Baru');
    expect(repo.history.first.paymentMethod, 'Tunai');
    expect(repo.history.first.merchantName, 'Toko Baru');
  });

  test('payment method round-trips through CSV as a trailing column', () async {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Bebas',
      paymentMethod: 'QRIS',
    );
    repo.recordIncome(
      amount: 5000000,
      chargedToCategory: allCategoriesLabel,
      notes: 'Gajian',
      paymentMethod: 'Transfer Bank',
    );

    final csv = repo.exportToCsv();
    expect(csv.split('\n').first, contains('Metode Pembayaran'));
    // Trailing column => an older 8-column file still imports.
    final headerColumns = csv.split('\n').first.split(',').length;
    expect(headerColumns, 9);

    final fresh = BudgetRepository();
    SharedPreferences.setMockInitialValues({});
    await fresh.init();
    expect(fresh.importFromCsv(csv), 2);
    expect(fresh.lastImportFailedLines, isEmpty);
    expect(
        fresh.history
            .firstWhere((t) => t.type == TransactionType.income)
            .paymentMethod,
        'Transfer Bank');
    expect(
        fresh.history
            .firstWhere((t) => t.type == TransactionType.expense)
            .paymentMethod,
        'QRIS');
  });

  test('an 8-column CSV from an older export imports with the default', () async {
    const csv = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot
Toko Lama,25000,Barang,2026-06-19,2026-08-22,00:25:41,Bebas,
''';
    expect(repo.importFromCsv(csv), 1);
    expect(repo.lastImportFailedLines, isEmpty);
    expect(repo.history.first.paymentMethod, defaultPaymentMethod);
  });

  test('a method this build does not know survives import untouched', () async {
    // Deliberately outside the known list, to prove import does not normalise it.
    const exotic = 'Cek Arti BCA';
    final csv =
        'Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot,Metode Pembayaran\n'
        'Toko,25000,Barang,2026-06-19,2026-08-22,00:25:41,Bebas,,$exotic\n';

    expect(paymentMethods, isNot(contains(exotic)),
        reason: 'sanity: the value is genuinely outside the known list');
    expect(repo.importFromCsv(csv), 1);
    expect(repo.lastImportFailedLines, isEmpty);
    expect(repo.history.first.paymentMethod, exotic);
  });
}