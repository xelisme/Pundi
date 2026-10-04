import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ledger_filter.dart';
import '../models/period_summary.dart';
import '../repositories/budget_repository.dart';
import '../state/ledger_filter_controller.dart';
import '../state/main_tab_controller.dart';
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

  /// A range that is neither a stepped month nor all-time — one of the presets,
  /// or two dates the user picked. Null whenever the chevrons or the
  /// PER BULAN/SEMUA toggle are in charge, which is what keeps month stepping
  /// meaningful instead of fighting a stale range.
  LedgerFilter? _range;

  /// Null means every category.
  String? _category;

  @override
  void initState() {
    super.initState();
    // Riwayat reads this filter from the moment it exists, so publish the
    // initial selection instead of leaving it unset until the first tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _publish());
  }

  LedgerFilter get _filter {
    final base = _range ??
        (_period == SummaryPeriod.month
            ? LedgerFilter(
                from: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
                to: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
              )
            : LedgerRanges.allTime());
    return _category == null
        ? base
        : base.copyWith(categoryName: _category);
  }

  /// Hand the current selection to Riwayat. Ringkasan is the only writer, so
  /// this is called from tap handlers rather than from build — writing during
  /// build would notify listeners mid-tree.
  void _publish() {
    if (!mounted) return;
    context.read<LedgerFilterController>().setFilter(_filter);
  }

  bool get _isRangeMode => _range != null;

  /// True when the chevrons can actually step anywhere. A hand-picked range has
  /// no month to step from, so they dim instead of silently moving the label to
  /// a month the numbers do not describe.
  bool get _canStepMonths => !_isRangeMode && _period == SummaryPeriod.month;

  String _fmt(int amount) => NumberFormat('#,##0', 'id_ID').format(amount);

  Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  void _previousMonth() {
    if (!_canStepMonths) return;
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _publish();
  }

  void _nextMonth() {
    if (!_canStepMonths) return;
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (!nextMonth.isBefore(DateTime(now.year, now.month + 1, 1))) return;
    setState(() => _selectedMonth = nextMonth);
    _publish();
  }

  /// True when [filter] covers exactly one calendar month, which means the
  /// chevrons can take over from it. Picking "Bulan ini" should land you in
  /// month mode with the arrows live, not in a frozen copy of this month.
  static bool _isWholeMonth(LedgerFilter filter) {
    final from = filter.from;
    final to = filter.to;
    if (from == null || to == null) return false;
    return from.day == 1 &&
        from.month == to.month &&
        from.year == to.year &&
        to.day == DateTime(to.year, to.month + 1, 0).day;
  }

  void _applyPreset(LedgerFilter next) {
    setState(() {
      if (_isWholeMonth(next)) {
        _range = null;
        _period = SummaryPeriod.month;
        _selectedMonth = DateTime(next.from!.year, next.from!.month, 1);
      } else {
        _period = SummaryPeriod.all;
        _range = next;
      }
    });
    _publish();
  }

  void _applyPeriodTab(SummaryPeriod value) {
    setState(() {
      _period = value;
      _range = null;
    });
    _publish();
  }

  void _applyCategory(String? name) {
    setState(() => _category = name);
    _publish();
  }

  Future<void> _pickCustomRange() async {
    final initial = _range ?? _filter;
    final picked = await showModalBottomSheet<LedgerFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RangeSheet(
        from: initial.from,
        to: initial.to,
        onApply: (from, to) => LedgerFilter(from: from, to: to),
      ),
    );
    if (picked == null || !mounted) return;
    _applyPreset(picked);
  }

  /// Send the user to Riwayat with the same selection applied there, so the list
  /// adds up to the total above it.
  void _openHistory() {
    _publish();
    context.read<MainTabController>().select(MainTabController.riwayat);
  }

  String _periodLabel() {
    if (_isRangeMode) return _formatRange(_range!);
    if (_period == SummaryPeriod.all) return 'SEMUA PERIODE';
    return DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth).toUpperCase();
  }

  /// "1 - 30 SEP 2026" for one month, "5 AGU - 2 SEP 2026" across months.
  String _formatRange(LedgerFilter filter) {
    final from = filter.from;
    final to = filter.to;
    if (from == null && to == null) return 'SEMUA PERIODE';
    if (from == null) return 'Sampai ${_day(to)}';
    if (to == null) return 'Sejak ${_day(from)}';
    if (from.year == to.year && from.month == to.month) {
      return '${from.day} - ${_day(to)}';
    }
    return '${_short(from)} - ${_day(to)}';
  }

  String _day(DateTime? d) => d == null
      ? ''
      : DateFormat('d MMM yyyy', 'id_ID').format(d).toUpperCase();

  String _short(DateTime d) =>
      DateFormat('d MMM', 'id_ID').format(d).toUpperCase();

  /// One line saying exactly what the numbers cover. Ringkasan is where people
  /// decide whether to trust a number, so the range and the category have to be
  /// stated rather than implied by which chip happens to look pressed.
  ///
  /// Returns empty when there is nothing in range. Claiming "0 bulan · 0
  /// transaksi" would be a fabricated span, and an empty selection is already
  /// visible from the empty figures below.
  String _scopeNote(PeriodSummary summary) {
    if (!summary.hasRecords) return '';
    final count = '${summary.recordCount} transaksi';
    if (_isRangeMode) {
      return '$count · ${_formatRange(_range!).toLowerCase()}';
    }
    if (_period == SummaryPeriod.all) {
      return '${summary.monthCount} bulan · $count';
    }
    return '$count · ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}';
  }

  /// Describes the period for the per-category section, including which category
  /// the rows are currently narrowed to.
  String _tableCaption() {
    if (_category != null) return 'Kategori $_category';
    if (_isRangeMode) return _formatRange(_range!).toLowerCase();
    if (_period == SummaryPeriod.all) return 'Akumulasi semua periode';
    return 'Periode ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<BudgetRepository>(
          builder: (context, repo, _) {
            // Filter first, then aggregate. Reusing calculatePeriodSummary on the
            // narrowed records keeps one aggregation implementation, so a
            // filtered total cannot quietly disagree with an unfiltered one.
            final visible = applyLedgerFilter(repo.activeHistory, _filter);
            final summary =
                calculatePeriodSummary(visible, repo.categories);
            final label = _periodLabel();

            return CustomScrollView(
              slivers: [
                // Duolingo green hero header with period selector
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
                        // Period pill. Rendered in every mode so the affordance
                        // never moves; it just stops responding when there is no
                        // month to step to.
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _stepButton(Icons.chevron_left, _previousMonth),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _canStepMonths
                                      ? Colors.white
                                      : Colors.white70,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _stepButton(Icons.chevron_right, _nextMonth),
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

                        // Say what is actually counted. Previously this only
                        // appeared for all-time, which left a hand-picked range
                        // or a category filter looking like the whole ledger.
                        // Nothing is claimed when the range is empty.
                        if (_scopeNote(summary).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _scopeNote(summary),
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

                // Filters: which stretch of dates, and which category.
                SliverToBoxAdapter(child: _buildFilterSection(context, repo)),

                // Send the user to the rows behind the number above.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: _HistoryLink(
                      count: summary.recordCount,
                      note: _category == null
                          ? null
                          : 'Nominal mengikuti bagian $_category saja.',
                      onTap: _openHistory,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

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
                            // The period or category these rows describe,
                            // plus how to narrow further. Stating it here keeps
                            // the table honest about what it is holding.
                            '${_tableCaption()} · tap untuk menyaring',
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
                        clipBehavior: Clip.antiAlias,
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

                            // Category rows. Each is a tap target that narrows
                            // the whole screen to that category, which is the
                            // "kantong tertentu" answer without a second screen.
                            ...summary.categoryBalances.map((balance) {
                              final color = _hexToColor(balance.colorHex);
                              final dimmed = !balance.isActive;
                              final selected = _category == balance.name;
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => _applyCategory(
                                        selected ? null : balance.name),
                                    child: Container(
                                      color: selected
                                          ? color.withValues(alpha: 0.10)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: dimmed
                                                  ? Colors.grey.shade400
                                                  : color,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dimmed
                                                      ? '${balance.name} (${balance.isArchived ? 'arsip' : 'nonaktif'})'
                                                      : balance.name,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: dimmed
                                                            ? Colors.grey.shade600
                                                            : null,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  balance.isEmpty
                                                      ? 'Belum ada pencatatan'
                                                      : 'Rp ${_fmt(balance.income)} − Rp ${_fmt(balance.expense)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: dimmed
                                                            ? Colors.grey.shade500
                                                            : null,
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
                                                    : (balance.balance >= 0
                                                        ? AppColors.income
                                                        : AppColors.expense),
                                                letterSpacing: -0.01,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            selected
                                                ? Icons.check_circle
                                                : Icons.chevron_right,
                                            size: 18,
                                            color: selected
                                                ? color
                                                : AppColors.textTertiary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (balance !=
                                      summary.categoryBalances.last)
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

  /// Period and category pickers, plus what the current selection means.
  Widget _buildFilterSection(BuildContext context, BudgetRepository repo) {
    // Archived categories are excluded because archiving one reassigns every
    // transaction away from it, so it could only ever show zero. Nonaktif ones
    // are kept: they still hold real money from before they were switched off.
    final categories =
        repo.categories.where((c) => !c.isArchived).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERIODE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < LedgerRanges.presetLabels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: LedgerRanges.presetLabels[i],
                      selected: _matchesPreset(LedgerRanges.preset(i)),
                      onTap: () => _applyPreset(LedgerRanges.preset(i)),
                    ),
                  ),
                _FilterChip(
                  label: 'Kustom',
                  icon: Icons.edit_calendar_outlined,
                  selected: false,
                  onTap: _pickCustomRange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'KATEGORI',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Semua',
                  selected: _category == null,
                  onTap: () => _applyCategory(null),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: category.name,
                      dot: _hexToColor(category.colorHex),
                      selected: _category == category.name,
                      onTap: () => _applyCategory(
                          _category == category.name ? null : category.name),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// True when [preset] is what the screen is already showing. Compared against
  /// the same range the header would print, so a stepped month lights up the
  /// matching chip instead of leaving the row looking unselected.
  bool _matchesPreset(LedgerFilter preset) {
    if (_isRangeMode) return _range == preset;
    if (preset.from == null || preset.to == null) {
      return !_isRangeMode && _period == SummaryPeriod.all;
    }
    if (!_canStepMonths) return false;
    final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    return preset.from!.year == monthStart.year &&
        preset.from!.month == monthStart.month &&
        preset.to!.year == monthStart.year &&
        preset.to!.month == monthStart.month;
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    final enabled = _canStepMonths;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: enabled ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white38,
          size: 20,
        ),
      ),
    );
  }

  /// One half of the PER BULAN / SEMUA toggle in the green header.
  Widget _buildPeriodTab(String label, SummaryPeriod value) {
    final selected = _period == value && !_isRangeMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applyPeriodTab(value),
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

/// A pill in the filter rows. Unselected chips stay legible on white rather than
/// borrowing the header's translucent-white treatment, which disappears there.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.green : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The affordance that connects a total to the rows behind it. When a category
/// filter is on it also says so, because a shared "Seluruhnya" row shows only
/// that category's share and would otherwise look like a wrong amount.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink({
    required this.count,
    required this.onTap,
    this.note,
  });

  final int count;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    // No rows means no link, and no sentence about transactions either. The
    // header already shows nothing in that case, so an extra "there are no
    // transactions here" line would just repeat it.
    if (count == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lihat $count transaksi',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(note!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Two dates and nothing else. The presets cover the ranges people ask for, so
/// this only has to handle the case where they want something else.
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.from,
    required this.to,
    required this.onApply,
  });

  final DateTime? from;
  final DateTime? to;
  final LedgerFilter Function(DateTime from, DateTime to) onApply;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late DateTime? _from = widget.from;
  late DateTime? _to = widget.to;

  Future<void> _pick({required bool isFrom}) async {
    final now = DateTime.now();
    final anchor = isFrom
        ? (_from ?? _to ?? now)
        : (_to ?? _from ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: anchor,
      // No future dates: the ledger records what already happened, and offering
      // tomorrow would only produce empty ranges.
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      locale: const Locale('id', 'ID'),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        // Keep the span valid by dragging the other end along, instead of
        // leaving a from-after-to range that silently matches nothing.
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && picked.isBefore(_from!)) _from = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _from != null && _to != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rentang periode',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih tanggal awal dan akhir.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Dari',
                  value: _from,
                  onTap: () => _pick(isFrom: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Sampai',
                  value: _to,
                  onTap: () => _pick(isFrom: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: ready
                  ? () => Navigator.of(context)
                      .pop(widget.onApply(_from!, _to!))
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Terapkan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                    fontSize: 10,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value == null
                  ? 'Pilih tanggal'
                  : DateFormat('d MMM yyyy', 'id_ID').format(value!),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}