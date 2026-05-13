import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';

/// Gauge circolare animato per un singolo parametro cutaneo.
class SkinGauge extends StatefulWidget {
  final SkinParam param;
  final double score;       // 0.0 – 9.9
  final double size;
  final bool showLabel;
  final bool animate;

  const SkinGauge({
    super.key,
    required this.param,
    required this.score,
    this.size = 140,
    this.showLabel = true,
    this.animate = true,
  });

  @override
  State<SkinGauge> createState() => _SkinGaugeState();
}

class _SkinGaugeState extends State<SkinGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0, end: widget.score)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (widget.animate) _ctrl.forward();
  }

  @override
  void didUpdateWidget(SkinGauge old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _anim = Tween<double>(begin: old.score, end: widget.score)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final current = _anim.value;
        final color = AppTheme.scoreColor(current);
        final range = scoreRangeFor(widget.param, current);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _GaugePainter(
                  score: current,
                  color: color,
                  paramColor: AppTheme.paramColors[widget.param.index],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        current.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: widget.size * 0.22,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/ 9.9',
                        style: TextStyle(
                          fontSize: widget.size * 0.1,
                          color: AppTheme.textDisabled,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 8),
              Text(
                widget.param.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color paramColor;

  _GaugePainter({
    required this.score,
    required this.color,
    required this.paramColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.shortestSide / 2) - 10;
    const startAngle = pi * 0.75;         // 135°
    const totalAngle = pi * 1.5;          // 270° sweep
    const strokeWidth = 10.0;

    // Track (sfondo grigio)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8EDF5);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      totalAngle,
      false,
      trackPaint,
    );

    // Ticks
    final tickPaint = Paint()
      ..color = const Color(0xFFD0D8E8)
      ..strokeWidth = 1.5;
    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (i / 10) * totalAngle;
      final inner = radius - 6;
      final outer = radius + 4;
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        tickPaint,
      );
    }

    // Progress arc with gradient
    if (score > 0) {
      final sweepAngle = (score / 9.9) * totalAngle;
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [paramColor.withValues(alpha: 0.6), color],
          transform: const GradientRotation(startAngle),
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );

      // Dot at end of arc
      final endAngle = startAngle + sweepAngle;
      final dotX = cx + radius * cos(endAngle);
      final dotY = cy + radius * sin(endAngle);
      canvas.drawCircle(
        Offset(dotX, dotY),
        strokeWidth / 2 + 1,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.color != color;
}
