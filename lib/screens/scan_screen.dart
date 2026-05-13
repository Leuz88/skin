import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_animation.dart';
import '../widgets/device_status_badge.dart';
import 'report_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  Patient? _selectedPatient;
  bool _withMakeup = false;

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceProvider>();
    final scan = context.watch<ScanProvider>();
    final patients = context.watch<PatientProvider>();

    final isScanning = device.isScanning;
    final canScan =
        device.isConnected && !isScanning && _selectedPatient != null;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Left: scan control ───────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nuova Scansione',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Seleziona il paziente e avvia l\'analisi cutanea',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 32),

                // Patient selector card
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paziente',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<Patient>(
                        value: _selectedPatient,
                        hint: const Text('Seleziona paziente…'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: patients.patients
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.name),
                                ))
                            .toList(),
                        onChanged: (p) {
                          setState(() => _selectedPatient = p);
                          if (p != null) scan.selectPatient(p.id);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _withMakeup,
                            onChanged: (v) =>
                                setState(() => _withMakeup = v ?? false),
                          ),
                          const Text('Con trucco / make-up'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Scan animation + button
                _buildCard(
                  child: Column(
                    children: [
                      ScanAnimation(isActive: isScanning),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: canScan
                              ? () => device.triggerScan()
                              : null,
                          icon: Icon(isScanning
                              ? Icons.hourglass_top
                              : Icons.play_circle_fill),
                          label: Text(isScanning
                              ? 'Scansione in corso…'
                              : 'Avvia Scansione'),
                        ),
                      ),
                      if (!device.isConnected) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Collega l\'analizzatore USB per abilitare la scansione.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_selectedPatient == null &&
                          device.isConnected) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Seleziona un paziente per procedere.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 28),

          // ─── Right: last results preview ─────────────────
          Expanded(
            flex: 3,
            child: _buildLastResults(context, scan),
          ),
        ],
      ),
    );
  }

  Widget _buildLastResults(BuildContext context, ScanProvider scan) {
    final result = scan.currentResult;
    if (result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_chart_outlined,
                size: 72, color: AppTheme.cardBorder),
            const SizedBox(height: 16),
            Text('Nessuna scansione disponibile',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // Navigate to report automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Handled by navigator in report screen
    });

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Risultato',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Esporta PDF'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ScanResultPreview(result: result),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
