import '../models/transaction.dart';

class IncomeParserResult {
  final double totalAmount;
  final List<CategorySplitResult> splits;

  IncomeParserResult({required this.totalAmount, required this.splits});
}

class IncomeParser {
  static IncomeParserResult? parse(String raw, List<AllocationCategory> categories) {
    final cleaned = raw.replaceAll(RegExp(r'[Rp\r\n\t]'), ' ').trim();
    final amount = _extractAmount(cleaned);
    if (amount == null || amount <= 0) return null;

    final splits = categories.map((cat) {
      final allocated = (amount * cat.percentage / 100).roundToDouble();
      return CategorySplitResult(category: cat, allocatedAmount: allocated);
    }).toList();

    return IncomeParserResult(totalAmount: amount, splits: splits);
  }

  static double? _extractAmount(String text) {
    // Try patterns like "50000", "50k", "50.000", "Rp50.000"
    final patterns = [
      RegExp(r'(\d+(?:[.,]\d+)?)\s*[kK]'),       // 50k, 50K
      RegExp(r'Rp\.?\s*(\d+(?:[.,]\d+)?)'),       // Rp50.000, Rp 50000
      RegExp(r'(\d{1,3}(?:\.\d{3})+(?:,\d+)?)'),  // 50.000, 1.500.000
      RegExp(r'(\d+(?:,\d+)?)'),                   // 50000, 50000,50
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var numStr = match.group(1)!;
        if (text.toLowerCase().contains('k')) {
          numStr = numStr.replaceAll(',', '.');
          final num = double.tryParse(numStr);
          if (num != null) return num * 1000;
        } else {
          // Handle Indonesian number format: 1.500.000,50
          numStr = numStr.replaceAll('.', '').replaceAll(',', '.');
          return double.tryParse(numStr);
        }
      }
    }

    // Fallback: try direct parse
    final direct = double.tryParse(text.replaceAll(RegExp(r'[^0-9.,]'), ''));
    return direct;
  }
}
