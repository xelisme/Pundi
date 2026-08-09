import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';

import '../utils/app_colors.dart';
import '../widgets/radial_allocation_viz.dart';

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
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rp ${_fmt(amount.toDouble())}',
          style: GoogleFonts.lora(
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
        backgroundColor: isError ? AppColors.expense : AppColors.baseBrown,
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
      backgroundColor: AppColors.baseBeige,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Refined header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HyperBudget',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alokasi Anggaran',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grand total summary card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Keseluruhan',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
                          Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sisa Bersih',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                'Rp ${_fmt(net.toDouble())}',
                                style: GoogleFonts.lora(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
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
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Pemasukan',
              isSelected: !_isExpense,
              onTap: () => setState(() => _isExpense = false),
              color: AppColors.income,
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Pengeluaran',
              isSelected: _isExpense,
              onTap: () => setState(() => _isExpense = true),
              color: AppColors.expense,
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
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor,
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Text(
                        'Alokasi Otomatis',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
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
                              style: GoogleFonts.lora(
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Masukkan Nominal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _inputController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.02,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '5000000',
                      hintStyle: GoogleFonts.lora(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.02,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
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
                  
                  // Dropdown pilihan pos untuk pemasukan
                  Consumer<BudgetRepository>(
                    builder: (context, repo, _) {
                      final options = [allCategoriesLabel, ...repo.categories.map((c) => c.name)];
                      final selected = _selectedIncomeTarget ?? allCategoriesLabel;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.baseBeige,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButton<String>(
                          value: selected,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: options.map((opt) {
                            return DropdownMenuItem(
                              value: opt,
                              child: Text(
                                opt,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedIncomeTarget = val);
                          },
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _submitIncome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.income,
                        foregroundColor: AppColors.surfaceWhite,
                      ),
                      child: const Text('Catat Pemasukan'),
                    ),
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Catat Pengeluaran',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // Amount input
              Text(
                'Nominal',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _inputController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.lora(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.02,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '250000',
                  hintStyle: GoogleFonts.lora(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.02,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.baseBeige.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Merchant
              Text(
                'Merchant (opsional)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _merchantController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Nama toko',
                  filled: true,
                  fillColor: AppColors.baseBeige.withValues(alpha: 0.3),
                ),
              ),

              const SizedBox(height: 20),

              // Items
              Text(
                'Item (opsional)',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _itemsController,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Deskripsi pembelian',
                  filled: true,
                  fillColor: AppColors.baseBeige.withValues(alpha: 0.3),
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
                        'Dibebankan ke',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
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
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.baseBeige.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM yyyy', 'id_ID').format(_receiptDate),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _submitExpense(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: AppColors.surfaceWhite,
                  ),
                  child: const Text('Catat Pengeluaran'),
                ),
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? color : AppColors.textTertiary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppColors.baseBeige.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? color : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
