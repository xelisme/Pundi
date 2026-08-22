import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init(); // default 50/30/20 = 100%
  });

  double totalAllocated() =>
      repo.history.fold(0.0, (s, t) => s + t.splits.fold(0.0, (a, sp) => a + sp.allocatedAmount));

  // ---- GUARD (repo level) ----
  test('RED guard: addCategory rejected when total would exceed 100', () {
    final newCat = AllocationCategory(name: 'Kelebihan', percentage: 10, colorHex: '123456');
    repo.addCategory(newCat);
    // should be REFUSED (total 50+30+20+10 = 110)
    expect(repo.categories.any((c) => c.name == 'Kelebihan'), false);
  });

  test('RED guard: updateCategory rejected when total would exceed 100', () {
    final invest = repo.categories.firstWhere((c) => c.name == 'Investasi');
    final edited = invest.copyWith(percentage: 60); // 50+60+20 = 130
    repo.updateCategory(invest.id, edited);
    // should be REFUSED, percentage stays 30
    expect(repo.categories.firstWhere((c) => c.name == 'Investasi').percentage, 30);
  });

  test('guard: addCategory allowed when total stays <= 100', () {
    // Drop Investasi to 10 first (50+10+20=80), then add 20 is fine.
    final invest = repo.categories.firstWhere((c) => c.name == 'Investasi');
    repo.updateCategory(invest.id, invest.copyWith(percentage: 10));
    repo.addCategory(AllocationCategory(name: 'Baru', percentage: 20, colorHex: 'ABCDEF'));
    expect(repo.categories.any((c) => c.name == 'Baru'), true);
  });

  // ---- BUG D: explicit tx reassigned to Seluruhnya loses ALL allocation ----
  test('RED bugD: explicit tx reassigned to Seluruhnya keeps full allocation', () {
    repo.recordExpense(merchantName: 'T', items: 'x', amount: 5000, chargedToCategory: 'Investasi');
    final id = repo.categories.firstWhere((c) => c.name == 'Investasi').id;
    repo.permanentlyDeleteCategory(id, reassignTo: allCategoriesLabel);
    // Explicit tx had 100% to Investasi (5000). After reassign to Seluruhnya it
    // must STILL be fully allocated (5000), not 0.
    expect(totalAllocated(), 5000);
  });

  // ---- BUG C (no longer a bug; captured as a regression guard) ----
  test('Seluruhnya tx stays fully allocated after a category is permanently deleted', () {
    repo.recordIncome(amount: 5000, chargedToCategory: allCategoriesLabel); // snapshot 50/30/20
    final id = repo.categories.firstWhere((c) => c.name == 'Investasi').id;
    repo.permanentlyDeleteCategory(id, reassignTo: 'Tabungan');
    // Reassigned to Tabungan -> 5000 fully allocated to Tabungan.
    expect(totalAllocated(), 5000);
  });
}
