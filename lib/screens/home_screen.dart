import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';

import '../utils/app_colors.dart';
import '../widgets/radial_allocation_viz.dart';
import '../widgets/duolingo_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputController = TextEditingController();
  final _merchantController = TextEditingController();
  final _itemsController = TextEditingController();
  bool _isExpense = false;
  String? _selectedChargedTo; // untuk expense
  String? _selectedIncomeTarget; // untuk income
  DateTime _receiptDate = DateTime.now();

  @override
  void dispose() {
    _inputController.dispose();
    _merchantController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _submitIncome(BuildContext context) {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;

    final repo = context.read<BudgetRepository>();
    final categories = repo.categories;

    final amount = _parseAmount(raw);
    if (amount == null || amount <= 0) {
      _showSnackBar(context, 'Format tidak dikenali. Gunakan: 50000 atau 50k', isError: true);
      return;
    }

    // Determine target: allCategoriesLabel (default) or specific category
    final target = _selectedIncomeTarget ?? allCategoriesLabel;
    
    List<CategorySplitResult> splits;
    if (target == allCategoriesLabel) {
      // Split ke semua pos by percentage
      splits = categories.map((cat) {
        final allocated = (amount * cat.percentage / 100).roundToDouble();
        return CategorySplitResult(category: cat, allocatedAmount: allocated);
      }).toList();
    } else {
      // Alokasi ke pos tertentu
      final category = categories.where((c) => c.name == target).firstOrNull;
      splits = category != null
          ? [CategorySplitResult(category: category, allocatedAmount: amount)]
          : [];
    }

    final record = TransactionRecord(
      rawInput: raw,
      totalAmount: amount,
      splits: splits,
      type: TransactionType.income,
      chargedTo: target,
    );

    repo.recordTransaction(record);
    _inputController.clear();
    setState(() => _selectedIncomeTarget = null);

    _showSnackBar(context, 'Pemasukan Rp ${_fmt(amount)} dicatat');
  }

  void _submitExpense(BuildContext context) {
    final merchant = _merchantController.text.trim();
    final items = _itemsController.text.trim();
    final raw = _inputController.text.trim();

    if (raw.isEmpty) {
      _showSnackBar(context, 'Nominal harus diisi', isError: true);
      return;
    }

    final amount = _parseAmount(raw);
    if (amount == null || amount <= 0) {
      _showSnackBar(context, 'Format nominal salah', isError: true);
      return;
    }

    final repo = context.read<BudgetRepository>();
    final chargedTo = _selectedChargedTo ?? allCategoriesLabel; // default: Seluruhnya

    repo.recordExpense(
      merchantName: merchant,
      items: items,
      amount: amount,
      chargedToCategory: chargedTo,
      receiptDate: _receiptDate.millisecondsSinceEpoch,
    );

    _inputController.clear();
    _merchantController.clear();
    _itemsController.clear();
    setState(() {
      _selectedChargedTo = null;
      _receiptDate = DateTime.now();
    });

    _showSnackBar(context, 'Pengeluaran Rp ${_fmt(amount)} dicatat');
  }

  double? _parseAmount(String text) {
    final cleaned = text.replaceAll(RegExp(r'[Rp\s.]'), '').replaceAll(',', '.');
    if (cleaned.toLowerCase().endsWith('k')) {
      final num = double.tryParse(cleaned.substring(0, cleaned.length - 1));
      return num != null ? num * 1000 : null;
    }
    if (cleaned.toLowerCase().endsWith('jt')) {
      final num = double.tryParse(cleaned.substring(0, cleaned.length - 2));
      return num != null ? num * 1000000 : null;
    }
    return double.tryParse(cleaned);
  }

  String _fmt(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  Widget _buildMiniMetric(
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
          'Rp ${_fmt(amount.toDouble())}',
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

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accent,
              onPrimary: AppColors.surfaceWhite,
              surface: AppColors.surfaceWhite,
              onSurface: AppColors.baseBrown,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _receiptDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Duolingo green hero header
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.green,
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BudgetAI',
                            style: GoogleFonts.nunito(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alokasi Anggaran',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_outlined, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            ),

            // Grand total summary card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Consumer<BudgetRepository>(
                  builder: (context, repo, _) {
                    int totalIncome = 0;
                    int totalExpenses = 0;

                    for (final record in repo.history) {
                      if (record.type == TransactionType.income) {
                        totalIncome += record.totalAmount.toInt();
                      } else {
                        totalExpenses += record.totalAmount.toInt();
                      }
                    }

                    final net = totalIncome - totalExpenses;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL KESELURUHAN',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMiniMetric(
                                  context,
                                  label: 'Pemasukan',
                                  amount: totalIncome,
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
                                child: _buildMiniMetric(
                                  context,
                                  label: 'Pengeluaran',
                                  amount: totalExpenses,
                                  color: AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'Sisa Bersih',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              Text(
                                'Rp ${_fmt(net.toDouble())}',
                                style: GoogleFonts.nunito(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.03,
                                  color: net >= 0 ? AppColors.income : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Mode toggle - refined
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildModeToggle(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Main content
            if (!_isExpense) ...[
              _buildIncomeSection(),
            ] else ...[
              _buildExpenseSection(),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isExpense = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isExpense ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: !_isExpense ? [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ] : null,
                ),
                child: Text(
                  'Pemasukan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: !_isExpense ? Colors.white : AppColors.grayNav,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isExpense = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isExpense ? AppColors.red : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _isExpense ? [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ] : null,
                ),
                child: Text(
                  'Pengeluaran',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isExpense ? Colors.white : AppColors.grayNav,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Allocation visualization
            Consumer<BudgetRepository>(
              builder: (context, repo, _) {
                if (repo.categories.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Text(
                        'ALOKASI OTOMATIS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: RadialAllocationViz(
                          allocations: {for (var c in repo.categories) c.name: c.percentage},
                          colors: {for (var c in repo.categories) c.name: _hexToColor(c.colorHex)},
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...repo.categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _hexToColor(cat.colorHex),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              '${cat.percentage.toStringAsFixed(0)}%',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.01,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Input card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'NOMINAL PEMASUKAN',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _inputController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.02,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '5000000',
                        hintStyle: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.02,
                          color: AppColors.textTertiary,
                        ),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Format: 5000000, 5jt, atau 5000k',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'POS ALOKASI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dropdown pilihan pos untuk pemasukan
                  Consumer<BudgetRepository>(
                    builder: (context, repo, _) {
                      final options = [allCategoriesLabel, ...repo.categories.map((c) => c.name)];
                      final selected = _selectedIncomeTarget ?? allCategoriesLabel;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selected,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                            items: options.map((opt) {
                              return DropdownMenuItem(
                                value: opt,
                                child: Text(
                                  opt,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedIncomeTarget = val);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih pos alokasi (default: Seluruhnya)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  DuolingoButton(
                    label: 'Catat Pemasukan',
                    onPressed: () => _submitIncome(context),
                    type: DuolingoButtonType.primary,
                    fullWidth: true,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CATAT PENGELUARAN',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Amount input
              Text(
                'NOMINAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _inputController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.02,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '250000',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.02,
                      color: AppColors.textTertiary,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Merchant
              Text(
                'MERCHANT (OPSIONAL)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _merchantController,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Nama toko',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Items
              Text(
                'ITEM (OPSIONAL)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _itemsController,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Deskripsi pembelian',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Category selection
              Consumer<BudgetRepository>(
                builder: (context, repo, _) {
                  if (repo.categories.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DIBEBANKAN KE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CategoryChip(
                            label: 'Seluruhnya',
                            color: AppColors.accent,
                            isSelected: _selectedChargedTo == null || _selectedChargedTo == allCategoriesLabel,
                            onTap: () => setState(() => _selectedChargedTo = allCategoriesLabel),
                          ),
                          ...repo.categories.map((cat) {
                            final isSelected = _selectedChargedTo == cat.name;
                            final color = _hexToColor(cat.colorHex);
                            return _CategoryChip(
                              label: cat.name,
                              color: color,
                              isSelected: isSelected,
                              onTap: () => setState(() => _selectedChargedTo = cat.name),
                            );
                          }),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Date picker
              Text(
                'TANGGAL STRUK',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy', 'id_ID').format(_receiptDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Submit button
              DuolingoButton(
                label: 'Catat Pengeluaran',
                onPressed: () => _submitExpense(context),
                type: DuolingoButtonType.danger,
                fullWidth: true,
                icon: Icons.arrow_downward_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _ModeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected ? color : AppColors.textTertiary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
