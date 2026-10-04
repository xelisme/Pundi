import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_budget_flutter/models/ledger_filter.dart';
import 'package:hyper_budget_flutter/models/period_summary.dart';
import 'package:hyper_budget_flutter/models/transaction.dart';

/// Filtering by category is the part that can be quietly wrong.
///
/// A "Seluruhnya" income is one row carrying several splits. If a category view
/// counted the whole row against each category, every category would claim the
/// full amount and the totals would not add up to anything real. These tests pin
/// the attribution down rather than the widget tree.
void main() {
  late AllocationCategory tabungan;
  late AllocationCategory investasi;
  late AllocationCategory bebas;

  setUp(() {
    tabungan = AllocationCategory(
        name: 'Tabungan', percentage: 50, colorHex: '#3B82F6');
    investasi = AllocationCategory(
        name: 'Investasi', percentage: 30, colorHex: '#10B981');
    bebas = AllocationCategory(
        name: 'Bebas', percentage: 20, colorHex: '#F59E0B');
  });

  int epoch(int y, int m, int d, [int hh = 12]) =>
      DateTime(y, m, d, hh).millisecondsSinceEpoch;

  /// A "Seluruhnya" expense: 600.000 split 50/30/20 -> 300.000/180.000/120.000.
  /// The amounts are deliberately distinct so a wrong total cannot coincidentally
  /// match another category's.
  TransactionRecord seluruhnya({
    required int amount,
    required int receipt,
    String chargedTo = allCategoriesLabel,
    TransactionType type = TransactionType.expense,
  }) =>
      TransactionRecord(
        rawInput: 'x',
        totalAmount: amount.toDouble(),
        type: type,
        merchantName: 'Gajian',
        items: 'gajian',
        receiptDate: receipt,
        timestamp: receipt,
        chargedTo: chargedTo,
        allocationSnapshot: {
          'Tabungan': 50,
          'Investasi': 30,
          'Bebas': 20,
        },
        splits: [
          CategorySplitResult(category: tabungan, allocatedAmount: amount * 0.5),
          CategorySplitResult(
              category: investasi, allocatedAmount: amount * 0.3),
          CategorySplitResult(category: bebas, allocatedAmount: amount * 0.2),
        ],
      );

  TransactionRecord labeled({
    required int amount,
    required int receipt,
    required AllocationCategory category,
    TransactionType type = TransactionType.expense,
  }) =>
      TransactionRecord(
        rawInput: 'x',
        totalAmount: amount.toDouble(),
        type: type,
        merchantName: 'Toko',
        items: 'barang',
        receiptDate: receipt,
        timestamp: receipt,
        chargedTo: category.name,
        splits: [CategorySplitResult(
            category: category, allocatedAmount: amount.toDouble())],
      );

  List<TransactionRecord> everything() => [
        labeled(
            amount: 700000,
            receipt: epoch(2026, 9, 15),
            category: bebas,
            type: TransactionType.income),
        seluruhnya(amount: 600000, receipt: epoch(2026, 9, 20)),
        labeled(
            amount: 300000, receipt: epoch(2026, 10, 2), category: tabungan),
      ];

  // ---------------------------------------------------------------- period --

  test('no filter returns the same records, untouched', () {
    final records = everything();
    final out = applyLedgerFilter(records, const LedgerFilter.none());

    expect(out.length, 3);
    expect(out.first.totalAmount, 700000);
    expect(out[1].splits.length, 3,
        reason: 'an unfiltered row must keep all of its splits');
  });

  test('a date range keeps only records inside it', () {
    final out = applyLedgerFilter(
      everything(),
      LedgerFilter(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
    );

    expect(out.map((r) => r.totalAmount), [700000, 600000]);
  });

  test('the range is inclusive of the whole final day', () {
    // A transaction logged at 23:59 on the last day belongs to the range.
    // Comparing against midnight would drop it and the total would look wrong
    // for no visible reason.
    final late = labeled(
        amount: 90000, receipt: epoch(2026, 9, 30, 23), category: bebas);
    final justAfter =
        labeled(amount: 40000, receipt: epoch(2026, 10, 1, 0), category: bebas);

    final out = applyLedgerFilter(
      [late, justAfter],
      LedgerFilter(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
    );

    expect(out.map((r) => r.totalAmount), [90000]);
  });

  test('the range is judged by receipt date, not by when it was typed in',
      () {
    // Receipted 30 Sep, keyed in 1 Oct. This is the exact drift that made month
    // totals wrong before; the range filter must not reintroduce it.
    final record = TransactionRecord(
      rawInput: 'x',
      totalAmount: 160000,
      receiptDate: epoch(2026, 9, 30),
      timestamp: epoch(2026, 10, 1),
      chargedTo: bebas.name,
      splits: [
        CategorySplitResult(category: bebas, allocatedAmount: 160000)
      ],
    );

    final september = applyLedgerFilter(
        [record], LedgerFilter(from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)));
    final october = applyLedgerFilter(
        [record], LedgerFilter(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)));

    expect(september, hasLength(1));
    expect(october, isEmpty);
  });

  test('an open period means unbounded on that side', () {
    final out = applyLedgerFilter(
        everything(), LedgerFilter(from: DateTime(2026, 10, 1)));
    expect(out.map((r) => r.totalAmount), [300000]);
  });

  // -------------------------------------------------------------- category --

  test('a category view counts only that category\'s share', () {
    final bebasOnly = applyLedgerFilter(
        everything(), LedgerFilter(categoryName: 'Bebas'));

    expect(bebasOnly.map((r) => r.totalAmount).toList(), [700000, 120000],
        reason: 'the shared 600.000 must contribute its 20% share, not 600.000');

    final total = bebasOnly.fold<double>(0, (s, r) => s + r.totalAmount);
    expect(total, 820000);
  });

  test('a category view keeps only that category\'s splits', () {
    final out = applyLedgerFilter(
        everything(), LedgerFilter(categoryName: 'Investasi'));

    expect(out, hasLength(1));
    expect(out.single.splits.length, 1);
    expect(out.single.splits.single.category.name, 'Investasi');
    expect(out.single.totalAmount, 180000);
  });

  test('the re-scaled records still total to the real per-category money', () {
    // The check that matters: the filtered list must add up the same as the
    // category row the summary screen shows.
    final bebasOnly = applyLedgerFilter(
        everything(), LedgerFilter(categoryName: 'Bebas'));
    final summary = calculatePeriodSummary(
      bebasOnly,
      [tabungan, investasi, bebas],
    );

    // 700.000 is the income charged to Bebas; the shared 600.000 expense
    // contributes only its 20% share.
    expect(summary.totalIncome, 700000);
    expect(summary.totalExpenses, 120000);
    expect(summary.netIncome, 580000);
    expect(summary.expenseBreakdown['Bebas'], 120000);

    // The real invariant: what the summary says this category holds must equal
    // what the filtered rows actually add up to. If these ever drift apart, a
    // category view is showing a number its own list does not support.
    final rowSum = summary.categoryBalances
        .firstWhere((b) => b.name == 'Bebas')
        .income +
        summary.categoryBalances
            .firstWhere((b) => b.name == 'Bebas')
            .expense;
    expect(rowSum, bebasOnly.fold<double>(0, (s, r) => s + r.totalAmount));
  });

  test('a record with no splits is matched by its label', () {
    // Hand-edited imports can land here, and calculatePeriodSummary attributes
    // them by label, so the filter has to agree or the row vanishes.
    final record = TransactionRecord(
      rawInput: 'x',
      totalAmount: 55000,
      receiptDate: epoch(2026, 9, 3),
      timestamp: epoch(2026, 9, 3),
      chargedTo: 'Bebas',
    );

    expect(applyLedgerFilter([record], LedgerFilter(categoryName: 'Bebas')),
        hasLength(1));
    expect(applyLedgerFilter([record], LedgerFilter(categoryName: 'Tabungan')),
        isEmpty);
  });

  test('several splits into one category are summed', () {
    final a = labeled(
        amount: 100000, receipt: epoch(2026, 9, 1), category: bebas);
    final b = TransactionRecord(
      rawInput: 'x',
      totalAmount: 90000,
      receiptDate: epoch(2026, 9, 2),
      timestamp: epoch(2026, 9, 2),
      chargedTo: bebas.name,
      splits: [
        CategorySplitResult(category: bebas, allocatedAmount: 40000),
        CategorySplitResult(category: tabungan, allocatedAmount: 50000),
      ],
    );

    final out = applyLedgerFilter([a, b], LedgerFilter(categoryName: 'Bebas'));
    expect(out.fold<double>(0, (s, r) => s + r.totalAmount), 140000);
  });

  test('income charged to one category is income in that category view', () {
    final income = labeled(
      amount: 2000000,
      receipt: epoch(2026, 9, 10),
      category: investasi,
      type: TransactionType.income,
    );

    final out =
        applyLedgerFilter([income], LedgerFilter(categoryName: 'Investasi'));
    expect(out.single.type, TransactionType.income);
    expect(out.single.totalAmount, 2000000);
  });

  // --------------------------------------------------------------- combined --

  test('period and category narrow together', () {
    final out = applyLedgerFilter(
      [
        labeled(
            amount: 700000,
            receipt: epoch(2026, 9, 15),
            category: bebas,
            type: TransactionType.income),
        labeled(
            amount: 111000, receipt: epoch(2026, 9, 20), category: bebas),
        labeled(
            amount: 300000, receipt: epoch(2026, 10, 2), category: bebas),
      ],
      LedgerFilter(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        categoryName: 'Bebas',
      ),
    );

    expect(out.map((r) => r.totalAmount), [700000, 111000]);
  });

  test('an archived record stays filterable and stays out of the maths', () {
    final record = labeled(
        amount: 400000, receipt: epoch(2026, 9, 12), category: bebas);
    final archived = record.copyWith(isArchived: true);

    final out =
        applyLedgerFilter([archived], LedgerFilter(categoryName: 'Bebas'));
    expect(out, hasLength(1),
        reason: 'filtering is a view, not a restore; archived stays archived');

    final summary =
        calculatePeriodSummary(out.where((r) => !r.isArchived).toList(), [bebas]);
    expect(summary.totalExpenses, 0);
  });

  // --------------------------------------------------------------- presets --

  test('presets cover the range their label claims', () {
    final now = DateTime.now();
    final records = [
      labeled(amount: 1000, receipt: now.millisecondsSinceEpoch, category: bebas),
      labeled(
          amount: 2000,
          receipt: DateTime(now.year, now.month - 1, 15).millisecondsSinceEpoch,
          category: bebas),
      labeled(
          amount: 4000,
          receipt: DateTime(now.year, now.month - 3, 15).millisecondsSinceEpoch,
          category: bebas),
    ];

    expect(applyLedgerFilter(records, LedgerRanges.thisMonth()),
        hasLength(1));
    expect(applyLedgerFilter(records, LedgerRanges.lastMonth()),
        hasLength(1));
    expect(applyLedgerFilter(records, LedgerRanges.lastDays(7)),
        hasLength(1));
    expect(applyLedgerFilter(records, LedgerRanges.allTime()),
        hasLength(3));

    expect(LedgerRanges.presetLabels, hasLength(5));
    for (var i = 0; i < LedgerRanges.presetLabels.length; i++) {
      expect(LedgerRanges.preset(i).isActive, isTrue,
          reason: 'preset ${LedgerRanges.presetLabels[i]} must be a real range');
    }
  });

  test('lastDays counts the window inclusively', () {
    final now = DateTime.now();
    final today = now.millisecondsSinceEpoch;
    final sixDaysAgo = DateTime(now.year, now.month, now.day - 6)
        .millisecondsSinceEpoch;
    final sevenDaysAgo = DateTime(now.year, now.month, now.day - 7)
        .millisecondsSinceEpoch;

    final out = applyLedgerFilter(
      [
        labeled(amount: 1, receipt: today, category: bebas),
        labeled(amount: 2, receipt: sixDaysAgo, category: bebas),
        labeled(amount: 3, receipt: sevenDaysAgo, category: bebas),
      ],
      LedgerRanges.lastDays(7),
    );

    expect(out.map((r) => r.totalAmount), [1, 2],
        reason: 'today plus the six days before it is seven days');
  });

  // ----------------------------------------------------------------- misc --

  test('an inactive filter reports itself as such', () {
    expect(const LedgerFilter.none().isActive, isFalse);
    expect(LedgerRanges.allTime().isActive, isTrue);
    expect(LedgerFilter(categoryName: 'Bebas').hasCategory, isTrue);
    expect(LedgerFilter(from: DateTime(2026, 1, 1)).hasPeriod, isTrue);
  });

  test('copyWith can clear each axis independently', () {
    final filter = LedgerFilter(
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 3, 31),
      categoryName: 'Bebas',
    );

    expect(filter.copyWith(clearCategory: true).categoryName, isNull);
    expect(filter.copyWith(clearCategory: true).hasPeriod, isTrue);
    expect(filter.copyWith(clearFrom: true).from, isNull);
    expect(filter.copyWith(clearFrom: true).to, DateTime(2026, 3, 31, 23, 59, 59, 999));
  });

  test('filters compare by value so identical selections do not redraw', () {
    expect(LedgerFilter(from: DateTime(2026, 1, 1)),
        LedgerFilter(from: DateTime(2026, 1, 1, 23, 30)));
    expect(
      LedgerFilter(from: DateTime(2026, 1, 1)),
      isNot(LedgerFilter(from: DateTime(2026, 1, 2))),
    );
  });
}
