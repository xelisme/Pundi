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

  test('archiving an empty category keeps it restorable', () {
    // Make room so the new 10% category keeps total <= 100.
    final invest = repo.categories.firstWhere((c) => c.name == 'Investasi');
    repo.updateCategory(invest.id, invest.copyWith(percentage: 10)); // 50+10+20=80
    repo.addCategory(AllocationCategory(
      name: 'Kosong', percentage: 10, colorHex: '123456',
    ));
    final id = repo.categories.firstWhere((c) => c.name == 'Kosong').id;
    final ok = repo.archiveCategory(id, reassignTo: null);
    expect(ok, true);

    // Archiving never destroys the row — it is hidden but present.
    final archived =
        repo.categories.firstWhere((c) => c.name == 'Kosong');
    expect(archived.isArchived, true);
    expect(archived.isActive, false);
    expect(repo.activeCategories.any((c) => c.name == 'Kosong'), false);
    expect(repo.archivedCategories.map((c) => c.name), contains('Kosong'));

    // ...and it comes straight back.
    expect(repo.restoreCategory(id), true);
    final back = repo.categories.firstWhere((c) => c.name == 'Kosong');
    expect(back.isArchived, false);
    expect(back.isActive, true);
  });

  test('archiving with transactions requires reassign', () {
    repo.recordExpense(
      merchantName: 'Toko',
      items: 'Barang',
      amount: 100000,
      chargedToCategory: 'Investasi',
    );
    expect(repo.transactionCountForCategory('Investasi'), 1);

    final id = repo.categories.firstWhere((c) => c.name == 'Investasi').id;
    // Without reassign -> must fail (no silent loss).
    expect(repo.archiveCategory(id, reassignTo: null), false);
    // Category untouched (archive was refused).
    expect(repo.categories.firstWhere((c) => c.name == 'Investasi').isArchived,
        false);

    // Reassigning onto itself is refused too.
    expect(repo.archiveCategory(id, reassignTo: 'Investasi'), false);

    // With reassign to Tabungan -> ok, tx moved.
    final ok = repo.archiveCategory(id, reassignTo: 'Tabungan');
    expect(ok, true);
    expect(repo.categories.firstWhere((c) => c.name == 'Investasi').isArchived,
        true);
    expect(repo.transactionCountForCategory('Tabungan'), 1);
    expect(repo.transactionCountForCategory('Investasi'), 0);
  });

  test('soft-deleting a category does not rewrite settled history', () {
    // Snapshot freeze: the income below was split 50/30/20. Soft-deleting
    // Bebas hides it from future allocation but must not touch this record.
    repo.recordIncome(amount: 5000, chargedToCategory: allCategoriesLabel);
    repo.deleteCategory(
        repo.categories.firstWhere((c) => c.name == 'Bebas').id);

    final old = repo.history.first;
    expect(old.splits.any((sp) => sp.category.name == 'Bebas'), true);
    expect(old.allocationSnapshot.containsKey('Bebas'), true);
    expect(old.splits.fold<double>(0, (s, sp) => s + sp.allocatedAmount), 5000);
  });

  test('archived category is excluded from new allocation', () {
    repo.recordIncome(amount: 5000, chargedToCategory: allCategoriesLabel);
    final bebId = repo.categories.firstWhere((c) => c.name == 'Bebas').id;

    // "Seluruhnya" history references Bebas through its snapshot, so archiving
    // demands a reassign target — the money-safety rule doing its job.
    expect(repo.archiveCategory(bebId), false);
    expect(
        repo.categories.firstWhere((c) => c.name == 'Bebas').isArchived, false);

    // With a target the 5000 moves to Tabungan and Bebas is archived.
    expect(repo.archiveCategory(bebId, reassignTo: 'Tabungan'), true);
    expect(repo.categories.firstWhere((c) => c.name == 'Bebas').isArchived,
        true);
    expect(repo.history.first.splits.any((sp) => sp.category.name == 'Bebas'),
        false);
    expect(
        repo.history.first.splits
            .fold<double>(0, (s, sp) => s + sp.allocatedAmount),
        5000);

    // A NEW "Seluruhnya" income skips the archive: the freed 20% is spread
    // across the remaining active 50/30, so the full amount is still allocated.
    repo.recordIncome(amount: 3000, chargedToCategory: allCategoriesLabel);
    final fresh = repo.history.first;
    expect(fresh.splits.any((sp) => sp.category.name == 'Bebas'), false);
    expect(fresh.splits.fold<double>(0, (s, sp) => s + sp.allocatedAmount), 3000);
  });

  test('restoring an archived category is refused to break the 100% guard', () {
    // Archive 40% worth, then give the last active category all 100%.
    repo.archiveCategory(
        repo.categories.firstWhere((c) => c.name == 'Investasi').id);
    final beb = repo.categories.firstWhere((c) => c.name == 'Bebas').id;
    repo.archiveCategory(beb);
    final tab = repo.categories.firstWhere((c) => c.name == 'Tabungan');
    repo.updateCategory(tab.id, tab.copyWith(percentage: 100)); // 50 -> 100
    expect(
        repo.categories.firstWhere((c) => c.name == 'Tabungan').percentage,
        100);

    final reactivated = repo.restoreCategory(beb); // would be 100 + 20 = 120
    final back = repo.categories.firstWhere((c) => c.name == 'Bebas');
    expect(reactivated, false);
    // Un-archived but NOT active — it must never be stranded in the archive.
    expect(back.isArchived, false);
    expect(back.isActive, false);
  });

  test('re-adding a name that was archived revives the original row', () {
    final id = repo.categories.firstWhere((c) => c.name == 'Investasi').id;
    repo.archiveCategory(id);
    expect(repo.archivedCategories.any((c) => c.name == 'Investasi'), true);

    // "Baru" fits in the freed 30% headroom.
    repo.addCategory(AllocationCategory(
      name: 'Investasi', percentage: 30, colorHex: '#10B981',
    ));

    expect(repo.categories.where((c) => c.name == 'Investasi').length, 1);
    final revived = repo.categories.firstWhere((c) => c.name == 'Investasi');
    expect(revived.id, id, reason: 'keeps the original row, no duplicate');
    expect(revived.isArchived, false);
    expect(revived.isActive, true);
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
