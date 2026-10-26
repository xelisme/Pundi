import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ledger_filter.dart';
import '../models/period_summary.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

/// Month stepping and the range sheet own period selection.

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _selectedMonth = DateTime.now();

  /// Semua mode: every month with records, bounded by the first and last
  /// recording rather than a hardcoded century. Set only from the "Semua"
  /// preset; the chevrons and month stepping own everything else.
  bool _allTime = false;

  /// A range that is neither a stepped month nor Semua — one of the presets,
  /// or two dates the user picked. Null whenever the chevrons or Semua mode
  /// are in charge, which is what keeps month stepping meaningful instead of
  /// fighting a stale range.
  LedgerFilter? _range;

  LedgerFilter _filterFor(BudgetRepository repo) {
    return _range ??
        (_allTime
            ? _allTimeBounds(repo.activeHistory)
            : LedgerFilter(
                from: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
                to: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
              ));
  }

  /// The Semua span: the first recording's day through the last recording's
  /// day, so the view always matches what is actually on file. Archived rows
  /// stay out, like every other total. Empty history means an unbounded
  /// filter, which matches nothing because there is nothing to match.
  LedgerFilter _allTimeBounds(List<TransactionRecord> records) {
    DateTime? first;
    DateTime? last;
    for (final record in records) {
      final date = DateTime.fromMillisecondsSinceEpoch(effectiveDate(record));
      if (first == null || date.isBefore(first)) first = date;
      if (last == null || date.isAfter(last)) last = date;
    }
    if (first == null || last == null) {
      return LedgerFilter(from: null, to: null);
    }
    return LedgerFilter(
      from: DateTime(first.year, first.month, first.day),
      to: DateTime(last.year, last.month, last.day, 23, 59, 59, 999),
    );
  }

  bool get _isRangeMode => _range != null;

  /// True when the chevrons can actually step anywhere. A hand-picked range has
  /// no month to step from, so they dim instead of silently moving the label to
  /// a month the numbers do not describe.
  bool get _canStepMonths => !_isRangeMode && !_allTime;

  String _fmt(int amount) => NumberFormat('#,##0', 'id_ID').format(amount);

  Color _hexToColor(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  void _previousMonth() {
    if (!_canStepMonths) return;
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    if (!_canStepMonths) return;
    final now = DateTime.now();
    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );
    if (!nextMonth.isBefore(DateTime(now.year, now.month + 1, 1))) return;
    setState(() => _selectedMonth = nextMonth);
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
      // "Semua" is a mode, not the 2000-2100 marker: the bounds resolve to
      // the first and last recording in _filterFor, so the header, the scope
      // note and Riwayat all describe what is actually on file.
      if (next == LedgerRanges.allTime()) {
        _allTime = true;
        _range = null;
        return;
      }
      // A range covering exactly one calendar month goes back to month mode, so
      // picking "Bulan ini" leaves the chevrons live instead of freezing a copy
      // of this month with the arrows inert.
      if (_isWholeMonth(next)) {
        _allTime = false;
        _range = null;
        _selectedMonth = DateTime(next.from!.year, next.from!.month, 1);
        return;
      }
      _allTime = false;
      _range = next;
    });
  }

  Future<void> _openRangeSheet() async {
    final picked = await showModalBottomSheet<LedgerFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RangeSheet(
        current: _filterFor(context.read<BudgetRepository>()),
        isAllTime: _allTime,
        onApply: (from, to) => LedgerFilter(from: from, to: to),
      ),
    );
    if (picked == null || !mounted) return;
    _applyPreset(picked);
  }

  String _periodLabel() {
    if (_isRangeMode) return _formatRange(_range!);
    if (_allTime) return 'SEMUA PERIODE';
    return DateFormat(
      'MMMM yyyy',
      'id_ID',
    ).format(_selectedMonth).toUpperCase();
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
    if (_allTime) {
      return '${summary.monthCount} bulan · $count';
    }
    return '$count · ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}';
  }

  /// Describes the period the per-category section holds.
  String _tableCaption() {
    if (_isRangeMode) return _formatRange(_range!).toLowerCase();
    if (_allTime) return 'Akumulasi semua periode';
    return 'Periode ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<BudgetRepository>(
          builder: (context, repo, _) {
            // Filter first, then aggregate. Reusing calculatePeriodSummary on the
            // narrowed records keeps one aggregation implementation, so a
            // filtered total cannot quietly disagree with an unfiltered one.
            final visible = applyLedgerFilter(
              repo.activeHistory,
              _filterFor(repo),
            );
            final summary = calculatePeriodSummary(visible, repo.categories);
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
                          style: GoogleFonts.plusJakartaSans(
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
                            Flexible(child: _buildPeriodLabel(label)),
                            const SizedBox(width: 12),
                            _stepButton(Icons.chevron_right, _nextMonth),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Say what is actually counted. Previously this only
                        // appeared for all-time, which left a hand-picked range
                        // or a category filter looking like the whole ledger.
                        // Nothing is claimed when the range is empty.
                        if (_scopeNote(summary).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            _scopeNote(summary),
                            style: GoogleFonts.plusJakartaSans(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
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
                            color: summary.netIncome >= 0
                                ? AppColors.income
                                : AppColors.expense,
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
                // Category balances - Data table style.
                if (summary.categoryBalances.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PER KATEGORI',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.textTertiary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The period these rows describe. Stating it here
                            // keeps the table honest about what it is holding.
                            _tableCaption(),
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Table header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                16,
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 3),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Kategori',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textTertiary,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Divider(color: AppColors.divider, height: 1),

                            // Category rows. Read-only: the table answers
                            // "berapa di tiap kantong", not "pergi ke sana".
                            ...summary.categoryBalances.map((balance) {
                              final color = _hexToColor(balance.colorHex);
                              final dimmed = !balance.isActive;
                              return Column(
                                children: [
                                  Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: dimmed
                                                ? AppColors.dimmedIndicator
                                                : color,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
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
                                                          ? AppColors
                                                                .dimmedTitle
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
                                                          ? AppColors
                                                                .dimmedSecondary
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
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: dimmed
                                                  ? AppColors.dimmedSecondary
                                                  : (balance.balance >= 0
                                                        ? AppColors.income
                                                        : AppColors.expense),
                                              letterSpacing: -0.01,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (balance != summary.categoryBalances.last)
                                    Divider(
                                      color: AppColors.divider,
                                      height: 1,
                                    ),
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

  Widget _buildPeriodLabel(String label) {
    // The underline says "this opens something"; the press has to say "now".
    // Under GestureDetector the label gave nothing back until the sheet was
    // already sliding up, which reads as a missed tap rather than a slow one.
    return Material(
      // The label reads differently every month, so this is the only stable way
      // to aim at it. Tests use it; nothing in the app looks it up.
      key: const ValueKey('periodLabel'),
      color: Colors.transparent,
      child: InkWell(
        onTap: _openRangeSheet,
        borderRadius: BorderRadius.circular(8),
        highlightColor: Colors.white.withValues(alpha: 0.25),
        splashColor: Colors.white.withValues(alpha: 0.16),
        child: Container(
          // Six pixels either side so the pressed area is a target rather than
          // a sliver of text. Widening the label widens the pill by the same
          // twelve, which reads as the pill having room for its label instead of
          // the label wedged between two arrows.
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          // The only cue that this opens something. A calendar icon sat here
          // before and was removed for good reason: one pill already carries a
          // glyph on each side, and a third for the label's job made the pill
          // read as three buttons rather than one label between two arrows.
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    final enabled = _canStepMonths;
    // Feedback has to land on pointer-down. GestureDetector reports nothing
    // until the tap resolves, so the arrow looked dead for the whole press and
    // only came alive once the month had already moved under it.
    //
    // The highlight paints on the Material behind the circle rather than over
    // it, so it stacks with the circle's own translucent white instead of
    // replacing it: pressed reads as noticeably brighter than released, and
    // released is unchanged from before.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        highlightColor: Colors.white.withValues(alpha: 0.30),
        splashColor: Colors.white.withValues(alpha: 0.18),
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
          style: GoogleFonts.plusJakartaSans(
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
          style: GoogleFonts.plusJakartaSans(
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
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

/// Where the period is chosen.
///
/// The presets live in here rather than on the screen itself: "last 30 days" and
/// "this month" are the ranges people actually ask for, and a sheet holding only
/// two date fields would be more work for the same result. What the sheet dropped
/// from the screen is the row of chips competing with the category row for
/// attention.
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.current,
    required this.isAllTime,
    required this.onApply,
  });

  /// What Ringkasan is showing now, so the fields open on the selection being
  /// changed rather than on an unrelated month.
  final LedgerFilter current;

  /// Whether the Semua preset is the active choice. It arrives as data bounds
  /// rather than the century marker, so equality alone cannot light its chip.
  final bool isAllTime;

  final LedgerFilter Function(DateTime from, DateTime to) onApply;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late DateTime? _from = widget.current.from;
  late DateTime? _to = widget.current.to;

  Future<void> _pick({required bool isFrom}) async {
    final now = DateTime.now();
    final anchor = isFrom ? (_from ?? _to ?? now) : (_to ?? _from ?? now);
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

  /// The last preset is Semua, which arrives as data bounds rather than the
  /// century marker the preset list holds.
  bool _isSemuaPreset(int index) =>
      LedgerRanges.preset(index) == LedgerRanges.allTime();

  /// True when [preset] is the range currently in view, so the sheet opens with
  /// the active choice lit rather than looking unset.
  bool _isPreset(LedgerFilter preset) {
    final current = widget.current;
    if (!current.hasPeriod) return preset == LedgerRanges.allTime();
    return current.from == preset.from && current.to == preset.to;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _from != null && _to != null;
    return SingleChildScrollView(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih yang cepat, atau tentukan tanggal sendiri.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          // The ranges people ask for first, so picking a period is one tap in
          // the common case instead of two date picks.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < LedgerRanges.presetLabels.length; i++)
                _FilterChip(
                  label: LedgerRanges.presetLabels[i],
                  selected: _isSemuaPreset(i)
                      ? widget.isAllTime
                      : _isPreset(LedgerRanges.preset(i)),
                  onTap: () =>
                      Navigator.of(context).pop(LedgerRanges.preset(i)),
                ),
            ],
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
                  ? () =>
                        Navigator.of(context).pop(widget.onApply(_from!, _to!))
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
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value == null
                  ? 'Pilih tanggal'
                  : DateFormat('d MMM yyyy', 'id_ID').format(value!),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
