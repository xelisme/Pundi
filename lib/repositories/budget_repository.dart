import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class BudgetRepository extends ChangeNotifier {
  static const _keyCategories = 'key_categories_v1';
  static const _keyHistory = 'key_history_v1';

  List<AllocationCategory> _categories = [];
  List<TransactionRecord> _history = [];
  SharedPreferences? _prefs;
  final List<String> _lastImportFailedLines = [];

  List<String> get lastImportFailedLines => _lastImportFailedLines;

  List<AllocationCategory> get categories => _categories;
  List<TransactionRecord> get history => _history;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCategoriesLocal();
    _loadHistoryLocal();
  }

  void _loadCategoriesLocal() {
    final json = _prefs?.getString(_keyCategories);
    if (json == null || json.isEmpty) {
      _categories = _getDefaultCategories();
      _saveCategoriesLocal();
    } else {
      try {
        final list = (jsonDecode(json) as List<dynamic>)
            .map((e) => AllocationCategory.fromJson(e as Map<String, dynamic>))
            .toList();
        _categories = list;
      } catch (_) {
        _categories = _getDefaultCategories();
      }
    }
    notifyListeners();
  }

  void _saveCategoriesLocal() {
    final json = jsonEncode(_categories.map((c) => c.toJson()).toList());
    _prefs?.setString(_keyCategories, json);
  }

  void saveCategories(List<AllocationCategory> list) {
    _categories = list;
    _saveCategoriesLocal();
    notifyListeners();
  }

  void _loadHistoryLocal() {
    final json = _prefs?.getString(_keyHistory);
    if (json != null && json.isNotEmpty) {
      try {
        _history = (jsonDecode(json) as List<dynamic>)
            .map((e) => TransactionRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _history = [];
      }
    }
    notifyListeners();
  }

  void _saveHistoryLocal() {
    final json = jsonEncode(_history.map((r) => r.toJson()).toList());
    _prefs?.setString(_keyHistory, json);
  }

  Map<String, dynamic> exportAllData() {
    return {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'categories': _categories.map((c) => c.toJson()).toList(),
      'history': _history.map((r) => r.toJson()).toList(),
    };
  }

  void recordTransaction(TransactionRecord record) {
    _history = [record, ..._history];
    _saveHistoryLocal();
    notifyListeners();
  }

  // Build a frozen snapshot of ALL category percentages (name -> pct), so that
  // "Seluruhnya" transactions created while a category is hidden still allocate
  // to it (money is never silently lost). Active vs hidden only matters for the
  // visible allocation UI, not for the math.
  Map<String, double> _snapshotPercentages() =>
      {for (final c in _categories) c.name: c.percentage};

  // Split an amount across categories using a FROZEN percentage snapshot,
  // not the currently-active _categories. Explicit-label transactions must
  // NOT call this (they go 100% to one category).
  //
  // Only ACTIVE categories receive money. If a snapshot entry points to a
  // category that is now soft-deleted or permanently gone, its share is
  // redistributed proportionally across the remaining ACTIVE categories so
  // that the FULL amount is always allocated (no silent money loss).
  List<CategorySplitResult> _splitBySnapshot(
      double amount, Map<String, double> snapshot) {
    // 1) Active categories that still have a (non-zero) snapshot share.
    final activeShares = <AllocationCategory, double>{};
    double activePctSum = 0;
    for (final entry in snapshot.entries) {
      if (entry.value <= 0) continue;
      final cat = _categories
          .where((c) => c.name == entry.key && c.isActive)
          .firstOrNull;
      if (cat == null) continue; // soft-deleted / gone -> handled below
      activeShares[cat] = entry.value;
      activePctSum += entry.value;
    }

    // 2) If the active shares already sum to ~100, use them directly.
    if (activePctSum >= 99.999) {
      return [
        for (final e in activeShares.entries)
          CategorySplitResult(
            category: e.key,
            allocatedAmount: (amount * e.value / 100).roundToDouble(),
          )
      ];
    }

    // 3) Otherwise (some category was removed) redistribute the FULL amount
    //    across the active categories proportionally to their snapshot share.
    if (activeShares.isEmpty) {
      // Fallback: spread evenly across all active categories.
      final actives = activeCategories;
      if (actives.isEmpty) return [];
      final each = (amount / actives.length).roundToDouble();
      return [
        for (final c in actives)
          CategorySplitResult(category: c, allocatedAmount: each)
      ];
    }
    // Normalize active shares so they sum to 100, then split the full amount.
    return [
      for (final e in activeShares.entries)
        CategorySplitResult(
          category: e.key,
          allocatedAmount:
              (amount * (e.value / activePctSum)).roundToDouble(),
        )
    ];
  }

  /// Record income. [notes] is a free-form remark ("gajian", "bonus penjualan")
  /// and is stored in the same `items` column expenses use, so income and
  /// expense rows stay symmetrical all the way through history, summary and
  /// CSV without a second parallel field.
  void recordIncome({
    required double amount,
    required String chargedToCategory,
    String notes = '',
    String paymentMethod = defaultPaymentMethod,
  }) {
    List<CategorySplitResult> splits;
    Map<String, double> snapshot = const {};

    if (chargedToCategory == allCategoriesLabel) {
      // "Seluruhnya" -> freeze current percentages (all categories) at creation time.
      snapshot = _snapshotPercentages();
      splits = _splitBySnapshot(amount, snapshot);
    } else {
      final category =
          _categories.where((c) => c.name == chargedToCategory).firstOrNull;
      splits = category != null
          ? [CategorySplitResult(category: category, allocatedAmount: amount)]
          : <CategorySplitResult>[];
    }

    final record = TransactionRecord(
      rawInput: amount.toString(),
      totalAmount: amount,
      splits: splits,
      type: TransactionType.income,
      merchantName: '',
      items: notes,
      receiptDate: DateTime.now().millisecondsSinceEpoch,
      chargedTo: chargedToCategory,
      paymentMethod: paymentMethod,
      allocationSnapshot: snapshot,
    );
    _history = [record, ..._history];
    _saveHistoryLocal();
    notifyListeners();
  }

  void recordExpense({
    required String merchantName,
    required String items,
    required double amount,
    required String chargedToCategory,
    int? receiptDate,
    String paymentMethod = defaultPaymentMethod,
  }) {
    List<CategorySplitResult> splits;
    Map<String, double> snapshot = const {};

    if (chargedToCategory == allCategoriesLabel) {
      // "Seluruhnya" -> freeze current percentages at creation time.
      snapshot = _snapshotPercentages();
      splits = _splitBySnapshot(amount, snapshot);
    } else {
      final category =
          _categories.where((c) => c.name == chargedToCategory).firstOrNull;
      splits = category != null
          ? [CategorySplitResult(category: category, allocatedAmount: amount)]
          : <CategorySplitResult>[];
    }

    final record = TransactionRecord(
      rawInput: merchantName.isEmpty ? items : merchantName,
      totalAmount: amount,
      splits: splits,
      type: TransactionType.expense,
      merchantName: merchantName,
      items: items,
      receiptDate: receiptDate ?? DateTime.now().millisecondsSinceEpoch,
      chargedTo: chargedToCategory,
      paymentMethod: paymentMethod,
      allocationSnapshot: snapshot,
    );
    _history = [record, ..._history];
    _saveHistoryLocal();
    notifyListeners();
  }

  void deleteTransaction(String transactionId) {
    _history = _history.where((r) => r.id != transactionId).toList();
    _saveHistoryLocal();
    notifyListeners();
  }

  void clearHistory() {
    _history = [];
    _saveHistoryLocal();
    notifyListeners();
  }

  // Only active categories count for allocation / percentage math.
  List<AllocationCategory> get activeCategories =>
      _categories.where((c) => c.isActive).toList();

  // Archived categories are out of the way but still recoverable.
  List<AllocationCategory> get archivedCategories =>
      _categories.where((c) => c.isArchived).toList();

  void addCategory(AllocationCategory category) {
    // If a soft-deleted or archived category with the same name exists, revive
    // it (reactivate + un-archive) instead of creating a duplicate. The revived
    // row keeps its id and colour so historical splits still line up.
    final existing = _categories
        .where((c) => !c.isActive && c.name.toLowerCase() == category.name.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      _categories = _categories
          .map((c) => c.id == existing.id
              ? existing.copyWith(isActive: true, isArchived: false)
              : c)
          .toList();
      _saveCategoriesLocal();
      notifyListeners();
      return;
    }
    // Guard: adding must not push total ACTIVE allocation above 100%.
    final newTotal =
        activeCategories.fold<double>(0, (s, c) => s + c.percentage) +
            category.percentage;
    if (newTotal > 100.0001) return; // refused; UI surfaces the error
    _categories = [..._categories, category];
    _saveCategoriesLocal();
    notifyListeners();
  }

  void updateCategory(String id, AllocationCategory updated) {
    // Guard: editing must not push total ACTIVE allocation above 100%.
    final othersActive =
        activeCategories.where((c) => c.id != id);
    final newTotal =
        othersActive.fold<double>(0, (s, c) => s + c.percentage) +
            updated.percentage;
    if (newTotal > 100.0001) return; // refused; UI surfaces the error
    _categories = _categories.map((c) => c.id == id ? updated : c).toList();
    _saveCategoriesLocal();
    notifyListeners();
  }

  // Soft delete (stage 1 of 2): mark inactive instead of archiving, so the
  // category stays visible in the "dihapus" list and can be reactivated with
  // one tap. A soft-deleted category can NOT receive new income/expense (the
  // input dropdowns only list activeCategories), but its past transactions
  // remain.
  void deleteCategory(String id) {
    if (activeCategories.length <= 1) return; // keep at least one active
    _categories = _categories
        .map((c) => c.id == id ? c.copyWith(isActive: false) : c)
        .toList();
    _saveCategoriesLocal();
    notifyListeners();
  }

  // Count transactions that touch a category: explicitly charged to it, or a
  // "Seluruhnya" transaction whose frozen snapshot included it.
  int transactionCountForCategory(String categoryName) {
    final cat = _categories.where((c) => c.name == categoryName).firstOrNull;
    if (cat == null) return 0;
    return _history.where(_referencesCategory(cat)).length;
  }

  // A transaction "references" a category if it is explicitly charged to it,
  // or is a "Seluruhnya" transaction whose frozen snapshot included it.
  bool Function(TransactionRecord) _referencesCategory(AllocationCategory cat) =>
      (TransactionRecord t) =>
          t.chargedTo == cat.name ||
          (t.chargedTo == allCategoriesLabel &&
              t.allocationSnapshot.containsKey(cat.name));

  /// Archive a category — the terminal step of deletion (stage 2 of 2).
  ///
  /// The row is NEVER destroyed: it is flagged `isArchived` and drops out of
  /// every list, but `restoreCategory` can always bring it back. All of its
  /// transactions are reassigned first so no money or record is lost, and
  /// `reassignTo` is REQUIRED whenever the category has transactions.
  ///
  /// A category counts as "having transactions" if any transaction is
  /// explicitly charged to it OR is a "Seluruhnya" transaction whose frozen
  /// snapshot included it (so its money must be redistributed).
  bool archiveCategory(String id, {String? reassignTo}) {
    final cat = _categories.where((c) => c.id == id).firstOrNull;
    if (cat == null) return false;
    if (cat.isArchived) return false; // already archived
    // Keep at least one usable category around.
    if (_categories.where((c) => !c.isArchived).length <= 1) return false;

    final txCount = _history.where(_referencesCategory(cat)).length;

    if (txCount > 0) {
      // Reassignment is mandatory when transactions exist.
      if (reassignTo == null || reassignTo.isEmpty) return false;
      if (reassignTo == cat.name) return false; // never onto itself
      if (reassignTo != allCategoriesLabel) {
        final target = _categories
            .where((c) => c.name == reassignTo && c.isActive)
            .firstOrNull;
        if (target == null) return false; // must reassign to a real active cat
      }
    }

    // Archive FIRST so that re-splitting below cannot route money back into
    // `cat` — _snapshotPercentages() must already exclude it.
    _categories = _categories
        .map((c) => c.id == id
            ? c.copyWith(isActive: false, isArchived: true)
            : c)
        .toList();
    _saveCategoriesLocal();

    if (txCount > 0) {
      // Reassign every transaction that references this category:
      //  - explicit-label tx (chargedTo == cat.name), or
      //  - "Seluruhnya" tx whose frozen snapshot included this category.
      _history = _history.map((t) {
        if (!_referencesCategory(cat)(t)) return t;

        if (reassignTo == allCategoriesLabel) {
          // Re-split via "Seluruhnya": drop the deleted category's entry from
          // the snapshot so _splitBySnapshot redistributes its share to the
          // remaining ACTIVE categories (full amount preserved).
          final adjusted = Map<String, double>.from(t.allocationSnapshot)
            ..remove(cat.name);
          final snapshot = adjusted.isNotEmpty
              ? adjusted
              : _snapshotPercentages();
          return TransactionRecord(
            id: t.id,
            timestamp: t.timestamp,
            rawInput: t.rawInput,
            totalAmount: t.totalAmount,
            splits: _splitBySnapshot(t.totalAmount, snapshot),
            type: t.type,
            merchantName: t.merchantName,
            items: t.items,
            receiptDate: t.receiptDate,
            chargedTo: reassignTo,
            paymentMethod: t.paymentMethod,
            allocationSnapshot: snapshot,
          );
        }
        // Reassign 100% to the chosen active category.
        final target = _categories.firstWhere((c) => c.name == reassignTo);
        return TransactionRecord(
          id: t.id,
          timestamp: t.timestamp,
          rawInput: t.rawInput,
          totalAmount: t.totalAmount,
          splits: [CategorySplitResult(category: target, allocatedAmount: t.totalAmount)],
          type: t.type,
          merchantName: t.merchantName,
          items: t.items,
          receiptDate: t.receiptDate,
          chargedTo: reassignTo,
          paymentMethod: t.paymentMethod,
          allocationSnapshot: const {},
        );
      }).toList();
      _saveHistoryLocal();
    }

    notifyListeners();
    return true;
  }

  /// Bring a soft-deleted OR archived category back.
  ///
  /// Un-archiving is unconditional — an archived category always returns to the
  /// "dihapus" list so it can never be stranded. Re-activating it as well is
  /// conditional: refused when that would push total ACTIVE allocation above
  /// 100%. Returns true when the category is active again, false when it came
  /// back but stayed inactive (no budget headroom).
  bool restoreCategory(String id) {
    final target = _categories.where((c) => c.id == id).firstOrNull;
    if (target == null || (target.isActive && !target.isArchived)) return false;
    final newTotal =
        activeCategories.fold<double>(0, (s, c) => s + c.percentage) +
            target.percentage;
    final canActivate = newTotal <= 100.0001;
    _categories = _categories
        .map((c) => c.id == id
            ? c.copyWith(isActive: canActivate, isArchived: false)
            : c)
        .toList();
    _saveCategoriesLocal();
    notifyListeners();
    return canActivate;
  }

  void updateTransactionChargedTo(String transactionId, String newChargedTo) {
    final idx = _history.indexWhere((t) => t.id == transactionId);
    if (idx < 0) return;

    final old = _history[idx];
    List<CategorySplitResult> splits;

    if (newChargedTo == allCategoriesLabel) {
      // Re-split using the transaction's OWN frozen snapshot, not current categories.
      splits = _splitBySnapshot(old.totalAmount, old.allocationSnapshot);
    } else {
      final category =
          _categories.where((c) => c.name == newChargedTo).firstOrNull;
      splits = category != null
          ? [
              CategorySplitResult(
                  category: category, allocatedAmount: old.totalAmount)
            ]
          : <CategorySplitResult>[];
    }

    _history[idx] = TransactionRecord(
      id: old.id,
      timestamp: old.timestamp,
      rawInput: old.rawInput,
      totalAmount: old.totalAmount,
      splits: splits,
      type: old.type,
      merchantName: old.merchantName,
      items: old.items,
      receiptDate: old.receiptDate,
      chargedTo: newChargedTo,
      paymentMethod: old.paymentMethod,
      allocationSnapshot: old.allocationSnapshot,
    );
    _saveHistoryLocal();
    notifyListeners();
  }

  void updateTransaction({
    required String transactionId,
    double? newAmount,
    String? newMerchantName,
    String? newItems,
    String? newChargedTo,
    int? newReceiptDate,
    String? newPaymentMethod,
  }) {
    final idx = _history.indexWhere((t) => t.id == transactionId);
    if (idx < 0) return;

    final old = _history[idx];
    final amount = newAmount ?? old.totalAmount;
    final chargedTo = newChargedTo ?? old.chargedTo;

    List<CategorySplitResult> splits;
    Map<String, double> snapshot = old.allocationSnapshot;

    final isAll = chargedTo == allCategoriesLabel || chargedTo == null;
    if (isAll) {
      // "Seluruhnya": re-split using the FROZEN snapshot, never current categories.
      splits = _splitBySnapshot(amount, old.allocationSnapshot);
    } else {
      // Explicit label: 100% to that category, percentages ignored entirely.
      final category = _categories.where((c) => c.name == chargedTo).firstOrNull;
      splits = category != null
          ? [CategorySplitResult(category: category, allocatedAmount: amount)]
          : old.splits;
    }

    _history[idx] = TransactionRecord(
      id: old.id,
      timestamp: old.timestamp,
      rawInput: old.rawInput,
      totalAmount: amount,
      splits: splits,
      type: old.type,
      merchantName: newMerchantName ?? old.merchantName,
      items: newItems ?? old.items,
      receiptDate: newReceiptDate ?? old.receiptDate,
      chargedTo: chargedTo,
      paymentMethod: newPaymentMethod ?? old.paymentMethod,
      allocationSnapshot: snapshot,
    );
    _saveHistoryLocal();
    notifyListeners();
  }

  void resetToDefaults() {
    _categories = _getDefaultCategories();
    _saveCategoriesLocal();
    notifyListeners();
  }

  void resetAllData() {
    _categories = _getDefaultCategories();
    _history = [];
    _saveCategoriesLocal();
    _saveHistoryLocal();
    notifyListeners();
  }

  static List<AllocationCategory> _getDefaultCategories() {
    return [
      AllocationCategory(
        name: 'Tabungan',
        percentage: 50.0,
        colorHex: '#3B82F6',
        iconName: 'savings',
        description: 'Tabungan & Dana Darurat',
      ),
      AllocationCategory(
        name: 'Investasi',
        percentage: 30.0,
        colorHex: '#10B981',
        iconName: 'trending_up',
        description: 'Saham, Crypto, Reksadana',
      ),
      AllocationCategory(
        name: 'Bebas',
        percentage: 20.0,
        colorHex: '#F59E0B',
        iconName: 'shopping_bag',
        description: 'Gaya Hidup & Hiburan',
      ),
    ];
  }

  /// Parse a date cell from a CSV, optionally with a separate time-of-day cell.
  ///
  /// Returns [fallback] when the cell is empty or unparseable, so one malformed
  /// date never takes down an entire import.
  int _parseCsvDate(String cell, {String? waktu, int? fallback}) {
    final raw = cell.trim();
    if (raw.isEmpty) return fallback ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final dateOnly = DateTime.parse(raw);
      final parts = (waktu ?? '').trim().split(':').map(int.tryParse).toList();
      if (parts.length < 2 || parts[0] == null || parts[1] == null) {
        return dateOnly.millisecondsSinceEpoch;
      }
      final hour = parts[0]!;
      final minute = parts[1]!;
      final second = parts.length > 2 && parts[2] != null ? parts[2]! : 0;
      // Reuse the date's y/m/d and take the time-of-day from the other cell, so
      // "2026-10-01" + "12:51:57" yields that exact instant rather than midnight.
      return DateTime(
        dateOnly.year,
        dateOnly.month,
        dateOnly.day,
        hour,
        minute,
        second,
      ).millisecondsSinceEpoch;
    } catch (_) {
      return fallback ?? DateTime.now().millisecondsSinceEpoch;
    }
  }

  String exportToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot,Metode Pembayaran');
    
    for (final record in _history) {
      final toko = _escapeCsv(record.merchantName.isEmpty ? 'Manual Input' : record.merchantName);
      final total = record.totalAmount.toInt();
      // Income rows ALWAYS carry the "(Pemasukan)" marker, even when they
      // have notes — importFromCsv uses it to tell income from expense, so a
      // note that happens to read like an expense must not flip the row's type.
      final items = record.type == TransactionType.income
          ? _escapeCsv('${record.items.isEmpty ? record.rawInput : record.items} (Pemasukan)')
          : _escapeCsv(record.items.isEmpty ? record.rawInput : record.items);
      final tanggalStruk = record.receiptDate > 0 
          ? DateTime.fromMillisecondsSinceEpoch(record.receiptDate).toIso8601String().substring(0, 10)
          : DateTime.fromMillisecondsSinceEpoch(record.timestamp).toIso8601String().substring(0, 10);
      final tanggalInput = DateTime.fromMillisecondsSinceEpoch(record.timestamp).toIso8601String().substring(0, 10);
      final waktuInput = DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(record.timestamp));
      final chargedTo = record.chargedTo ?? allCategoriesLabel;
      // Frozen allocation snapshot, e.g. "Tabungan:50;Investasi:30;Bebas:20".
      // Empty for explicit-label transactions (they ignore percentages).
      final snapshotStr = record.allocationSnapshot.entries
          .map((e) => '${e.key}:${e.value.toInt()}')
          .join(';');
      
      // Appended last so older 8-column exports keep importing unchanged.
      buffer.writeln('$toko,$total,$items,$tanggalStruk,$tanggalInput,$waktuInput,$chargedTo,$snapshotStr,${_escapeCsv(record.paymentMethod)}');
    }
    
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  int importFromCsv(String csvContent) {
    _lastImportFailedLines.clear();

    // RFC 4180-compliant parse via the `csv` package. Handles quoted fields
    // with embedded newlines, commas, and "" escapes — no manual split.
    final rows = const CsvToListConverter(
      fieldDelimiter: ',',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent.trim());

    if (rows.length < 2) {
      _lastImportFailedLines.add('File kosong atau hanya berisi header.');
      return 0;
    }

    int imported = 0;
    // rows[0] = header; data starts at index 1.
    for (int i = 1; i < rows.length; i++) {
      final parts = rows[i].map((e) => e.toString()).toList();
      if (parts.length < 7) {
        _lastImportFailedLines
            .add('Baris ${i + 1}: kolom tidak lengkap (${parts.length}/7 minimal)');
        continue;
      }

      final toko = parts[0].trim();
      final totalStr = parts[1].trim();
      final total = double.tryParse(totalStr);
      if (total == null || total <= 0) {
        _lastImportFailedLines
            .add('Baris ${i + 1}: nominal tidak valid "$totalStr"');
        continue;
      }

      final items = parts[2];
      final tanggalStruk = parts[3];
      final chargedTo = parts[6];
      // Column 7 (optional): frozen allocation snapshot from export, e.g.
      // "Tabungan:50;Investasi:30;Bebas:20". Empty/old files -> use fallback.
      final snapshotRaw = parts.length > 7 ? parts[7].trim() : '';
      final importedSnapshot = _parseSnapshot(snapshotRaw);
      // Column 8 (optional): payment method. Files exported before this field
      // existed simply have no 9th column and fall back to the default.
      final paymentMethod = (parts.length > 8 && parts[8].trim().isNotEmpty)
          ? parts[8].trim()
          : defaultPaymentMethod;

      final isIncome = items.toLowerCase().contains('pemasukan') ||
          toko.toLowerCase().contains('pemasukan') ||
          (chargedTo != 'Bebas' && items.toLowerCase().contains('uang'));

      // Two dates, two jobs:
      //   receiptDate  — when the money actually moved (Tanggal Struk). This is
      //                  what a month total is built from.
      //   timestamp    — when the row was keyed in (Tanggal Input + Waktu
      //                  Input). Order-by and "Struk: ..." display only.
      //
      // Both must come from the file. Stamping either with DateTime.now()
      // collapses every imported month into the import month, which is what
      // made Ringkasan totals wrong after a CSV import.
      final receiptDate =
          _parseCsvDate(tanggalStruk, fallback: DateTime.now().millisecondsSinceEpoch);
      // Fall back to the receipt instant when the file has no input date, so a
      // row is never filed under an unrelated month.
      final inputDate = _parseCsvDate(
        parts.length > 4 ? parts[4] : '',
        waktu: parts.length > 5 ? parts[5] : '',
        fallback: receiptDate,
      );

      final merchantName = toko == 'Manual Input' ? '' : toko;
      var cleanItems =
          items.replaceAll(RegExp(r'\s*\(Pemasukan\)\s*', caseSensitive: false), '');
      // Older exports wrote the amount into the Items column when an income row
      // had no note ("107000.0 (Pemasukan)"), so re-importing those files put
      // the amount on screen as if the user had typed it. A cleaned value that
      // is exactly the row total is that artefact, not a note.
      if (isIncome && cleanItems.trim().isNotEmpty) {
        final asNumber = double.tryParse(cleanItems.trim().replaceAll(',', ''));
        if (asNumber != null && (asNumber - total).abs() < 0.005) {
          cleanItems = '';
        }
      }
      cleanItems = cleanItems.trim();

      List<CategorySplitResult> splits;
      Map<String, double> snapshot;
      if (chargedTo == allCategoriesLabel || chargedTo.isEmpty) {
        // "Seluruhnya": prefer the frozen snapshot from the CSV; only fall back
        // to current percentages when the file has no snapshot column (legacy).
        if (importedSnapshot.isNotEmpty) {
          snapshot = importedSnapshot;
        } else {
          snapshot = _snapshotPercentages();
        }
        splits = _splitBySnapshot(total, snapshot);
      } else {
        // Explicit category label -> 100% to that category, percentages ignored.
        final category =
            _categories.where((c) => c.name == chargedTo).firstOrNull;
        splits = category != null
            ? [CategorySplitResult(category: category, allocatedAmount: total)]
            : <CategorySplitResult>[];
        snapshot = const {};
      }

      final record = TransactionRecord(
        timestamp: inputDate,
        rawInput: isIncome ? total.toString() : cleanItems,
        totalAmount: total,
        splits: splits,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        merchantName: merchantName,
        items: cleanItems,
        receiptDate: receiptDate,
        chargedTo: chargedTo,
        paymentMethod: paymentMethod,
        allocationSnapshot: snapshot,
      );
      _history = [record, ..._history];
      imported++;
    }

    _saveHistoryLocal();
    notifyListeners();
    return imported;
  }

  // Parse "Tabungan:50;Investasi:30;Bebas:20" -> {Tabungan:50,...}
  Map<String, double> _parseSnapshot(String raw) {
    final map = <String, double>{};
    if (raw.isEmpty) return map;
    for (final pair in raw.split(';')) {
      final kv = pair.split(':');
      if (kv.length == 2) {
        final name = kv[0].trim();
        final pct = double.tryParse(kv[1].trim());
        if (name.isNotEmpty && pct != null) map[name] = pct;
      }
    }
    return map;
  }
}
