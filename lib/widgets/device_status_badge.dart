import 'package:flutter/material.dart';
import '../providers/device_provider.dart';

class DeviceStatusBadge extends StatefulWidget {
  final DeviceStatus status;
  const DeviceStatusBadge({super.key, required this.status});

  @override
  State<DeviceStatusBadge> createState() => _DeviceStatusBadgeState();
}

class _DeviceStatusBadgeState extends State<DeviceStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final String label;

    switch (widget.status) {
      case DeviceStatus.connected:
        dotColor = const Color(0xFF2E7D32);
        label = 'Connesso';
      case DeviceStatus.scanning:
        dotColor = const Color(0xFFF9A825);
        label = 'Scansione…';
      case DeviceStatus.disconnected:
        dotColor = const Color(0xFFB0BEC5);
        label = 'Non connesso';
    }

    final bool shouldBlink = widget.status == DeviceStatus.scanning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Opacity(
              opacity: shouldBlink ? _anim.value : 1.0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: dotColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1)
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}
