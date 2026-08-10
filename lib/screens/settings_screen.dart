import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transaction.dart';
import '../repositories/budget_repository.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import '../widgets/edit_category_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
      backgroundColor: AppColors.baseBeige,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kelola kategori alokasi',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Account section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Consumer2<AuthService, BudgetRepository>(
                  builder: (context, auth, repo, _) {
                    final isSignedIn = auth.isSignedIn;

                    if (!isSignedIn) {
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
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
                                    'Data tersimpan lokal. Login untuk sync ke cloud.',
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

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
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
                                      'Cloud Sync',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      auth.user?.email ?? 'Tersinkronasi',
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
                                repo.isLoadingFromCloud ? Icons.sync : Icons.cloud_done,
                                size: 16,
                                color: repo.isLoadingFromCloud
                                    ? AppColors.warning
                                    : AppColors.income,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  repo.isLoadingFromCloud
                                      ? 'Memuat data...'
                                      : 'Data tersimpan di cloud',
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
                        borderRadius: BorderRadius.circular(16),
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
                                        'Kategori Alokasi',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${repo.categories.length} kategori',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showEditDialog(context, null),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Tambah'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accent,
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
                                        style: GoogleFonts.lora(
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
                    borderRadius: BorderRadius.circular(16),
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

  void _showEditDialog(BuildContext context, AllocationCategory? category) {
    showDialog(
      context: context,
      builder: (context) => EditCategoryDialog(category: category),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      borderRadius: BorderRadius.circular(16),
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
