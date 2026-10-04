import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/period_summary.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/restore_actions.dart';

/// Everything the user deleted, in one place.
///
/// This is a dedicated screen rather than a panel inside Pengaturan on purpose.
/// Pengaturan is a fixed list of settings; the archive grows every time the
/// user deletes something, so leaving it inline turns that screen into a junk
/// drawer whose contents depend on how much has gone wrong. Pengaturan keeps one
/// row with a count; the records live here.
///
/// Two kinds of record are deleted in this app, so two sections: transactions
/// (archived rows, excluded from every total) and categories. They are not the
/// same thing and must never read as one flat list.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Arsip')),
      // Consumer, not context.read: restoring or purging has to rebuild this
      // screen, and a read would register no dependency.
      body: Consumer<BudgetRepository>(
        builder: (context, repo, _) {
          final transactions = repo.archivedHistory;
          final categories = repo.archivedCategories;
          final total = transactions.length + categories.length;

          if (total == 0) {
            // Deliberately an empty state rather than a blank page: the user
            // navigated here on purpose, so silence would read as a failure.
            return const _ArchiveEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              // Says plainly what being here means, before any list, so nobody
              // has to archive something to find out.
              Text(
                '$total catatan dihapus dan tidak dihitung. '
                'Semuanya masih di sini sampai kamu mengosongkan arsip.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              if (transactions.isNotEmpty) ...[
                _ArchiveSection(
                  title: 'TRANSAKSI',
                  count: transactions.length,
                  note: 'Tidak masuk perhitungan',
                  children: transactions
                      .map((record) => _TransactionRow(record: record))
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
              if (categories.isNotEmpty)
                _ArchiveSection(
                  title: 'KATEGORI',
                  count: categories.length,
                  note: 'Dihapus — masih bisa dipulihkan',
                  children: categories
                      .map((category) => _CategoryRow(category: category))
                      .toList(),
                ),
              const SizedBox(height: 32),
              _PurgeButton(
                transactionCount: transactions.length,
                categoryCount: categories.length,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Nothing has been deleted yet.
class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.border,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Arsip kosong',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Transaksi atau kategori yang kamu hapus akan muncul di sini '
              'dan bisa dipulihkan.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// One titled card of archived records, with dividers between rows.
///
/// The count sits in the header rather than in a body line so a long list can
/// be assessed before scrolling into it.
class _ArchiveSection extends StatelessWidget {
  final String title;
  final int count;
  final String note;
  final List<Widget> children;

  const _ArchiveSection({
    required this.title,
    required this.count,
    required this.note,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  note,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          for (var i = 0; i < children.length; i++) ...[
            Divider(color: AppColors.divider, height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// An archived transaction: dimmed, struck through, one restore control.
class _TransactionRow extends StatelessWidget {
  final TransactionRecord record;

  const _TransactionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final isExpense = record.type == TransactionType.expense;
    final date =
        DateTime.fromMillisecondsSinceEpoch(effectiveDate(record));
    final amount =
        NumberFormat('#,##0', 'id_ID').format(record.totalAmount.round());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Rail coloured by direction: a category row cannot show this, and it
          // is what tells income from expense at a glance in a list of both.
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: isExpense ? AppColors.expense : AppColors.income,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transactionLabel(record),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
                Text(
                  '${DateFormat('dd MMM yyyy', 'id_ID').format(date)} · '
                  '${isExpense ? 'Pengeluaran' : 'Pemasukan'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Struck through rather than hidden: the money was real, it is just
          // out of the maths, and the user should be able to see the value they
          // are putting back.
          Text(
            'Rp $amount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.textTertiary,
                ),
          ),
          const SizedBox(width: 4),
          _RestoreButton(onPressed: () => confirmRestoreTransaction(context, record)),
        ],
      ),
    );
  }
}

/// An archived category.
class _CategoryRow extends StatelessWidget {
  final AllocationCategory category;

  const _CategoryRow({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
                Text(
                  category.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          _RestoreButton(
              onPressed: () => confirmRestoreCategory(context, category)),
        ],
      ),
    );
  }
}

class _RestoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RestoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('PULIHKAN'),
    );
  }
}

/// Destroy every archived record for good.
///
/// The one irreversible action in the app, so it is separated from restoring,
/// styled as destructive, and guarded by a dialog that names the exact number
/// of records about to be lost rather than asking generically.
class _PurgeButton extends StatelessWidget {
  final int transactionCount;
  final int categoryCount;

  const _PurgeButton({
    required this.transactionCount,
    required this.categoryCount,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _confirmPurge(context),
      icon: const Icon(Icons.delete_forever_outlined, size: 18),
      label: const Text('Kosongkan Arsip'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmPurge(BuildContext context) {
    final repo = context.read<BudgetRepository>();
    // Captured before the purge, because purging removes this very button from
    // the tree. Reaching for ScaffoldMessenger.of(context) afterwards would be
    // looking up an ancestor from an element that is already gone.
    final messenger = ScaffoldMessenger.of(context);
    final total = transactionCount + categoryCount;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Kosongkan Arsip?',
          style: Theme.of(dialogContext).textTheme.titleLarge,
        ),
        content: Text(
          '$total catatan akan dihapus permanen dan tidak bisa dipulihkan lagi.'
          '${transactionCount > 0 ? ' $transactionCount transaksi' : ''}'
          '${transactionCount > 0 && categoryCount > 0 ? ' dan' : ''}'
          '${categoryCount > 0 ? ' $categoryCount kategori' : ''} '
          'akan hilang.',
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final removed = repo.purgeArchived();
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('$removed catatan dihapus permanen'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );
  }
}
