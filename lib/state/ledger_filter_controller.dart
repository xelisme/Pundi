import 'package:flutter/foundation.dart';

import '../models/ledger_filter.dart';

/// Holds the period-and-category selection that Ringkasan writes and Riwayat
/// reads.
///
/// It lives above the tab shell rather than inside either screen because the
/// two need to agree on one selection: Ringkasan states a total, and Riwayat has
/// to show exactly the records behind that total. If each screen kept its own
/// copy they would drift, and the list would stop adding up to the number above
/// it.
///
/// Ringkasan is the writer for now; Riwayat only reads and clears.
class LedgerFilterController extends ChangeNotifier {
  LedgerFilter _filter = const LedgerFilter.none();

  LedgerFilter get filter => _filter;

  bool get isActive => _filter.isActive;
  bool get hasCategory => _filter.hasCategory;
  bool get hasPeriod => _filter.hasPeriod;

  /// No-op when the selection is unchanged, so setting the same filter on every
  /// rebuild does not wake Riwayat for nothing.
  void setFilter(LedgerFilter next) {
    if (next == _filter) return;
    _filter = next;
    notifyListeners();
  }

  void setCategory(String? categoryName) => setFilter(
        _filter.copyWith(
          categoryName: categoryName,
          clearCategory: categoryName == null,
        ),
      );

  void setPeriod({DateTime? from, DateTime? to, bool clear = false}) =>
      setFilter(_filter.copyWith(
        from: from,
        to: to,
        clearFrom: clear || from == null,
        clearTo: clear || to == null,
      ));

  void clear() => setFilter(const LedgerFilter.none());
}
