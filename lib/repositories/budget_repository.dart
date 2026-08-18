import 'dart:convert';
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

  void recordExpense({
    required String merchantName,
    required String items,
    required double amount,
    required String chargedToCategory,
    int? receiptDate,
  }) {
    List<CategorySplitResult> splits;

    if (chargedToCategory == allCategoriesLabel) {
      // Split across all categories by percentage
      splits = _categories.map((cat) {
        final allocated = (amount * cat.percentage / 100).roundToDouble();
        return CategorySplitResult(category: cat, allocatedAmount: allocated);
      }).toList();
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

  void addCategory(AllocationCategory category) {
    _categories = [..._categories, category];
    _saveCategoriesLocal();
    notifyListeners();
  }

  void updateCategory(String id, AllocationCategory updated) {
    _categories = _categories.map((c) => c.id == id ? updated : c).toList();
    _saveCategoriesLocal();
    notifyListeners();
  }

  void deleteCategory(String id) {
    if (_categories.length <= 1) return;
    _categories = _categories.where((c) => c.id != id).toList();
    _saveCategoriesLocal();
    notifyListeners();
  }

  void updateTransactionChargedTo(String transactionId, String newChargedTo) {
    final idx = _history.indexWhere((t) => t.id == transactionId);
    if (idx < 0) return;

    final old = _history[idx];
    List<CategorySplitResult> splits;

    if (newChargedTo == allCategoriesLabel) {
      splits = _categories.map((cat) {
        final allocated = (old.totalAmount * cat.percentage / 100).roundToDouble();
        return CategorySplitResult(category: cat, allocatedAmount: allocated);
      }).toList();
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

    if (old.type == TransactionType.income) {
      // For income, recalculate splits based on current categories
      if (chargedTo == allCategoriesLabel || chargedTo == null) {
        splits = _categories.map((cat) {
          final allocated = (amount * cat.percentage / 100).roundToDouble();
          return CategorySplitResult(category: cat, allocatedAmount: allocated);
        }).toList();
      } else {
        // Income to specific category
        final category = _categories.where((c) => c.name == chargedTo).firstOrNull;
        splits = category != null
            ? [CategorySplitResult(category: category, allocatedAmount: amount)]
            : old.splits;
      }
    } else {
      // For expense
      if (chargedTo == allCategoriesLabel) {
        splits = _categories.map((cat) {
          final allocated = (amount * cat.percentage / 100).roundToDouble();
          return CategorySplitResult(category: cat, allocatedAmount: allocated);
        }).toList();
      } else {
        final category = _categories.where((c) => c.name == chargedTo).firstOrNull;
        splits = category != null
            ? [CategorySplitResult(category: category, allocatedAmount: amount)]
            : old.splits;
      }
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
    buffer.writeln('Toko,Total,Items,Tanggal Struk,Tanggal Input,Waktu Input,Dibebankan Ke');
    
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
      
      buffer.writeln('$toko,$total,$items,$tanggalStruk,$tanggalInput,$waktuInput,$chargedTo');
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
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return 0;
    
    int imported = 0;
    for (int i = 1; i < lines.length; i++) {
      final parts = _parseCsvLine(lines[i]);
      if (parts.length < 7) continue;
      
      final toko = parts[0];
      final total = double.tryParse(parts[1]) ?? 0;
      final items = parts[2];
      final tanggalStruk = parts[3];
      final chargedTo = parts[6];
      
      if (total <= 0) continue;
      
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
      final cleanItems = items.replaceAll(RegExp(r'\s*\(Pemasukan\)\s*', caseSensitive: false), '');
      
      if (isIncome) {
        final splits = _categories.map((cat) {
          final allocated = (total * cat.percentage / 100).roundToDouble();
          return CategorySplitResult(category: cat, allocatedAmount: allocated);
        }).toList();
        
        final record = TransactionRecord(
          rawInput: total.toString(),
          totalAmount: total,
          splits: splits,
          type: TransactionType.income,
          merchantName: merchantName,
          items: cleanItems,
          receiptDate: receiptDate,
          chargedTo: chargedTo,
        );
        _history = [record, ..._history];
      } else {
        final targetCategory = chargedTo == allCategoriesLabel ? chargedTo : chargedTo;
        List<CategorySplitResult> splits;
        
        if (targetCategory == allCategoriesLabel) {
          splits = _categories.map((cat) {
            final allocated = (total * cat.percentage / 100).roundToDouble();
            return CategorySplitResult(category: cat, allocatedAmount: allocated);
          }).toList();
        } else {
          final category = _categories.where((c) => c.name == targetCategory).firstOrNull;
          splits = category != null
              ? [CategorySplitResult(category: category, allocatedAmount: total)]
              : <CategorySplitResult>[];
        }
        
        final record = TransactionRecord(
          rawInput: cleanItems,
          totalAmount: total,
          splits: splits,
          type: TransactionType.expense,
          merchantName: merchantName,
          items: cleanItems,
          receiptDate: receiptDate,
          chargedTo: chargedTo,
        );
        _history = [record, ..._history];
      }
      imported++;
    }
    
    _saveHistoryLocal();
    notifyListeners();
    return imported;
  }

  List<String> _parseCsvLine(String line) {
    final parts = <String>[];
    final current = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        parts.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    parts.add(current.toString());
    return parts;
  }
}
