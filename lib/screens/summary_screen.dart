import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/period_summary.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

/// Which span of history the Ringkasan screen is showing.
enum SummaryPeriod {
  /// One calendar month, chosen with the chevrons.
  month,

  /// Every month that has at least one record — no month or year ceiling.
  all,
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _selectedMonth = DateTime.now();
  SummaryPeriod _period = SummaryPeriod.month;

  /// The month to aggregate, or null when accumulating everything on record.
  DateTime? get _windowMonth =>
      _period == SummaryPeriod.month ? _selectedMonth : null;

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
            final summary = calculatePeriodSummary(
              repo.history,
              repo.categories,
              month: _windowMonth,
            );
            final monthName = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
            final isAllTime = _period == SummaryPeriod.all;

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
                              onTap: isAllTime ? null : _previousMonth,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: isAllTime ? 0.1 : 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_left,
                                  color: isAllTime ? Colors.white38 : Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isAllTime ? 'SEMUA PERIODE' : monthName.toUpperCase(),
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: isAllTime ? null : _nextMonth,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: isAllTime ? 0.1 : 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right,
                                  color: isAllTime ? Colors.white38 : Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Period toggle: one month, or every month on record.
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            children: [
                              _buildPeriodTab('PER BULAN', SummaryPeriod.month),
                              _buildPeriodTab('SEMUA', SummaryPeriod.all),
                            ],
                          ),
                        ),

                        // Explain what "SEMUA" actually covers instead of
                        // leaving the user guessing.
                        if (isAllTime) ...[
                          const SizedBox(height: 12),
                          Text(
                            summary.hasRecords
                                ? '${summary.monthCount} bulan · ${summary.recordCount} transaksi'
                                : 'Belum ada pencatatan',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PER KATEGORI',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAllTime
                                ? 'Akumulasi semua periode'
                                : 'Periode ${monthName.toLowerCase()}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
                                                dimmed
                                                    ? '${balance.name} (${balance.isArchived ? 'arsip' : 'nonaktif'})'
                                                    : balance.name,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: dimmed ? Colors.grey.shade600 : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                balance.isEmpty
                                                    ? 'Belum ada pencatatan'
                                                    : 'Rp ${_fmt(balance.income)} − Rp ${_fmt(balance.expense)}',
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

  /// One half of the PER BULAN / SEMUA toggle in the green header.
Widget _buildPeriodTab(String label, SummaryPeriod value) {
  final selected = _period == value;
  return Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _period = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: selected ? AppColors.green : Colors.white,
          ),
        ),
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
