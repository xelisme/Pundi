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
  // NOT call this (they go 100% to one category). Looks up the category by
  // name across ALL categories (including soft-deleted ones) so that money
  // allocated to a now-hidden category is not lost.
  List<CategorySplitResult> _splitBySnapshot(
      double amount, Map<String, double> snapshot) {
    final result = <CategorySplitResult>[];
    for (final entry in snapshot.entries) {
      final cat = _categories.where((c) => c.name == entry.key).firstOrNull;
      if (cat == null) continue; // category truly gone; skip
      final allocated = (amount * entry.value / 100).roundToDouble();
      result.add(
          CategorySplitResult(category: cat, allocatedAmount: allocated));
    }
    return result;
  }

  void recordIncome({
    required double amount,
    required String chargedToCategory,
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
      items: '',
      receiptDate: DateTime.now().millisecondsSinceEpoch,
      chargedTo: chargedToCategory,
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

  void addCategory(AllocationCategory category) {
    // If a soft-deleted category with the same name exists, restore it
    // (reactivate + update fields) instead of creating a duplicate.
    final existing = _categories
        .where((c) => !c.isActive && c.name.toLowerCase() == category.name.toLowerCase())
        .firstOrNull;
    if (existing != null) {
      _categories = _categories
          .map((c) => c.id == existing.id ? existing.copyWith(isActive: true) : c)
          .toList();
      _saveCategoriesLocal();
      notifyListeners();
      return;
    }
    _categories = [..._categories, category];
    _saveCategoriesLocal();
    notifyListeners();
  }

  void updateCategory(String id, AllocationCategory updated) {
    _categories = _categories.map((c) => c.id == id ? updated : c).toList();
    _saveCategoriesLocal();
    notifyListeners();
  }

  // Soft delete: mark inactive instead of removing, so historical transactions
  // in summaries are preserved (greyed out) and can be restored later.
  void deleteCategory(String id) {
    if (activeCategories.length <= 1) return; // keep at least one active
    _categories = _categories
        .map((c) => c.id == id ? c.copyWith(isActive: false) : c)
        .toList();
    _saveCategoriesLocal();
    notifyListeners();
  }

  // Restore a previously soft-deleted category.
  void restoreCategory(String id) {
    _categories = _categories
        .map((c) => c.id == id ? c.copyWith(isActive: true) : c)
        .toList();
    _saveCategoriesLocal();
    notifyListeners();
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

  String exportToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke,Snapshot');
    
    for (final record in _history) {
      final toko = _escapeCsv(record.merchantName.isEmpty ? 'Manual Input' : record.merchantName);
      final total = record.totalAmount.toInt();
      final items = _escapeCsv(record.items.isEmpty ? (record.type == TransactionType.income ? '${record.rawInput} (Pemasukan)' : record.rawInput) : record.items);
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
      
      buffer.writeln('$toko,$total,$items,$tanggalStruk,$tanggalInput,$waktuInput,$chargedTo,$snapshotStr');
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

      final isIncome = items.toLowerCase().contains('pemasukan') ||
          toko.toLowerCase().contains('pemasukan') ||
          (chargedTo != 'Bebas' && items.toLowerCase().contains('uang'));

      int receiptDate;
      try {
        receiptDate = DateTime.parse(tanggalStruk).millisecondsSinceEpoch;
      } catch (_) {
        receiptDate = DateTime.now().millisecondsSinceEpoch;
      }

      final merchantName = toko == 'Manual Input' ? '' : toko;
      final cleanItems =
          items.replaceAll(RegExp(r'\s*\(Pemasukan\)\s*', caseSensitive: false), '');

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
        rawInput: isIncome ? total.toString() : cleanItems,
        totalAmount: total,
        splits: splits,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        merchantName: merchantName,
        items: cleanItems,
        receiptDate: receiptDate,
        chargedTo: chargedTo,
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
