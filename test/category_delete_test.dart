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
    // init() already loads the 3 default categories (Tabungan/Investasi/Bebas).
  });

  test('permanently delete empty category removes it', () {
    // Make room so the new 10% category keeps total <= 100.
    final invest = repo.categories.firstWhere((c) => c.name == 'Investasi');
    repo.updateCategory(invest.id, invest.copyWith(percentage: 10)); // 50+10+20=80
    repo.addCategory(AllocationCategory(
      name: 'Kosong', percentage: 10, colorHex: '123456',
    ));
    final id = repo.categories.firstWhere((c) => c.name == 'Kosong').id;
    final ok = repo.permanentlyDeleteCategory(id, reassignTo: null);
    expect(ok, true);
    expect(repo.categories.any((c) => c.name == 'Kosong'), false);
  });

  test('permanently delete with transactions requires reassign', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Investasi',
    );
    expect(repo.transactionCountForCategory('Investasi'), 1);

    final id = repo.categories.firstWhere((c) => c.name == 'Investasi').id;
    // Without reassign -> must fail (no silent loss).
    expect(repo.permanentlyDeleteCategory(id, reassignTo: null), false);
    // Category still present (delete was refused).
    expect(repo.categories.any((c) => c.name == 'Investasi'), true);

    // With reassign to Tabungan -> ok, tx moved.
    final ok = repo.permanentlyDeleteCategory(id, reassignTo: 'Tabungan');
    expect(ok, true);
    expect(repo.categories.any((c) => c.name == 'Investasi'), false);
    expect(repo.transactionCountForCategory('Tabungan'), 1);
    expect(repo.transactionCountForCategory('Investasi'), 0);
  });

  test('soft-delete (nonaktif) keeps transactions, blocks via activeCategories', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 50000,
      chargedToCategory: 'Bebas',
    );
    final id = repo.categories.firstWhere((c) => c.name == 'Bebas').id;
    repo.deleteCategory(id);
    final cat = repo.categories.firstWhere((c) => c.name == 'Bebas');
    expect(cat.isActive, false);
    expect(repo.activeCategories.any((c) => c.name == 'Bebas'), false);
    // Transaction preserved.
    expect(repo.transactionCountForCategory('Bebas'), 1);
  });

  test('input guard: deactivated category falls back to Seluruhnya', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 50000,
      chargedToCategory: 'Bebas',
    );
    final id = repo.categories.firstWhere((c) => c.name == 'Bebas').id;
    repo.deleteCategory(id);
    // Simulate UI state holding a now-deactivated selection.
    const selected = 'Bebas';
    final effective = (selected != 'Seluruhnya' &&
            !repo.activeCategories.any((c) => c.name == selected))
        ? 'Seluruhnya'
        : selected;
    expect(effective, 'Seluruhnya');
  });
}
