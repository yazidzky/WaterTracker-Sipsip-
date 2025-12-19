import 'dart:math';
import 'package:flutter/material.dart';

class WaterProgressPainter extends CustomPainter {
  final double percentage;
  final Color backgroundColor;
  final Color progressColor;
  final double? customStrokeWidth; // Optional custom stroke width

  WaterProgressPainter({
    required this.percentage,
    required this.backgroundColor,
    required this.progressColor,
    this.customStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    
    // Use custom stroke width if provided, otherwise calculate based on size
    final strokeWidth = customStrokeWidth ?? (size.width > 100 ? 25.0 : 8.0);

    // Background Arc
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start from 135 degrees (bottom-leftish)
    // Sweep 270 degrees (leaving 90 degrees open at bottom)
    const startAngle = 135 * pi / 180;
    const sweepAngle = 270 * pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Calculate sweep based on percentage, capped at the full sweep angle
    final progressSweep = sweepAngle * percentage;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant WaterProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.customStrokeWidth != customStrokeWidth;
  }
}
