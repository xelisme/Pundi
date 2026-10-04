import 'transaction.dart';

/// Income minus expense for a single category over one period.
class CategoryBalance {
  final String name;
  final String colorHex;
  final int income;
  final int expense;

  /// False once the category was soft-deleted or archived. Kept so the UI can
  /// dim the row: an archived category still owes its historical money a place
  /// on the table, it just no longer accepts new transactions.
  final bool isActive;
  final bool isArchived;

  const CategoryBalance({
    required this.name,
    required this.colorHex,
    required this.income,
    required this.expense,
    required this.isActive,
    required this.isArchived,
  });

  int get balance => income - expense;

  /// True when the category has never seen a single rupiah in this period.
  bool get isEmpty => income == 0 && expense == 0;
}

/// Totals for one period: a single month, or every month on record.
class PeriodSummary {
  final int totalIncome;
  final int totalExpenses;
  final int netIncome;

  /// Per-category totals derived from each transaction's frozen splits.
  final Map<String, int> incomeBreakdown;
  final Map<String, int> expenseBreakdown;

  /// One row per known category, in category order, including empty ones so
  /// the table layout does not jump between periods.
  final List<CategoryBalance> categoryBalances;

  /// How many distinct calendar months actually contributed a record. For an
  /// all-time summary this is the real span ("12 bulan"), not a guess.
  final int monthCount;

  /// Total records inside the window, income and expense.
  final int recordCount;

  const PeriodSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netIncome,
    required this.incomeBreakdown,
    required this.expenseBreakdown,
    required this.categoryBalances,
    required this.monthCount,
    required this.recordCount,
  });

  static const empty = PeriodSummary(
    totalIncome: 0,
    totalExpenses: 0,
    netIncome: 0,
    incomeBreakdown: {},
    expenseBreakdown: {},
    categoryBalances: [],
    monthCount: 0,
    recordCount: 0,
  );

  bool get hasRecords => recordCount > 0;
}

/// Aggregate [records] into per-category and overall totals.
///
/// Pass a [month] to scope the result to that single calendar month, or omit it
/// to accumulate every record on file — no month or year ceiling — which is
/// what the "SEMUA" period shows.
///
/// A record belongs to the month of its *input* timestamp, not its receipt
/// date, which is how the month selector has always behaved.
PeriodSummary calculatePeriodSummary(
  List<TransactionRecord> records,
  List<AllocationCategory> categories, {
  DateTime? month,
}) {
  int totalIncome = 0;
  int totalExpenses = 0;
  final Map<String, int> incomeBreakdown = {};
  final Map<String, int> expenseBreakdown = {};
  final Map<String, int> categoryIncome = {};
  final Map<String, int> categoryExpense = {};
  final Set<String> monthsSeen = <String>{};
  int recordCount = 0;

  for (final cat in categories) {
    categoryIncome[cat.name] = 0;
    categoryExpense[cat.name] = 0;
  }

  // A null window means "every month on record".
  DateTime? windowStart;
  DateTime? windowEnd;
  if (month != null) {
    windowStart = DateTime(month.year, month.month, 1);
    windowEnd = DateTime(month.year, month.month + 1, 1);
  }

  for (final record in records) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (windowStart != null &&
        (date.isBefore(windowStart) || date.compareTo(windowEnd!) >= 0)) {
      continue;
    }

    recordCount++;
    monthsSeen.add('${date.year}-${date.month}');

    if (record.type == TransactionType.income) {
      totalIncome += record.totalAmount.toInt();
      for (final split in record.splits) {
        final key = split.category.name;
        incomeBreakdown[key] =
            (incomeBreakdown[key] ?? 0) + split.allocatedAmount.toInt();
        categoryIncome[key] =
            (categoryIncome[key] ?? 0) + split.allocatedAmount.toInt();
      }
    } else {
      totalExpenses += record.totalAmount.toInt();
      if (record.splits.isNotEmpty) {
        for (final split in record.splits) {
          final key = split.category.name;
          expenseBreakdown[key] =
              (expenseBreakdown[key] ?? 0) + split.allocatedAmount.toInt();
          categoryExpense[key] =
              (categoryExpense[key] ?? 0) + split.allocatedAmount.toInt();
        }
      } else {
        // No splits at all (shouldn't happen, but a hand-edited import can):
        // fall back to the label so the money is still attributed somewhere.
        final key = record.chargedTo ?? 'Lainnya';
        expenseBreakdown[key] =
            (expenseBreakdown[key] ?? 0) + record.totalAmount.toInt();
        if (categoryExpense.containsKey(key)) {
          categoryExpense[key] =
              (categoryExpense[key] ?? 0) + record.totalAmount.toInt();
        }
      }
    }
  }

  final balances = <CategoryBalance>[];
  for (final cat in categories) {
    balances.add(CategoryBalance(
      name: cat.name,
      colorHex: cat.colorHex,
      income: categoryIncome[cat.name] ?? 0,
      expense: categoryExpense[cat.name] ?? 0,
      isActive: cat.isActive,
      isArchived: cat.isArchived,
    ));
  }

  return PeriodSummary(
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    netIncome: totalIncome - totalExpenses,
    incomeBreakdown: incomeBreakdown,
    expenseBreakdown: expenseBreakdown,
    categoryBalances: balances,
    monthCount: monthsSeen.length,
    recordCount: recordCount,
  );
}