import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../utils/app_colors.dart';
import '../widgets/edit_category_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return DateFormat('dd MMM yyyy', 'id_ID').format(time);
  }

  void _showSignOutDialog(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Data Anda akan tetap tersimpan di Google Drive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              'Keluar',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );
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

            // Account section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Consumer2<AuthService, DriveService>(
                  builder: (context, auth, drive, _) {
                    final isSignedIn = auth.isSignedIn;
                    final isGoogleUser = auth.isGoogleUser;

                    if (!isSignedIn) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mode Offline',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Data tersimpan lokal. Login untuk sync ke Drive.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final user = await auth.signIn();
                                if (user == null && auth.lastError != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(auth.lastError!),
                                      backgroundColor: AppColors.expense,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Masuk',
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // User login via email tapi belum connect Google Drive
                    if (!isGoogleUser) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
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
                                color: AppColors.warning.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.cloud_off, size: 20, color: AppColors.warning),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sync Tidak Aktif',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Login dengan Google untuk aktifkan sync Drive.',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final user = await auth.signIn();
                                if (user == null && auth.lastError != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(auth.lastError!),
                                      backgroundColor: AppColors.expense,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Hubungkan',
                                style: TextStyle(color: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final isSyncing = drive.isSyncing;
                    final lastSyncError = drive.lastSyncError;
                    final lastSyncTime = drive.lastSyncTime;

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.accentTint,
                                child: Icon(
                                  Icons.cloud_done,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Google Drive',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Tersinkronasi',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                isSyncing ? Icons.sync : Icons.cloud_done,
                                size: 16,
                                color: isSyncing
                                    ? AppColors.warning
                                    : (lastSyncError != null ? AppColors.error : AppColors.income),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isSyncing
                                      ? 'Menyinkronkan...'
                                      : lastSyncError != null
                                          ? 'Sync gagal'
                                          : lastSyncTime != null
                                              ? 'Terakhir disync: ${_formatSyncTime(lastSyncTime)}'
                                              : 'Belum pernah disync',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _showSignOutDialog(context, auth),
                                child: Text(
                                  'Keluar',
                                  style: TextStyle(color: AppColors.expense),
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

            // Categories section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                        '${repo.categories.length} KATEGORI'.toUpperCase(),
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

                          // Category list
                          ...repo.categories.asMap().entries.map((entry) {
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
                                      if (repo.categories.length > 1)
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
                                if (index < repo.categories.length - 1)
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
    final existingNames = repo.categories.map((c) => c.name).toList();

    // Total persentase semua kategori KECUALI yang sedang diedit
    final totalOther = repo.categories
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
          'Kategori "${category.name}" akan dihapus permanen.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BudgetRepository>().deleteCategory(category.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kategori "${category.name}" dihapus'),
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
            child: const Text('Hapus'),
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
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final defaultName = 'hyper_budget_$timestamp.csv';
    
    final path = await FilePicker.saveFile(
      dialogTitle: 'Simpan CSV',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    
    if (path == null) return;
    
    final file = File(path);
    await file.writeAsString(csv);
    
    if (context.mounted) {
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
