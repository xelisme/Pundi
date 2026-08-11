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

  const EditCategoryDialog({super.key, this.category, this.existingNames = const []});

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _percentController = TextEditingController(
      text: widget.category?.percentage.toInt().toString() ?? '',
    );
    _descController = TextEditingController(text: widget.category?.description ?? '');
    _selectedColor = widget.category?.colorHex ?? _presetColors[0];
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

  void _save() {
    final name = _nameController.text.trim();
    final percent = double.tryParse(_percentController.text.trim());

    setState(() {
      _nameError = null;
      _percentError = null;
    });

    if (name.isEmpty) {
      setState(() {
        _nameError = 'Nama kategori harus diisi';
      });
      return;
    }

    if (percent == null || percent <= 0) {
      setState(() {
        _percentError = 'Persentase harus lebih dari 0';
      });
      return;
    }

    // Check duplicate name (exclude current category if editing)
    final isDuplicate = widget.existingNames.any(
      (n) => n.toLowerCase() == name.toLowerCase() && n != widget.category?.name,
    );
    if (isDuplicate) {
      setState(() {
        _nameError = 'Nama kategori sudah ada';
      });
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

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
          onPressed: _save,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.accent,
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
