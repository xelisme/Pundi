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
import '../screens/archive_screen.dart';
import '../utils/app_colors.dart';
import '../utils/app_info.dart';
import '../widgets/edit_category_dialog.dart';
import '../widgets/restore_actions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kelola kategori alokasi',
                            style: GoogleFonts.plusJakartaSans(
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
                                        style: GoogleFonts.plusJakartaSans(
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

// Deactivated categories — restorable, but not deleted.
            //
            // Only nonaktif lives here. Anything the user *deleted* is on the
            // Arsip screen behind the row below, because that list grows with
            // every deletion and this screen is meant to stay a fixed set of
            // settings.
            //
            // This MUST be a Consumer, not context.read: context.read does not
            // register a dependency, so a soft-delete / archive / restore would
            // never make these sections appear or disappear.
            SliverToBoxAdapter(
              child: Consumer<BudgetRepository>(
                builder: (context, repo, _) {
                  final inactive = repo.categories
                      .where((c) => !c.isActive && !c.isArchived)
                      .toList();
                  if (inactive.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _CategoryRecoveryCard(
                      title: 'KATEGORI NONAKTIF',
                      hint: 'Riwayat tetap tersimpan',
                      categories: inactive,
                      onRestore: (c) => confirmRestoreCategory(context, c),
                    ),
                  );
                },
              ),
            ),

            // One row, always the same height, whatever has been deleted. The
            // count is the only thing that changes, so the user can tell there
            // is something to recover without opening a screen full of records.
            SliverToBoxAdapter(
              child: Consumer<BudgetRepository>(
                builder: (context, repo, _) {
                  final total = repo.archivedHistory.length +
                      repo.archivedCategories.length;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _ArchiveEntryRow(
                      count: total,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ArchiveScreen()),
                      ),
                    ),
                  );
                },
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


            // Copyright / license — parked at the very bottom so it is present
            // but never in the way, and tapping it opens the actual grant
            // rather than just asserting that one exists.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: _AboutFooter(
                  notice: appCopyrightNotice,
                  version: appVersion,
                  licenseName: appLicenseName,
                  onTapLicense: () => _showLicenseDialog(context),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  /// The full MIT grant, shown verbatim and selectable so it can actually be
  /// copied — a copyright notice nobody can read is not a real one.
  void _showLicenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Lisensi $appLicenseName',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              appLicenseText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tutup',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
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
          '• Arsipkan${txCount > 0 ? ' — $txCount transaksi akan dipindahkan ke kategori lain (wajib pilih)' : ' — tidak ada transaksi, langsung masuk arsip'}. Kategori tidak hilang, masih bisa dipulihkan dari Arsip.',
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
              _confirmArchiveCategory(context, category);
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

  void _confirmArchiveCategory(BuildContext context, AllocationCategory category) {
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
            'Arsipkan Kategori?',
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
                      final ok = repo.archiveCategory(
                        category.id,
                        reassignTo: txCount > 0 ? selected : null,
                      );
                      Navigator.of(context).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Kategori "${category.name}" diarsipkan${txCount > 0 ? ' & $txCount transaksi dipindahkan' : ''}'
                                : 'Gagal mengarsipkan kategori'),
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

      // Count what was actually written, including archived rows. Quoting the
      // CSV length keeps the two in step if the exporter ever changes shape.
      final csvRowCount = repo.history.length;
      
      // Share the file using share_plus
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Export Pundi - $csvRowCount transaksi',
      );
      
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV berhasil diekspor: $csvRowCount transaksi'),
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

/// One "recoverable categories" panel: a titled card listing categories that
/// are out of active use, each with a PULIHKAN action. Shared by the nonaktif
/// and arsip lists so both stay visually identical.
class _CategoryRecoveryCard extends StatelessWidget {
  final String title;
  final String hint;
  final List<AllocationCategory> categories;
  final ValueChanged<AllocationCategory> onRestore;

  const _CategoryRecoveryCard({
    required this.title,
    required this.hint,
    required this.categories,
    required this.onRestore,
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.dimmedIndicator,
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
                              style:
                                  Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.dimmedTitle,
                                      ),
                            ),
                            Text(
                              hint,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.dimmedSecondary),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => onRestore(category),
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
                if (index < categories.length - 1)
                  Divider(color: AppColors.divider, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// The one Pengaturan row that leads to the Arsip screen.
///
/// Separate from [_SettingsAction] because it carries a count, and that count
/// is the point: it is the only thing in this screen that changes as the user
/// deletes more, so the screen itself stays a fixed set of rows. The row is the
/// same size whether the archive holds one record or two hundred.
class _ArchiveEntryRow extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ArchiveEntryRow({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baru dihapus',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'Belum ada yang dihapus'
                          : '$count catatan bisa dipulihkan',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: count == 0
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copyright + license footer, last thing in Pengaturan.
///
/// Deliberately quiet: one muted line with the notice, and the license name as
/// the only tappable part. Nothing here competes with the settings actions
/// above it, but the full grant is one tap away and selectable.
class _AboutFooter extends StatelessWidget {
  final String notice;
  final String version;
  final String licenseName;
  final VoidCallback onTapLicense;

  const _AboutFooter({
    required this.notice,
    required this.version,
    required this.licenseName,
    required this.onTapLicense,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textTertiary,
          fontSize: 11,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$appName v$version', style: muted),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$notice · ', style: muted),
            GestureDetector(
              onTap: onTapLicense,
              child: Text(
                'Lihat lisensi',
                style: muted?.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
                borderRadius: BorderRadius.circular(8),
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
