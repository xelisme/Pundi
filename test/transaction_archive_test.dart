import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/period_summary.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';
import 'package:hyper_budget_flutter/repositories/budget_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Archiving a transaction has to do more than hide a row.
///
/// The failure this guards against is the quiet one: an archived record that
/// still counts. A delete that only greys out a row looks like it worked while
/// "Sisa Bersih" stays wrong, which is worse than no archive at all because the
/// user trusts the number.
void main() {
  late BudgetRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = BudgetRepository();
    await repo.init();
  });

  /// 100k expense + 1M income, both in the current month so the period summary
  /// picks them up without any date arithmetic.
  void seed() {
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    repo.recordIncome(
      amount: 1000000,
      chargedToCategory: allCategoriesLabel,
      notes: 'Gajian',
    );
  }

  PeriodSummary thisMonth() => calculatePeriodSummary(
        repo.activeHistory,
        repo.categories,
        month: DateTime.now(),
      );

  test('archiving keeps the row but removes it from every total', () {
    seed();
    final expense = repo.history.firstWhere((t) => t.type == TransactionType.expense);

    expect(repo.archiveTransaction(expense.id), isTrue);

    expect(repo.history, hasLength(2), reason: 'the row itself must survive');
    expect(repo.activeHistory, hasLength(1));
    expect(repo.archivedHistory, hasLength(1));

    // The number that matters: the archived expense must be gone from the maths.
    final summary = thisMonth();
    expect(summary.totalExpenses, 0,
        reason: 'an archived expense must not still be counted');
    expect(summary.totalIncome, 1000000);
    expect(summary.netIncome, 1000000);
  });

  test('archiving an income lowers the total, not just the row count', () {
    seed();
    final income = repo.history.firstWhere((t) => t.type == TransactionType.income);

    repo.archiveTransaction(income.id);

    final summary = thisMonth();
    expect(summary.totalIncome, 0);
    expect(summary.netIncome, -100000,
        reason: 'Sisa Bersih must reflect the removal immediately');
  });

  test('restore puts the transaction back into the totals', () {
    seed();
    final expense = repo.history.firstWhere((t) => t.type == TransactionType.expense);
    final before = thisMonth();

    repo.archiveTransaction(expense.id);
    expect(thisMonth().totalExpenses, 0);

    expect(repo.restoreTransaction(expense.id), isTrue);

    expect(repo.archivedHistory, isEmpty);
    final after = thisMonth();
    expect(after.totalExpenses, before.totalExpenses);
    expect(after.netIncome, before.netIncome);
  });

  test('restore returns the record to its original position, not the top', () {
    repo.recordExpense(
        merchantName: 'A', items: 'a', amount: 1000, chargedToCategory: 'Bebas');
    repo.recordExpense(
        merchantName: 'B', items: 'b', amount: 2000, chargedToCategory: 'Bebas');
    repo.recordExpense(
        merchantName: 'C', items: 'c', amount: 3000, chargedToCategory: 'Bebas');

    // Newest-first, so history is [C, B, A].
    expect(repo.history.map((t) => t.merchantName), ['C', 'B', 'A']);

    final middle = repo.history.firstWhere((t) => t.merchantName == 'B');
    repo.archiveTransaction(middle.id);
    expect(repo.activeHistory.map((t) => t.merchantName), ['C', 'A']);

    repo.restoreTransaction(middle.id);
    expect(repo.activeHistory.map((t) => t.merchantName), ['C', 'B', 'A'],
        reason: 'B must return between C and A, not jump to the top');
  });

  test('every field survives an archive/restore round trip', () {
    repo.recordExpense(
      merchantName: 'Almaz',
      items: 'ayam',
      amount: 33000,
      chargedToCategory: allCategoriesLabel,
      paymentMethod: 'QRIS',
    );
    final before = repo.history.single;

    repo.archiveTransaction(before.id);
    repo.restoreTransaction(before.id);

    final after = repo.history.single;
    expect(after.id, before.id);
    expect(after.merchantName, 'Almaz');
    expect(after.items, 'ayam');
    expect(after.totalAmount, 33000);
    expect(after.receiptDate, before.receiptDate);
    expect(after.timestamp, before.timestamp);
    expect(after.paymentMethod, 'QRIS');
    expect(after.chargedTo, before.chargedTo);
    expect(after.allocationSnapshot, before.allocationSnapshot);
    expect(after.splits.length, before.splits.length);
    expect(after.isArchived, isFalse);
  });

  test('double-archiving and unknown ids report failure instead of lying', () {
    seed();
    final expense = repo.history.firstWhere((t) => t.type == TransactionType.expense);

    expect(repo.archiveTransaction(expense.id), isTrue);
    expect(repo.archiveTransaction(expense.id), isFalse,
        reason: 'a second tap must not claim a success that changed nothing');
    expect(repo.archiveTransaction('tidak-ada'), isFalse);
    expect(repo.restoreTransaction('tidak-ada'), isFalse);

    // Restoring something that was never archived is also a no-op, not a
    // silent resurrection of an unrelated row.
    final income = repo.history.firstWhere((t) => t.type == TransactionType.income);
    expect(repo.restoreTransaction(income.id), isFalse);
    expect(income.isArchived, isFalse);
  });

  test('editing an archived transaction must not resurrect it', () {
    seed();
    final expense = repo.history.firstWhere((t) => t.type == TransactionType.expense);
    repo.archiveTransaction(expense.id);

    repo.updateTransaction(transactionId: expense.id, newAmount: 555);

    expect(repo.history.firstWhere((t) => t.id == expense.id).isArchived, isTrue,
        reason: 'the archive flag must be carried through every rebuild');
    expect(repo.activeHistory, hasLength(1),
        reason: 'editing an archived row must not put it back in the totals');
  });

  test('reassigning a category carries the archive flag too', () {
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    final record = repo.history.single;

    repo.archiveTransaction(record.id);
    repo.updateTransactionChargedTo(record.id, 'Investasi');

    expect(repo.history.single.isArchived, isTrue,
        reason: 're-splitting a category must not clear the archive flag');
  });

  test('purgeArchived is the only path that actually destroys data', () {
    seed();
    final expense = repo.history.firstWhere((t) => t.type == TransactionType.expense);
    repo.archiveTransaction(expense.id);

    expect(repo.purgeArchived(), 1);
    expect(repo.history, hasLength(1));
    expect(repo.archivedHistory, isEmpty);
    expect(repo.purgeArchived(), 0, reason: 'nothing left to purge');
  });

  test('archived rows survive a CSV round trip without rejoining the totals',
      () async {
    repo.recordExpense(
      merchantName: 'KFC',
      items: 'kfc',
      amount: 100000,
      chargedToCategory: 'Bebas',
    );
    final record = repo.history.single;
    repo.archiveTransaction(record.id);

    // Archived rows must still be exported, or "export then reinstall" quietly
    // deletes the user's data.
    expect(repo.exportToCsv(), contains('KFC'));

    SharedPreferences.setMockInitialValues({});
    final fresh = BudgetRepository();
    await fresh.init();
    expect(fresh.importFromCsv(repo.exportToCsv()), 1);

    expect(fresh.history.single.isArchived, isTrue,
        reason: 'a re-import must return the row to the archive, not the totals');
    expect(fresh.activeHistory, isEmpty);
    expect(
      calculatePeriodSummary(fresh.activeHistory, fresh.categories,
              month: DateTime.now())
          .totalExpenses,
      0,
    );
  });

  test('a CSV with no Arsip column still imports as live rows', () async {
    // Files exported before archiving existed have 9 columns and no flag.
    const legacy = '''
Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot,Metode Pembayaran
KFC,100000,kfc,2026-09-15,2026-09-15,10:00:00,Bebas,,QRIS
''';
    expect(repo.importFromCsv(legacy), 1);
    expect(repo.history.single.isArchived, isFalse);
    expect(repo.archivedHistory, isEmpty);
  });

  test('the archive flag persists through a save and reload', () async {
    seed();
    final expense = repo.history.firstWhere((t) => t.type == TransactionType.expense);
    repo.archiveTransaction(expense.id);

    // A fresh repo reading the same prefs must see the archive, otherwise the
    // row silently returns to the totals on the next app launch.
    final reloaded = BudgetRepository();
    await reloaded.init();

    expect(reloaded.archivedHistory, hasLength(1));
    expect(reloaded.activeHistory, hasLength(1));
    expect(
      reloaded.archivedHistory.single.id,
      expense.id,
    );
  });
}