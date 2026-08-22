import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init(); // 50/30/20
  });

  double totalSplits() =>
      repo.history.fold(0.0, (s, t) => s + t.splits.fold(0.0, (a, sp) => a + sp.allocatedAmount));

  // BUG 1: soft-deleted category must NOT receive allocation from new "Seluruhnya" tx.
  test('RED bug1: new Seluruhnya tx ignores soft-deleted categories', () {
    final invest = repo.categories.firstWhere((c) => c.name == 'Investasi');
    repo.deleteCategory(invest.id); // soft-delete 30%
    // Need active total 100% to add a new one cleanly:
    repo.addCategory(AllocationCategory(name: 'Baru', percentage: 30, colorHex: '111111'));
    repo.recordIncome(amount: 5000, chargedToCategory: allCategoriesLabel);
    final hasInvest = repo.history.first.splits.any((sp) => sp.category.name == 'Investasi');
    expect(hasInvest, false);
    expect(totalSplits(), 5000);
  });

  // BUG 3: permanently-deleted category -> its share redistributed, not lost.
  test('RED bug3: perm-deleted category share is redistributed (not dropped)', () {
    repo.recordIncome(amount: 5000, chargedToCategory: allCategoriesLabel); // snap 50/30/20
    final invest = repo.categories.firstWhere((c) => c.name == 'Investasi');
    repo.permanentlyDeleteCategory(invest.id, reassignTo: 'Tabungan');
    final hasInvest = repo.history.first.splits.any((sp) => sp.category.name == 'Investasi');
    expect(hasInvest, false);
    expect(totalSplits(), 5000);
  });

  // BUG 2: restoreCategory refused when it would exceed 100%.
  test('RED bug2: restoreCategory refused when total would exceed 100', () {
    // Build a 100%-active state WITHOUT the category we will try to restore:
    // drop Investasi & Bebas (both 0 tx), then push Tabungan to 100%.
    final inv = repo.categories.firstWhere((c) => c.name == 'Investasi');
    final invId = inv.id;
    final beb = repo.categories.firstWhere((c) => c.name == 'Bebas');
    repo.permanentlyDeleteCategory(inv.id, reassignTo: null);
    repo.permanentlyDeleteCategory(beb.id, reassignTo: null);
    final tab = repo.categories.firstWhere((c) => c.name == 'Tabungan');
    repo.updateCategory(tab.id, tab.copyWith(percentage: 100)); // 100% active
    // Now restoring Investasi (30) would push 100+30 = 130 -> refused.
    repo.restoreCategory(invId);
    expect(repo.categories.where((c) => c.name == 'Investasi').isEmpty ||
        repo.categories.firstWhere((c) => c.name == 'Investasi').isActive == false,
        true);
  });
}
