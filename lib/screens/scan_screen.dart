import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../providers/device_provider.dart';
import '../providers/scan_provider.dart';
import '../providers/patient_provider.dart';
import '../models/patient.dart';
import '../services/camera_service.dart';
import '../theme/app_theme.dart';
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
  void initState() {
    super.initState();
    // Inizializza la fotocamera quando la schermata viene aperta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CameraService.instance.initialize();
    });
  }

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
                const Text('Seleziona il paziente e avvia l\'analisi cutanea',
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
                        initialValue: _selectedPatient,
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

                // Camera preview + scan button
                _buildCard(
                  child: Column(
                    children: [
                      _CameraPreviewPanel(isScanning: isScanning),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: canScan
                              ? () => _startScan(device)
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
                        const Text(
                          'Collega l\'analizzatore USB per abilitare la scansione.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_selectedPatient == null &&
                          device.isConnected) ...[
                        const SizedBox(height: 10),
                        const Text(
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

  Future<void> _startScan(DeviceProvider device) async {
    final bytes = await CameraService.instance.captureFrameBytes();
    await device.triggerScanWithImage(bytes);
  }

  Widget _buildLastResults(BuildContext context, ScanProvider scan) {
    final result = scan.currentResult;
    if (result == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_chart_outlined,
                size: 72, color: AppTheme.cardBorder),
            SizedBox(height: 16),
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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widget camera preview: mostra il feed live dell'analizzatore
// ─────────────────────────────────────────────────────────────
class _CameraPreviewPanel extends StatefulWidget {
  final bool isScanning;
  const _CameraPreviewPanel({required this.isScanning});

  @override
  State<_CameraPreviewPanel> createState() => _CameraPreviewPanelState();
}

class _CameraPreviewPanelState extends State<_CameraPreviewPanel> {
  @override
  Widget build(BuildContext context) {
    final cam = CameraService.instance;

    return AnimatedBuilder(
      animation: cam,
      builder: (context, _) {
        // Loading
        if (cam.isInitializing) {
          return _placeholder(
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text('Inizializzazione fotocamera…',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          );
        }

        // Errore
        if (cam.error != null) {
          return _placeholder(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, color: Colors.white54, size: 40),
                const SizedBox(height: 8),
                Text(cam.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => CameraService.instance.initialize(),
                  child: const Text('Riprova',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          );
        }

        // Preview attiva
        if (cam.isInitialized && cam.controller != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: cam.controller!.value.aspectRatio,
                  child: CameraPreview(cam.controller!),
                ),
                // Overlay mirino durante scansione
                if (widget.isScanning)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.8),
                          width: 2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                // Selezione fotocamera (se multipla)
                if (cam.cameras.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _CameraSwitchButton(cameras: cam.cameras),
                  ),
              ],
            ),
          );
        }

        // Stato disconnesso
        return _placeholder(
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, color: Colors.white38, size: 40),
              SizedBox(height: 8),
              Text('Fotocamera non disponibile',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder({required Widget child}) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _CameraSwitchButton extends StatelessWidget {
  final List<CameraDescription> cameras;
  const _CameraSwitchButton({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.switch_camera, color: Colors.white, size: 22),
      tooltip: 'Cambia fotocamera',
      onSelected: (index) => CameraService.instance.selectCamera(index),
      itemBuilder: (_) => cameras
          .asMap()
          .entries
          .map((e) => PopupMenuItem<int>(
                value: e.key,
                child: Row(children: [
                  Icon(_lensIcon(e.value.lensDirection), size: 16),
                  const SizedBox(width: 8),
                  Flexible(child: Text(e.value.name, overflow: TextOverflow.ellipsis)),
                ]),
              ))
          .toList(),
    );
  }

  IconData _lensIcon(CameraLensDirection dir) {
    return switch (dir) {
      CameraLensDirection.external => Icons.usb,
      CameraLensDirection.front => Icons.face,
      CameraLensDirection.back => Icons.camera_rear,
    };
  }
}
