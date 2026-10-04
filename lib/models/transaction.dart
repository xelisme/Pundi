import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const String allCategoriesLabel = 'Seluruhnya';

/// Payment methods offered when recording a transaction.
///
/// Stored as a plain String on the record rather than an enum, so adding or
/// renaming a method never needs a data migration for existing installs.
const List<String> paymentMethods = [
  'Tunai',
  'QRIS',
  'Transfer Bank',
  'Kartu Debit',
  'Kartu Kredit',
  'E-Wallet',
  'Lainnya',
];

const String defaultPaymentMethod = 'Tunai';

enum TransactionType { income, expense }

class AllocationCategory {
  final String id;
  final String name;
  final double percentage;
  final String colorHex;
  final String iconName;
  final String description;
  // Soft-delete flag. When false the category is hidden from active use but
  // its historical transactions still show in summaries (greyed out).
  final bool isActive;
  // Archive flag. Archiving is the terminal step of deletion: the category is
  // out of the way (hidden from every list) but the row is NEVER destroyed, so
  // it can always be brought back. Always implies isActive == false.
  final bool isArchived;

  AllocationCategory({
    String? id,
    required this.name,
    required this.percentage,
    required this.colorHex,
    this.iconName = 'account_balance_wallet',
    this.description = '',
    this.isActive = true,
    this.isArchived = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'percentage': percentage,
        'colorHex': colorHex,
        'iconName': iconName,
        'description': description,
        'isActive': isActive,
        'isArchived': isArchived,
      };

  factory AllocationCategory.fromJson(Map<String, dynamic> json) =>
      AllocationCategory(
        id: json['id'] as String?,
        name: json['name'] as String,
        percentage: (json['percentage'] as num).toDouble(),
        colorHex: json['colorHex'] as String,
        iconName: json['iconName'] as String? ?? 'account_balance_wallet',
        description: json['description'] as String? ?? '',
        isActive: json['isActive'] as bool? ?? true,
        isArchived: json['isArchived'] as bool? ?? false,
      );

  AllocationCategory copyWith({
    String? id,
    String? name,
    double? percentage,
    String? colorHex,
    String? iconName,
    String? description,
    bool? isActive,
    bool? isArchived,
  }) =>
      AllocationCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        percentage: percentage ?? this.percentage,
        colorHex: colorHex ?? this.colorHex,
        iconName: iconName ?? this.iconName,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        isArchived: isArchived ?? this.isArchived,
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
  // How the money moved ("QRIS", "Tunai", ...). Free-form so unknown values
  // from an imported CSV survive a round-trip untouched.
  final String paymentMethod;
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
    this.paymentMethod = defaultPaymentMethod,
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
        'paymentMethod': paymentMethod,
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
        paymentMethod:
            json['paymentMethod'] as String? ?? defaultPaymentMethod,
        allocationSnapshot: (json['allocationSnapshot'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
}
