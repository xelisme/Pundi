import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../utils/app_colors.dart';
import '../widgets/edit_category_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                color: AppColors.green,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan',
                            style: GoogleFonts.nunito(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola kategori alokasi',
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
                      child: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            ),

            // Categories section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Consumer<BudgetRepository>(
                  builder: (context, repo, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Section header
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'KATEGORI ALOKASI',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppColors.textPrimary,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${repo.activeCategories.length} KATEGORI'.toUpperCase(),
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppColors.textTertiary,
                                          fontSize: 10,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showEditDialog(context, null),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'TAMBAH',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(color: AppColors.divider, height: 1),

                          // Active category list
                          ...repo.categories.where((c) => c.isActive).toList().asMap().entries.map((entry) {
                            final index = entry.key;
                            final category = entry.value;
                            final color = _hexToColor(category.colorHex);

                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color,
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
                                              ),
                                            ),
                                            if (category.description.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                category.description,
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${category.percentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.nunito(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.01,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () => _showEditDialog(context, category),
                                        color: AppColors.textSecondary,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                      if (repo.activeCategories.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          onPressed: () => _confirmDeleteCategory(context, category),
                                          color: AppColors.error,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        ),
                                    ],
                                  ),
                                ),
                                if (index < repo.activeCategories.length - 1)
                                  Divider(color: AppColors.divider, height: 1),
                              ],
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Deleted (soft-deleted) categories — restorable
            if (context.read<BudgetRepository>().categories.any((c) => !c.isActive))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: Text(
                            'KATEGORI DIHAPUS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textTertiary,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...context.read<BudgetRepository>().categories.where((c) => !c.isActive).map((category) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
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
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            'Riwayat tetap tersimpan',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _confirmRestoreCategory(context, category),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.green,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('PULIHKAN'),
                                    ),
                                  ],
                                ),
                              ),
                              if (category != context.read<BudgetRepository>().categories.where((c) => !c.isActive).last)
                                Divider(color: AppColors.divider, height: 1),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Actions section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      _SettingsAction(
                        icon: Icons.upload_file_outlined,
                        title: 'Export CSV',
                        subtitle: 'Ekspor riwayat ke file CSV',
                        color: AppColors.income,
                        onTap: () => _exportCsv(context),
                      ),
                      Divider(color: AppColors.divider, height: 1),
                      _SettingsAction(
                        icon: Icons.download_outlined,
                        title: 'Import CSV',
                        subtitle: 'Impor data dari file CSV',
                        color: AppColors.income,
                        onTap: () => _importCsv(context),
                      ),
                      Divider(color: AppColors.divider, height: 1),
                      _SettingsAction(
                        icon: Icons.refresh_outlined,
                        title: 'Reset Kategori',
                        subtitle: 'Kembalikan kategori ke pengaturan awal',
                        color: AppColors.accent,
                        onTap: () => _confirmReset(context),
                      ),
                      Divider(color: AppColors.divider, height: 1),
                      _SettingsAction(
                        icon: Icons.delete_forever_outlined,
                        title: 'Reset Semua Keuangan',
                        subtitle: 'Hapus semua riwayat & kategori kembali default',
                        color: AppColors.error,
                        onTap: () => _confirmResetAll(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  void _showEditDialog(BuildContext context, AllocationCategory? category) async {
    final repo = context.read<BudgetRepository>();
    // Only active categories count for the 100% allocation rule.
    final existingNames = repo.activeCategories.map((c) => c.name).toList();

    // Total persentase kategori AKTIF KECUALI yang sedang diedit
    final totalOther = repo.activeCategories
        .where((c) => c.id != category?.id)
        .fold<double>(0, (sum, c) => sum + c.percentage);

    final result = await showDialog<AllocationCategory>(
      context: context,
      builder: (context) => EditCategoryDialog(
        category: category,
        existingNames: existingNames,
        totalOtherPercentages: totalOther,
      ),
    );

    if (result != null && context.mounted) {
      if (category == null) {
        repo.addCategory(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori "${result.name}" ditambahkan'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        repo.updateCategory(category.id, result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori "${result.name}" diperbarui'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _confirmDeleteCategory(BuildContext context, AllocationCategory category) {
    final repo = context.read<BudgetRepository>();
    final txCount = repo.transactionCountForCategory(category.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Hapus Kategori?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Pilih salah satu:\n\n'
          '• Nonaktifkan — kategori disembunyikan, riwayat tetap ada & bisa dipulihkan. Tidak bisa terima transaksi baru.\n\n'
          '• Hapus Permanen${txCount > 0 ? ' — $txCount transaksi akan dipindahkan ke kategori lain (wajib pilih)' : ' — tidak ada transaksi, kategori dihapus langsung'}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              repo.deleteCategory(category.id);
              Navigator.of(context).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kategori "${category.name}" dinonaktifkan'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Nonaktifkan'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmPermanentDelete(context, category);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }

  void _confirmPermanentDelete(BuildContext context, AllocationCategory category) {
    final repo = context.read<BudgetRepository>();
    final txCount = repo.transactionCountForCategory(category.name);
    final targets = repo.activeCategories.where((c) => c.id != category.id).toList();

    String? selected = targets.isNotEmpty ? targets.first.name : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Hapus Permanen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: txCount > 0
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$txCount transaksi pada "${category.name}" akan dipindahkan ke:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selected,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: allCategoriesLabel,
                          child: Text(allCategoriesLabel),
                        ),
                        ...targets.map((c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => selected = v),
                    ),
                  ],
                )
              : Text(
                  'Kategori "${category.name}" tidak punya transaksi. Akan dihapus langsung.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: txCount > 0 && selected == null
                  ? null
                  : () {
                      final ok = repo.permanentlyDeleteCategory(
                        category.id,
                        reassignTo: txCount > 0 ? selected : null,
                      );
                      Navigator.of(context).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Kategori "${category.name}" dihapus${txCount > 0 ? ' & $txCount transaksi dipindahkan' : ''}'
                                : 'Gagal menghapus kategori'),
                            backgroundColor: ok ? AppColors.error : AppColors.expense,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.surfaceWhite,
              ),
              child: const Text('Hapus'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestoreCategory(BuildContext context, AllocationCategory category) {
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
              context.read<BudgetRepository>().restoreCategory(category.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kategori "${category.name}" dipulihkan'),
                  backgroundColor: AppColors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Reset Kategori?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Ini akan menghapus semua kategori custom dan kembali ke pengaturan awal: Tabungan (50%), Investasi (30%), Bebas (20%).',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BudgetRepository>().resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Kategori direset ke default'),
                  backgroundColor: AppColors.baseBrown,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmResetAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reset Semua Keuangan?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Semua riwayat transaksi akan dihapus dan kategori dikembalikan ke pengaturan awal. Tindakan ini tidak dapat dibatalkan.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BudgetRepository>().resetAllData();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Semua data keuangan direset ke default'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.surfaceWhite,
            ),
            child: const Text('Reset Semua'),
          ),
        ],
      ),
    );
  }

  void _exportCsv(BuildContext context) async {
    final repo = context.read<BudgetRepository>();
    final csv = repo.exportToCsv();
    
    if (csv.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tidak ada data untuk diekspor'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }
    
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'pundi_$timestamp.csv';
      final filePath = '${tempDir.path}/$fileName';
      
      // Write CSV to temporary file
      final file = File(filePath);
      await file.writeAsString(csv);
      
      // Share the file using share_plus
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Export Pundi - ${repo.history.length} transaksi',
      );
      
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV berhasil diekspor: ${repo.history.length} transaksi'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _importCsv(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    
    if (result == null || result.files.isEmpty) return;
    
    final file = File(result.files.first.path!);
    final csvContent = await file.readAsString();
    
    if (!context.mounted) return;
    
    final repo = context.read<BudgetRepository>();
    final imported = repo.importFromCsv(csvContent);

    if (context.mounted) {
      final failed = repo.lastImportFailedLines;
      if (failed.isNotEmpty) {
        final preview = failed.take(3).join('\n');
        final extra = failed.length > 3 ? '\n+ ${failed.length - 3} baris lainnya' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Impor: $imported berhasil, ${failed.length} gagal.\n$preview$extra'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$imported transaksi berhasil diimpor'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
