import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';

class RadarChart extends StatefulWidget {
  final List<double> scores; // 8 valori 0.0–9.9
  final double size;

  const RadarChart({super.key, required this.scores, this.size = 280});

  @override
  State<RadarChart> createState() => _RadarChartState();
}

class _RadarChartState extends State<RadarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(RadarChart old) {
    super.didUpdateWidget(old);
    if (old.scores != widget.scores) {
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
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RadarPainter(
          scores: widget.scores,
          progress: _anim.value,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> scores;
  final double progress; // 0.0 – 1.0 animation

  _RadarPainter({required this.scores, this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.shortestSide / 2) - 30;
    const sides = 8;
    const angleStep = 2 * pi / sides;
    // Start from top, rotate -π/2
    double angle(int i) => -pi / 2 + i * angleStep;

    // ── Grid rings ──
    for (int ring = 1; ring <= 5; ring++) {
      final ringR = r * ring / 5;
      final ringPaint = Paint()
        ..color = ring == 5
            ? const Color(0xFFCCD5E8)
            : const Color(0xFFE8EDF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring == 5 ? 1.5 : 1.0;

      final path = Path();
      for (int i = 0; i < sides; i++) {
        final a = angle(i);
        final p = Offset(cx + ringR * cos(a), cy + ringR * sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    // ── Spoke lines ──
    final spokePaint = Paint()
      ..color = const Color(0xFFE0E7F2)
      ..strokeWidth = 1.0;
    for (int i = 0; i < sides; i++) {
      final a = angle(i);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * cos(a), cy + r * sin(a)),
        spokePaint,
      );
    }

    // ── Data polygon ──
    final dataPath = Path();
    for (int i = 0; i < sides; i++) {
      final a = angle(i);
      final ratio = (scores[i] / 9.9).clamp(0.0, 1.0) * progress;
      final p = Offset(cx + r * ratio * cos(a), cy + r * ratio * sin(a));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppTheme.primary.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppTheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // ── Data points ──
    for (int i = 0; i < sides; i++) {
      final a = angle(i);
      final ratio = (scores[i] / 9.9).clamp(0.0, 1.0) * progress;
      final p = Offset(cx + r * ratio * cos(a), cy + r * ratio * sin(a));
      canvas.drawCircle(p, 5,
          Paint()..color = AppTheme.paramColors[i]);
      canvas.drawCircle(p, 5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }

    // ── Labels ──
    final labelR = r + 18;
    for (int i = 0; i < sides; i++) {
      final a = angle(i);
      final lx = cx + labelR * cos(a);
      final ly = cy + labelR * sin(a);
      final label = SkinParam.values[i].label;
      final score = (scores[i] * progress).toStringAsFixed(1);

      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
            TextSpan(
              text: score,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.paramColors[i],
                height: 1.1,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 64);

      tp.paint(canvas,
          Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.scores != scores || old.progress != progress;
}
