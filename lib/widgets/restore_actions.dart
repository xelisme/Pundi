import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';

/// Reactivate a category.
///
/// Confirmed with a dialog, because it has a side effect worth reading before
/// it happens: the category's transactions reappear in the allocation.
///
/// `restoreCategory` returns false when reactivating would push allocations past
/// 100%, in which case the category is restored as nonaktif instead. That is
/// reported rather than swallowed, because the user asked for it back and would
/// otherwise see nothing happen.
void confirmRestoreCategory(
    BuildContext context, AllocationCategory category) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Pulihkan Kategori?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: Text(
        'Kategori "${category.name}" akan aktif kembali dan riwayat transaksinya kembali muncul di alokasi.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final reactivated =
                context.read<BudgetRepository>().restoreCategory(category.id);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(reactivated
                    ? 'Kategori "${category.name}" dipulihkan'
                    : 'Kategori "${category.name}" dipulihkan ke nonaktif — alokasi 100% sudah penuh'),
                backgroundColor: reactivated ? AppColors.green : AppColors.warning,
                behavior: SnackBarBehavior.floating,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: AppColors.surfaceWhite,
          ),
          child: const Text('Pulihkan'),
        ),
      ],
    ),
  );
}

/// Restore an archived transaction.
///
/// No confirmation dialog, unlike [confirmRestoreCategory]. A category restore
/// moves transactions back into the allocation and is worth a beat; this is
/// pure undo — the record returns to the exact slot it came from and can be
/// archived again instantly. A dialog in front of a reversible action is only a
/// second thing to dismiss.
void confirmRestoreTransaction(
    BuildContext context, TransactionRecord record) {
  final repo = context.read<BudgetRepository>();
  if (!repo.restoreTransaction(record.id)) return;
  final label = record.merchantName.isNotEmpty
      ? record.merchantName
      : (record.items.isNotEmpty ? record.items : 'Pemasukan');
  final amount = NumberFormat('#,##0', 'id_ID').format(record.totalAmount.round());
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label · Rp $amount dipulihkan'),
      backgroundColor: AppColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

/// Human label for a transaction, used wherever an archived row or a restore
/// confirmation has to name the record.
String transactionLabel(TransactionRecord record) => record.merchantName.isNotEmpty
    ? record.merchantName
    : (record.items.isNotEmpty ? record.items : 'Pemasukan');
