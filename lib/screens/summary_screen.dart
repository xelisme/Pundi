import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';

class _CategoryBalance {
  final String name;
  final String colorHex;
  final int income;
  final int expense;
  final bool isActive;
  int get balance => income - expense;

  _CategoryBalance({
    required this.name,
    required this.colorHex,
    required this.income,
    required this.expense,
    this.isActive = true,
  });
}

class _MonthlySummary {
  final int totalIncome;
  final int totalExpenses;
  final int netIncome;
  final Map<String, int> incomeBreakdown;
  final Map<String, int> expenseBreakdown;
  final List<_CategoryBalance> categoryBalances;

  _MonthlySummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netIncome,
    required this.incomeBreakdown,
    required this.expenseBreakdown,
    required this.categoryBalances,
  });
}

_MonthlySummary _calculateMonthlySummary(
    List<TransactionRecord> records, List<AllocationCategory> categories, DateTime selectedMonth) {
  int totalIncome = 0;
  int totalExpenses = 0;
  final Map<String, int> incomeBreakdown = {};
  final Map<String, int> expenseBreakdown = {};
  final Map<String, int> categoryIncome = {};
  final Map<String, int> categoryExpense = {};
  final Map<String, String> categoryColors = {};

  for (final cat in categories) {
    categoryIncome[cat.name] = 0;
    categoryExpense[cat.name] = 0;
    categoryColors[cat.name] = cat.colorHex;
  }

  final thisMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

  for (final record in records) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.isBefore(thisMonth) || date.compareTo(nextMonth) >= 0) continue;

    if (record.type == TransactionType.income) {
      totalIncome += record.totalAmount.toInt();
      for (final split in record.splits) {
        final key = split.category.name;
        incomeBreakdown[key] = (incomeBreakdown[key] ?? 0) + split.allocatedAmount.toInt();
        categoryIncome[key] = (categoryIncome[key] ?? 0) + split.allocatedAmount.toInt();
      }
    } else {
      totalExpenses += record.totalAmount.toInt();
      if (record.splits.isNotEmpty) {
        for (final split in record.splits) {
          final key = split.category.name;
          expenseBreakdown[key] = (expenseBreakdown[key] ?? 0) + split.allocatedAmount.toInt();
          categoryExpense[key] = (categoryExpense[key] ?? 0) + split.allocatedAmount.toInt();
        }
      } else {
        final key = record.chargedTo ?? 'Lainnya';
        expenseBreakdown[key] = (expenseBreakdown[key] ?? 0) + record.totalAmount.toInt();
        if (categoryExpense.containsKey(key)) {
          categoryExpense[key] = (categoryExpense[key] ?? 0) + record.totalAmount.toInt();
        }
      }
    }
  }

  final balances = <_CategoryBalance>[];
  for (final cat in categories) {
    balances.add(_CategoryBalance(
      name: cat.name,
      colorHex: cat.colorHex,
      income: categoryIncome[cat.name] ?? 0,
      expense: categoryExpense[cat.name] ?? 0,
      isActive: cat.isActive,
    ));
  }

  return _MonthlySummary(
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    netIncome: totalIncome - totalExpenses,
    incomeBreakdown: incomeBreakdown,
    expenseBreakdown: expenseBreakdown,
    categoryBalances: balances,
  );
}

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _selectedMonth = DateTime.now();

  String _fmt(int amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (nextMonth.isBefore(DateTime(now.year, now.month + 1, 1))) {
      setState(() {
        _selectedMonth = nextMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<BudgetRepository>(
          builder: (context, repo, _) {
            final summary = _calculateMonthlySummary(repo.history, repo.categories, _selectedMonth);
            final monthName = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

            return CustomScrollView(
              slivers: [
                // Duolingo green hero header with month selector
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.green,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan',
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Month selector pill
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _previousMonth,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              monthName.toUpperCase(),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _nextMonth,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Hero numbers - Editorial pull quote style
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          // Net income - the lead
                          _buildHeroMetric(
                            context,
                            label: 'Sisa Bersih',
                            amount: summary.netIncome,
                            color: summary.netIncome >= 0 ? AppColors.income : AppColors.expense,
                            isLarge: true,
                          ),
                          
                          const SizedBox(height: 24),
                          Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: 24),

                          // Supporting metrics
                          Row(
                            children: [
                              Expanded(
                                child: _buildSupportingMetric(
                                  context,
                                  label: 'Pemasukan',
                                  amount: summary.totalIncome,
                                  color: AppColors.income,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppColors.divider,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSupportingMetric(
                                  context,
                                  label: 'Pengeluaran',
                                  amount: summary.totalExpenses,
                                  color: AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Category balances - Data table style
                if (summary.categoryBalances.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        'PER KATEGORI',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            // Table header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: Row(
                                children: [
                                  const SizedBox(width: 3),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Kategori',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      'Sisa',
                                      textAlign: TextAlign.right,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            Divider(color: AppColors.divider, height: 1),

                            // Category rows
                            ...summary.categoryBalances.map((balance) {
                              final color = _hexToColor(balance.colorHex);
                              final dimmed = !balance.isActive;
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: dimmed ? Colors.grey.shade400 : color,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dimmed ? '${balance.name} (dihapus)' : balance.name,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: dimmed ? Colors.grey.shade600 : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rp ${_fmt(balance.income)} − Rp ${_fmt(balance.expense)}',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: dimmed ? Colors.grey.shade500 : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 90,
                                          child: Text(
                                            'Rp ${_fmt(balance.balance)}',
                                            textAlign: TextAlign.right,
                                            style: GoogleFonts.nunito(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: dimmed
                                                  ? Colors.grey.shade500
                                                  : (balance.balance >= 0 ? AppColors.income : AppColors.expense),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (balance != summary.categoryBalances.last)
                                    Divider(color: AppColors.divider, height: 1),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroMetric(
    BuildContext context, {
    required String label,
    required int amount,
    required Color color,
    bool isLarge = false,
  }) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Rp ${_fmt(amount)}',
          style: GoogleFonts.nunito(
            fontSize: isLarge ? 36 : 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.03,
            height: 1.1,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSupportingMetric(
    BuildContext context, {
    required String label,
    required int amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Rp ${_fmt(amount)}',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.02,
            color: color,
          ),
        ),
      ],
    );
  }
}
