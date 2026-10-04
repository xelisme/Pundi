import 'package:intl/intl.dart';

import 'transaction.dart';
import 'period_summary.dart';

/// Which slice of the ledger the user is asking about.
///
/// Two independent axes, and the whole point is that either one can be used
/// alone: a period with no category, a category with no period, or both
/// together.
///
/// [categoryName] is a name rather than an id on purpose. Every category total
/// in this app has always been keyed by name — see [PeriodSummary]'s
/// breakdowns — and a transaction's frozen splits carry the category object the
/// row was written with, which may be a copy that no longer shares the current
/// list's identity. Matching on name keeps one lookup convention instead of two.
class LedgerFilter {
  /// Inclusive first day, or null for "since the beginning".
  final DateTime? from;

  /// Inclusive last day, or null for "up to now". Normalised to the end of that
  /// day on construction so callers can pass a bare date.
  final DateTime? to;

  /// Null means every category.
  final String? categoryName;

  LedgerFilter({
    DateTime? from,
    DateTime? to,
    this.categoryName,
  })  : from = from == null ? null : DateTime(from.year, from.month, from.day),
        // End of the named day. Comparing against `>= endOfDay` would drop a
        // transaction logged at 23:59, which is the kind of off-by-one that
        // makes a total look wrong with no visible cause.
        to = to == null ? null : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

  /// Everything, every category. Also the state Pengaturan and Riwayat return
  /// to when no filter is set, so it must be the "do nothing" default.
  const LedgerFilter.none()
      : from = null,
        to = null,
        categoryName = null;

  bool get hasPeriod => from != null || to != null;
  bool get hasCategory => categoryName != null;

  /// "semua kategori" reads as a sentence; a null category is not a category.
  String get categoryLabel => categoryName ?? 'semua kategori';

  /// How the period reads to a person, mixed case.
  ///
  /// Lives here rather than in each screen because two screens describing one
  /// selection differently is how a filter chip ends up claiming a range the
  /// list does not hold. Same month collapses to "1 - 30 Sep 2026" instead of
  /// repeating the month name twice.
  String get periodLabel {
    if (from == null && to == null) return 'semua periode';
    if (from == null) return 'sampai ${_day(to!)}';
    if (to == null) return 'sejak ${_day(from!)}';
    if (from!.year == to!.year && from!.month == to!.month) {
      return '${from!.day} - ${_day(to!)}';
    }
    return '${_day(from!)} - ${_day(to!)}';
  }

  /// One phrase covering both axes, for a filter banner.
  String get describe {
    if (hasCategory && hasPeriod) return '$categoryLabel · $periodLabel';
    if (hasCategory) return 'Kategori $categoryLabel';
    return 'Periode $periodLabel';
  }

  static String _day(DateTime d) =>
      DateFormat('d MMM yyyy', 'id_ID').format(d);

  /// True when this filter would actually remove something, which is what
  /// decides whether the UI shows a "filter active" chip at all.
  bool get isActive => hasPeriod || hasCategory;

  /// True when [record]'s receipt date falls inside the period.
  bool containsDate(TransactionRecord record) {
    if (!hasPeriod) return true;
    final date = DateTime.fromMillisecondsSinceEpoch(effectiveDate(record));
    if (from != null && date.isBefore(from!)) return false;
    if (to != null && date.isAfter(to!)) return false;
    return true;
  }

  /// True when [record] touches [categoryName], judged by its frozen splits.
  /// A record with no splits falls back to its label, matching how
  /// [calculatePeriodSummary] attributes the same malformed row.
  bool containsCategory(TransactionRecord record) {
    if (!hasCategory) return true;
    if (record.splits.isNotEmpty) {
      return record.splits.any((s) => s.category.name == categoryName);
    }
    return record.chargedTo == categoryName;
  }

  LedgerFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? categoryName,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearCategory = false,
  }) =>
      LedgerFilter(
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
        categoryName:
            clearCategory ? null : (categoryName ?? this.categoryName),
      );

  @override
  bool operator ==(Object other) =>
      other is LedgerFilter &&
      other.from == from &&
      other.to == to &&
      other.categoryName == categoryName;

  @override
  int get hashCode => Object.hash(from, to, categoryName);

  @override
  String toString() =>
      'LedgerFilter(from: $from, to: $to, category: $categoryName)';
}

/// Narrow [records] to [filter], re-scaling each survivor to what it actually
/// contributes to the filtered view.
///
/// The re-scaling is the whole point. A "Seluruhnya" income of 500.000 split
/// 50/30/20 across Tabungan/Investasi/Bebas contributes 100.000 to a Bebas
/// view, so the returned record carries 100.000 and only the Bebas split. Sum
/// the results and the total is genuinely the money that went to that category,
/// instead of the whole receipt appearing under every category at once.
///
/// Dates are judged by [effectiveDate] — the receipt date — for the same reason
/// month totals are: a 30-Sep receipt keyed in on 1 Oct is September money.
List<TransactionRecord> applyLedgerFilter(
  List<TransactionRecord> records,
  LedgerFilter filter,
) {
  if (!filter.isActive) return records;

  final out = <TransactionRecord>[];
  for (final record in records) {
    if (!filter.containsDate(record)) continue;
    if (!filter.hasCategory) {
      out.add(record);
      continue;
    }

    final matching = record.splits
        .where((s) => s.category.name == filter.categoryName)
        .toList();

    // No splits at all: the row is attributed by its label instead. Nothing to
    // narrow, and the full amount belongs to that label.
    if (record.splits.isEmpty) {
      if (record.chargedTo == filter.categoryName) out.add(record);
      continue;
    }

    if (matching.isEmpty) continue;
    final attributed =
        matching.fold<double>(0, (sum, s) => sum + s.allocatedAmount);
    out.add(record.copyWith(
      totalAmount: attributed,
      splits: matching,
    ));
  }
  return out;
}

/// Ready-made periods, so the UI offers the ranges people actually ask for
/// instead of making everyone pick two dates by hand.
class LedgerRanges {
  const LedgerRanges._();

  static DateTime _today() => DateTime.now();

  static LedgerFilter thisMonth() {
    final now = _today();
    return LedgerFilter(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month + 1, 0),
    );
  }

  static LedgerFilter lastMonth() {
    final now = _today();
    return LedgerFilter(
      from: DateTime(now.year, now.month - 1, 1),
      to: DateTime(now.year, now.month, 0),
    );
  }

  static LedgerFilter lastDays(int count) {
    final now = _today();
    return LedgerFilter(
      from: DateTime(now.year, now.month, now.day - (count - 1)),
      to: now,
    );
  }

  /// Every month on file, no ceiling.
  static LedgerFilter allTime() => LedgerFilter(
        from: DateTime(2000),
        to: DateTime(2100),
      );

  static LedgerFilter custom(DateTime from, DateTime to) =>
      LedgerFilter(from: from, to: to);

  /// Named presets offered in the period picker. Kept as data so the UI does not
  /// hardcode an order that then drifts from the tests.
  static const List<String> presetLabels = [
    'Bulan ini',
    'Bulan lalu',
    '7 hari',
    '30 hari',
    'Semua',
  ];

  static LedgerFilter preset(int index) {
    switch (index) {
      case 0:
        return thisMonth();
      case 1:
        return lastMonth();
      case 2:
        return lastDays(7);
      case 3:
        return lastDays(30);
      default:
        return allTime();
    }
  }
}
