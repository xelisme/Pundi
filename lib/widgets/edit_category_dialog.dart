import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction.dart';
import '../utils/app_colors.dart';

const _presetColors = [
  '#3B82F6', // Blue
  '#10B981', // Green
  '#F59E0B', // Amber
  '#8B5CF6', // Purple
  '#EF4444', // Red
  '#EC4899', // Pink
  '#06B6D4', // Cyan
  '#84CC16', // Lime
  '#F97316', // Orange
  '#6366F1', // Indigo
  '#14B8A6', // Teal
  '#A855F7', // Violet
];

class EditCategoryDialog extends StatefulWidget {
  final AllocationCategory? category;
  final List<String> existingNames;
  /// Total persentase semua kategori KECUALI kategori yang sedang diedit.
  /// Dipakai untuk validasi agar total tidak melebihi 100%.
  final double totalOtherPercentages;

  const EditCategoryDialog({
    super.key,
    this.category,
    this.existingNames = const [],
    this.totalOtherPercentages = 0,
  });

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late TextEditingController _nameController;
  late TextEditingController _percentController;
  late TextEditingController _descController;
  late String _selectedColor;

  String? _nameError;
  String? _percentError;

  // Persentase yang saat ini diketik user (untuk hint real-time)
  double? _currentPercent;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _percentController = TextEditingController(
      text: widget.category?.percentage.toInt().toString() ?? '',
    );
    _descController = TextEditingController(text: widget.category?.description ?? '');
    _selectedColor = widget.category?.colorHex ?? _presetColors[0];
    _currentPercent = widget.category?.percentage;

    _percentController.addListener(_onPercentChanged);
  }

  void _onPercentChanged() {
    final val = double.tryParse(_percentController.text.trim());
    setState(() {
      _currentPercent = val;
      // Reset error saat user mengetik ulang
      _percentError = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _percentController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  double get _maxAvailable => 100.0 - widget.totalOtherPercentages;

  void _save() {
    final name = _nameController.text.trim();
    final percent = double.tryParse(_percentController.text.trim());

    setState(() {
      _nameError = null;
      _percentError = null;
    });

    if (name.isEmpty) {
      setState(() => _nameError = 'Nama kategori harus diisi');
      return;
    }

    if (percent == null || percent <= 0) {
      setState(() => _percentError = 'Persentase harus lebih dari 0');
      return;
    }

    // Validasi total tidak melebihi 100%
    final total = widget.totalOtherPercentages + percent;
    if (total > 100) {
      setState(() {
        _percentError =
            'Total akan menjadi ${total.toStringAsFixed(0)}%. '
            'Maksimal tersisa ${_maxAvailable.toStringAsFixed(0)}%';
      });
      return;
    }

    // Cek nama duplikat (kecuali kategori yang sedang diedit)
    final isDuplicate = widget.existingNames.any(
      (n) => n.toLowerCase() == name.toLowerCase() && n != widget.category?.name,
    );
    if (isDuplicate) {
      setState(() => _nameError = 'Nama kategori sudah ada');
      return;
    }

    final category = AllocationCategory(
      name: name,
      percentage: percent,
      colorHex: _selectedColor,
      description: _descController.text.trim(),
    );

    Navigator.pop(context, category);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? errorText,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.baseBeige.withValues(alpha: 0.3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      labelStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.textMedium,
      ),
      errorStyle: const TextStyle(
        fontSize: 11,
        color: AppColors.error,
      ),
    );
  }

  /// Chip hint di bawah field persentase yang tampil real-time.
  Widget _buildPercentHint() {
    final max = _maxAvailable;
    final current = _currentPercent;

    // Hitung total jika ada input
    final total = current != null ? widget.totalOtherPercentages + current : null;
    final isOver = total != null && total > 100;

    Color chipColor;
    Color textColor;
    String label;

    if (isOver) {
      chipColor = AppColors.error.withValues(alpha: 0.1);
      textColor = AppColors.error;
      label = 'Total ${total.toStringAsFixed(0)}% — melebihi 100%';
    } else if (current != null && current > max * 0.9 && max > 0) {
      chipColor = AppColors.warning.withValues(alpha: 0.12);
      textColor = AppColors.warning;
      label = 'Hampir penuh — sisa ${(max - current).clamp(0, 100).toStringAsFixed(0)}%';
    } else {
      chipColor = AppColors.accent.withValues(alpha: 0.08);
      textColor = AppColors.textTertiary;
      label = 'Tersedia: ${max.toStringAsFixed(0)}% dari 100%';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final canSave = _currentPercent != null &&
        _currentPercent! > 0 &&
        (widget.totalOtherPercentages + _currentPercent!) <= 100;

    return AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.all(24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEditing ? 'Edit Kategori' : 'Tambah Kategori',
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.03,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Atur alokasi budget Anda',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textTertiary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionLabel('Informasi Kategori'),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration(
                label: 'Nama Kategori',
                errorText: _nameError,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _percentController,
              decoration: _inputDecoration(
                label: 'Persentase Alokasi',
                suffix: '%',
                errorText: _percentError,
              ),
              keyboardType: TextInputType.number,
            ),
            _buildPercentHint(),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: _inputDecoration(
                label: 'Deskripsi (opsional)',
              ),
              maxLines: 2,
            ),
            _sectionLabel('Pilih Warna'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _presetColors.map((hex) {
                final isSelected = hex == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.textPrimary : AppColors.border,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMedium,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'BATAL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextButton(
          // Disable tombol SIMPAN jika input tidak valid
          onPressed: canSave ? _save : null,
          style: TextButton.styleFrom(
            backgroundColor: canSave ? AppColors.accent : AppColors.border,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'SIMPAN',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
