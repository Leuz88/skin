import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScanAnimation extends StatefulWidget {
  final bool isActive;
  const ScanAnimation({super.key, this.isActive = false});

  @override
  State<ScanAnimation> createState() => _ScanAnimationState();
}

class _ScanAnimationState extends State<ScanAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (widget.isActive) _startAnimations();
  }

  @override
  void didUpdateWidget(ScanAnimation old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _startAnimations();
    } else if (!widget.isActive && old.isActive) {
      _pulseCtrl.stop();
      _rippleCtrl.stop();
    }
  }

  void _startAnimations() {
    _pulseCtrl.repeat(reverse: true);
    _rippleCtrl.repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          if (widget.isActive)
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _rippleCtrl,
                builder: (_, __) {
                  final delay = i / 3;
                  final progress =
                      (((_rippleCtrl.value - delay) % 1.0 + 1.0) % 1.0);
                  return Opacity(
                    opacity: (1 - progress).clamp(0.0, 0.5),
                    child: Container(
                      width: 80 + progress * 120,
                      height: 80 + progress * 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Center circle
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, child) => Transform.scale(
              scale: widget.isActive ? _scaleAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: widget.isActive
                      ? [AppTheme.primary, AppTheme.primaryDark]
                      : [const Color(0xFFB0BEC5), const Color(0xFF90A4AE)],
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        )
                      ]
                    : [],
              ),
              child: Icon(
                widget.isActive ? Icons.wifi_tethering : Icons.sensors_off,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
