import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/scan_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/device_status_badge.dart';
import 'scan_screen.dart';
import 'patients_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.radar_outlined),
      selectedIcon: Icon(Icons.radar),
      label: Text('Scansione'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Pazienti'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assessment_outlined),
      selectedIcon: Icon(Icons.assessment),
      label: Text('Referti'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Navigation Rail
          Container(
            color: AppTheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppTheme.primary, AppTheme.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.face_retouching_natural,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Skin\nAnalyzer',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (i) =>
                        setState(() => _selectedIndex = i),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppTheme.surface,
                    destinations: _destinations,
                  ),
                ),
                // Device status at bottom of rail
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: DeviceStatusBadge(status: device.status),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                ScanScreen(),
                PatientsScreen(),
                ReportScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
