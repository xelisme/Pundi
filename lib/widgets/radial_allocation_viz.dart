import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'package:intl/intl.dart';

class RadialAllocationViz extends StatefulWidget {
  final Map<String, double> allocations;
  final Map<String, Color> colors;
  final double centerAmount;
  final String centerLabel;
  final double strokeWidth;
  final double? size;

  const RadialAllocationViz({
    super.key,
    required this.allocations,
    required this.colors,
    this.centerAmount = 0,
    this.centerLabel = '',
    this.strokeWidth = 28,
    this.size,
  });

  @override
  State<RadialAllocationViz> createState() => _RadialAllocationVizState();
}

class _RadialAllocationVizState extends State<RadialAllocationViz>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo, // More refined, less bouncy
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadialPainter(
            allocations: widget.allocations,
            colors: widget.colors,
            animationValue: _animation.value,
            strokeWidth: widget.strokeWidth,
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rp ${_fmt(widget.centerAmount)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  if (widget.centerLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.centerLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _fmt(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }
}

class _RadialPainter extends CustomPainter {
  final Map<String, double> allocations;
  final Map<String, Color> colors;
  final double animationValue;
  final double strokeWidth;

  _RadialPainter({
    required this.allocations,
    required this.colors,
    required this.animationValue,
    this.strokeWidth = 28,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2 - 8;

    final total = allocations.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) return;

    // Subtle background track - warm beige tone
    final trackPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    double startAngle = -pi / 2;

    for (final entry in allocations.entries) {
      final sweepAngle = (entry.value / total) * 2 * pi * animationValue;
      final color = colors[entry.key] ?? AppColors.textTertiary;

      // Subtle inner shadow for depth (drawn first, behind arc)
      final innerShadowPaint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        startAngle,
        sweepAngle,
        false,
        innerShadowPaint,
      );

      // Main arc with refined color
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      // Very subtle highlight on top edge
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + strokeWidth / 2 - 1),
        startAngle,
        sweepAngle,
        false,
        highlightPaint,
      );

      startAngle += sweepAngle;
    }

    // Inner circle - warm surface white with subtle gradient feel
    final innerBgPaint = Paint()
      ..color = AppColors.surfaceWhite
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - strokeWidth / 2 - 2, innerBgPaint);
    
    // Inner circle subtle border
    final innerBorderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - strokeWidth / 2 - 2, innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _RadialPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.allocations != allocations;
  }
}
