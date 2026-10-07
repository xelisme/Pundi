import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';

/// Duolingo-style 3D button with box-shadow effect
/// 
/// Features:
/// - 48px height (Duolingo standard)
/// - 3D box-shadow depth (4px offset)
/// - Active state: shadow removed, translateY(4px)
/// - Uppercase bold text
/// - 12px border-radius
class DuolingoButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final DuolingoButtonType type;
  final bool fullWidth;
  final bool isLoading;
  final IconData? icon;

  const DuolingoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.type = DuolingoButtonType.primary,
    this.fullWidth = false,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<DuolingoButton> createState() => _DuolingoButtonState();
}

class _DuolingoButtonState extends State<DuolingoButton> {
  bool _isPressed = false;

  Color get _backgroundColor {
    switch (widget.type) {
      case DuolingoButtonType.primary:
        return AppColors.green;
      case DuolingoButtonType.secondary:
        return Colors.transparent;
      case DuolingoButtonType.danger:
        return AppColors.red;
      case DuolingoButtonType.warning:
        return AppColors.orange;
      case DuolingoButtonType.success:
        return AppColors.golden;
    }
  }

  Color get _shadowColor {
    switch (widget.type) {
      case DuolingoButtonType.primary:
        return AppColors.greenShadow;
      case DuolingoButtonType.secondary:
        return AppColors.grayText;
      case DuolingoButtonType.danger:
        return const Color(0xFFCC0000);
      case DuolingoButtonType.warning:
        return const Color(0xFFCC7700);
      case DuolingoButtonType.success:
        return const Color(0xFFCCA000);
    }
  }

  Color get _textColor {
    switch (widget.type) {
      case DuolingoButtonType.secondary:
        return AppColors.blue;
      default:
        return Colors.white;
    }
  }

  Border? get _border {
    if (widget.type == DuolingoButtonType.secondary) {
      return Border.all(color: AppColors.borderColor, width: 2);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLoading) {
          widget.onPressed();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.fullWidth ? double.infinity : null,
        height: 48,
        transform: Matrix4.translationValues(0, _isPressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: _border,
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: _shadowColor,
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: widget.isLoading
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_textColor),
                  ),
                ),
              )
            : Row(
                mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: _textColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

enum DuolingoButtonType {
  primary,   // Green (default)
  secondary, // Transparent with border, blue text
  danger,    // Red
  warning,   // Orange
  success,   // Golden
}
