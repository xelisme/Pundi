import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const String allCategoriesLabel = 'Seluruhnya';

enum TransactionType { income, expense }

class AllocationCategory {
  final String id;
  final String name;
  final double percentage;
  final String colorHex;
  final String iconName;
  final String description;

  AllocationCategory({
    String? id,
    required this.name,
    required this.percentage,
    required this.colorHex,
    this.iconName = 'account_balance_wallet',
    this.description = '',
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'percentage': percentage,
        'colorHex': colorHex,
        'iconName': iconName,
        'description': description,
      };

  factory AllocationCategory.fromJson(Map<String, dynamic> json) =>
      AllocationCategory(
        id: json['id'] as String?,
        name: json['name'] as String,
        percentage: (json['percentage'] as num).toDouble(),
        colorHex: json['colorHex'] as String,
        iconName: json['iconName'] as String? ?? 'account_balance_wallet',
        description: json['description'] as String? ?? '',
      );
}

class CategorySplitResult {
  final AllocationCategory category;
  final double allocatedAmount;

  CategorySplitResult({required this.category, required this.allocatedAmount});

  Map<String, dynamic> toJson() => {
        'category': category.toJson(),
        'allocatedAmount': allocatedAmount,
      };

  factory CategorySplitResult.fromJson(Map<String, dynamic> json) =>
      CategorySplitResult(
        category: AllocationCategory.fromJson(
            json['category'] as Map<String, dynamic>),
        allocatedAmount: (json['allocatedAmount'] as num).toDouble(),
      );
}

class TransactionRecord {
  final String id;
  final int timestamp;
  final String rawInput;
  final double totalAmount;
  final List<CategorySplitResult> splits;
  final TransactionType type;
  final String merchantName;
  final String items;
  final int receiptDate;
  final String? chargedTo;
  // Frozen allocation percentages (category name -> percentage) captured at
  // creation time. Only meaningful for "Seluruhnya" transactions; explicit
  // category transactions ignore this entirely.
  final Map<String, double> allocationSnapshot;

  TransactionRecord({
    String? id,
    int? timestamp,
    required this.rawInput,
    required this.totalAmount,
    this.splits = const [],
    this.type = TransactionType.income,
    this.merchantName = '',
    this.items = '',
    int? receiptDate,
    this.chargedTo,
    this.allocationSnapshot = const {},
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch,
        receiptDate = receiptDate ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'rawInput': rawInput,
        'totalAmount': totalAmount,
        'splits': splits.map((s) => s.toJson()).toList(),
        'type': type.name,
        'merchantName': merchantName,
        'items': items,
        'receiptDate': receiptDate,
        'chargedTo': chargedTo,
        'allocationSnapshot': allocationSnapshot,
      };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) =>
      TransactionRecord(
        id: json['id'] as String?,
        timestamp: json['timestamp'] as int?,
        rawInput: json['rawInput'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        splits: (json['splits'] as List<dynamic>?)
                ?.map((s) =>
                    CategorySplitResult.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        type: TransactionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => TransactionType.income,
        ),
        merchantName: json['merchantName'] as String? ?? '',
        items: json['items'] as String? ?? '',
        receiptDate: json['receiptDate'] as int?,
        chargedTo: json['chargedTo'] as String?,
        allocationSnapshot: (json['allocationSnapshot'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
}
