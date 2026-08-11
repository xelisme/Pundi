import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Duolingo-style card with subtle shadow depth
/// 
/// Features:
/// - White background
/// - Subtle elevation (0 8px 24px rgba(0,0,0,0.12))
/// - 12px border-radius (Duolingo standard)
/// - Hover: scale(1.05) with deeper shadow
/// - Optional border color
class DuolingoCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final bool hoverable;

  const DuolingoCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
    this.hoverable = true,
  });

  @override
  State<DuolingoCard> createState() => _DuolingoCardState();
}

class _DuolingoCardState extends State<DuolingoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.hoverable ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.hoverable ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: widget.margin,
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color ?? Colors.white,
            borderRadius: BorderRadius.circular(12), // Duolingo: 12px
            border: widget.borderColor != null
                ? Border.all(
                    color: widget.borderColor!,
                    width: widget.borderWidth,
                  )
                : Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Duolingo-style metric card for displaying stats
/// 
/// Features:
/// - Colored icon/emoji
/// - Bold Nunito label
/// - Large Nunito value
/// - Optional subtitle
class DuolingoMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const DuolingoMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor = AppColors.green,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DuolingoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: AppColors.grayNav,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.darkBlue,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grayLight,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Duolingo-style list item card
/// 
/// Features:
/// - Horizontal layout (icon/avatar + content + trailing)
/// - Border on hover/tap
/// - Ripple effect
class DuolingoListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? borderColor;

  const DuolingoListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return DuolingoCard(
      padding: const EdgeInsets.all(16),
      borderColor: borderColor,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}
