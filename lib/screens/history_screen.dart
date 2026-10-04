import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/period_summary.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/payment_method_field.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _fmt(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  void _showTransactionOptions(BuildContext context, TransactionRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Opsi Transaksi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showEditDialog(context, record);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Transaksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.surfaceWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _confirmArchive(context, record);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Arsipkan Transaksi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmArchive(BuildContext context, TransactionRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arsipkan Transaksi?'),
        content: const Text(
          'Transaksi ini dipindahkan ke Arsip dan dikeluarkan dari semua '
          'perhitungan. Bisa dipulihkan kapan saja dari Riwayat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final repo = context.read<BudgetRepository>();
              Navigator.pop(context);
              if (repo.archiveTransaction(record.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Transaksi diarsipkan'),
                    backgroundColor: AppColors.success,
                    // The undo lives here rather than in a separate screen,
                    // because the common case is a mis-tap seconds ago.
                    action: SnackBarAction(
                      label: 'Urungkan',
                      textColor: AppColors.surfaceWhite,
                      onPressed: () => repo.restoreTransaction(record.id),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, TransactionRecord record) {
    final amountController = TextEditingController(text: record.totalAmount.toString());
    final merchantController = TextEditingController(text: record.merchantName);
    final itemsController = TextEditingController(text: record.items);
    String? selectedChargedTo = record.chargedTo;
    var selectedPaymentMethod = record.paymentMethod;
    DateTime editReceiptDate = DateTime.fromMillisecondsSinceEpoch(record.receiptDate);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Transaksi'),
          content: SingleChildScrollView(
            child: Consumer<BudgetRepository>(
              builder: (context, repo, _) {
                final isExpense = record.type == TransactionType.expense;
                final options = [allCategoriesLabel, ...repo.activeCategories.map((c) => c.name)];
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isExpense) ...[
                      TextField(
                        controller: merchantController,
                        decoration: const InputDecoration(
                          labelText: 'Merchant',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Income stores its note in the same column, so both
                    // record types get one editable free-text field.
                    TextField(
                      controller: itemsController,
                      decoration: InputDecoration(
                        labelText: isExpense ? 'Item' : 'Catatan',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PaymentMethodField(
                        value: selectedPaymentMethod,
                        onChanged: (v) =>
                            setDialogState(() => selectedPaymentMethod = v),
                      ),
                    ),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Nominal',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedChargedTo ?? options.first,
                      decoration: const InputDecoration(
                        labelText: 'Dibebankan ke',
                        border: OutlineInputBorder(),
                      ),
                      items: options.map((opt) {
                        return DropdownMenuItem(value: opt, child: Text(opt));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedChargedTo = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: editReceiptDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => editReceiptDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Struk',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(editReceiptDate)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  context.read<BudgetRepository>().updateTransaction(
                    transactionId: record.id,
                    newAmount: amount,
                    newMerchantName: merchantController.text,
                    newItems: itemsController.text,
                    newChargedTo: selectedChargedTo,
                    newReceiptDate: editReceiptDate.millisecondsSinceEpoch,
                    newPaymentMethod: selectedPaymentMethod,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaksi berhasil diupdate'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<BudgetRepository>(
          builder: (context, repo, _) {
            final history = repo.activeHistory;

            return CustomScrollView(
              slivers: [
                // Duolingo green hero header
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.green,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Riwayat',
                                style: GoogleFonts.nunito(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // Archived rows are the user's data but not
                                // their spending, so the count shows only what
                                // still counts and the archive is surfaced
                                // further down as its own section.
                                '${history.length} transaksi',
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
                          child: const Icon(Icons.history, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),

                // Empty state
                if (history.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 36,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada transaksi',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Ledger-style transaction list
                if (history.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Column(
                          children: [
                            // Ledger header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                              child: Row(
                                children: [
                                  const SizedBox(width: 3),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Tanggal',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Deskripsi',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textTertiary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      'Nominal',
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

                            // Transaction rows
                            ...history.asMap().entries.map((entry) {
                              final index = entry.key;
                              final record = entry.value;
                              final isExpense = record.type == TransactionType.expense;
                              // Group and label rows by when the money moved, the
                              // same basis Ringkasan sums on. Using the input
                              // timestamp here made a 30-Sep receipt keyed in on
                              // 1 Oct appear under October in one screen and
                              // September in the other.
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                  effectiveDate(record));
                              final color = isExpense ? AppColors.expense : AppColors.income;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => _showTransactionOptions(context, record),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                        // Type indicator bar
                                        Container(
                                          width: 3,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Date column
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('dd MMM', 'id_ID').format(date),
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('HH:mm', 'id_ID').format(date),
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              // The row is now dated by the receipt, so when the two differ it is the keyed-in
                                              // date worth surfacing — that is the one the user may want to
                                              // double-check.
                                              if (record.receiptDate > 0 &&
                                                  record.receiptDate !=
                                                      record.timestamp)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    'Diinput ${DateFormat('dd MMM', 'id_ID').format(DateTime.fromMillisecondsSinceEpoch(record.timestamp))}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .textTertiary,
                                                          fontSize: 10,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Description column
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (isExpense && record.merchantName.isNotEmpty)
                                                Text(
                                                  record.merchantName,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              if (isExpense && record.items.isNotEmpty)
                                                Text(
                                                  record.items,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              if (isExpense && record.chargedTo != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    record.chargedTo!,
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: color,
                                                    ),
                                                  ),
                                                ),
                                              if (!isExpense)
                                                Text(
                                                  'Pemasukan',
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: color,
                                                  ),
                                                ),
                                              // Notes work for income too — same
                                              // column expenses use.
                                              if (!isExpense && record.items.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    record.items,
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (!isExpense && record.splits.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    '${record.splits.length} alokasi',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                ),
                                              // Payment method, for both record
                                              // types — a muted last line so it
                                              // stays secondary to merchant /
                                              // notes / allocation.
                                              if (record.paymentMethod.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    record.paymentMethod,
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: AppColors.textTertiary,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // Amount column - right aligned
                                        SizedBox(
                                          width: 100,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                isExpense ? '−' : '+',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                  height: 1.2,
                                                ),
                                              ),
                                              Text(
                                                'Rp ${_fmt(record.totalAmount)}',
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                  letterSpacing: -0.01,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (index < history.length - 1)
                                    Divider(color: AppColors.divider, height: 1),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}
