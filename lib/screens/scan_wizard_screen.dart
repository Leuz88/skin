import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patient.dart';
import '../models/scan_result.dart';
import '../models/scan_zone.dart';
import '../providers/device_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/scan_provider.dart';
import '../services/camera_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScanWizardScreen — 3 step wizard
// ─────────────────────────────────────────────────────────────────────────────

class ScanWizardScreen extends StatefulWidget {
  /// Chiamato dopo aver salvato l'analisi — consente a HomeScreen
  /// di passare alla scheda Referti.
  final VoidCallback? onNavigateToReports;

  const ScanWizardScreen({super.key, this.onNavigateToReports});

  @override
  State<ScanWizardScreen> createState() => _ScanWizardScreenState();
}

class _ScanWizardScreenState extends State<ScanWizardScreen> {
  int _step = 0;
  Patient? _selectedPatient;
  final Set<SkinParam> _selectedParams = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _WizardHeader(step: _step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_step) {
                0 => _PatientStep(key: const ValueKey(0), onNext: _onPatientSelected),
                1 => _ParamsStep(
                    key: const ValueKey(1),
                    selectedParams: _selectedParams,
                    onParamsChanged: (p) => setState(() { _selectedParams.clear(); _selectedParams.addAll(p); }),
                    onBack: () => setState(() => _step = 0),
                    onNext: _onParamsConfirmed,
                  ),
                2 => _ZonesStep(
                    key: const ValueKey(2),
                    patient: _selectedPatient!,
                    onBack: () => setState(() => _step = 1),
                    onFinish: _onFinish,
                  ),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onPatientSelected(Patient patient) => setState(() { _selectedPatient = patient; _step = 1; });

  Future<void> _onParamsConfirmed() async {
    final scan = context.read<ScanProvider>();
    await scan.startWizard(patientId: _selectedPatient!.id);
    scan.selectParams(_selectedParams);
    setState(() => _step = 2);
  }

  Future<void> _onFinish(List<double> scores) async {
    final scan = context.read<ScanProvider>();
    final result = await scan.finalizeSession(scores);
    if (!mounted || result == null) return;
    // Resetta il wizard a step 0 per la prossima analisi
    setState(() {
      _step = 0;
      _selectedPatient = null;
      _selectedParams.clear();
    });
    // Naviga alla scheda Referti in HomeScreen
    widget.onNavigateToReports?.call();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wizard header
// ─────────────────────────────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int step;
  const _WizardHeader({required this.step});

  @override
  Widget build(BuildContext context) {
    const steps = ['Paziente', 'Parametri', 'Analisi'];
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) Expanded(child: Divider(color: i <= step ? AppTheme.primary : AppTheme.cardBorder, thickness: 1.5)),
            _StepDot(index: i, label: steps[i], active: i == step, done: i < step),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;
  const _StepDot({required this.index, required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppTheme.primary : AppTheme.textDisabled;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: done ? AppTheme.primary : (active ? AppTheme.primary.withAlpha(20) : Colors.transparent),
          foregroundColor: done ? Colors.white : color,
          child: done
              ? const Icon(Icons.check, size: 16)
              : Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Paziente
// ─────────────────────────────────────────────────────────────────────────────

class _PatientStep extends StatefulWidget {
  final void Function(Patient) onNext;
  const _PatientStep({super.key, required this.onNext});
  @override
  State<_PatientStep> createState() => _PatientStepState();
}

class _PatientStepState extends State<_PatientStep> {
  final _searchCtrl = TextEditingController();
  Patient? _selected;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona paziente', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Scegli il paziente da esaminare o creane uno nuovo.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Cerca per nome…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) { context.read<PatientProvider>().search(v); setState(() {}); },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Nuovo paziente'),
                onPressed: () => showDialog(context: context, builder: (_) => const _AddPatientDialog()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<PatientProvider>(
              builder: (_, pp, __) {
                final pts = pp.patients;
                if (pts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search, size: 56, color: AppTheme.cardBorder),
                        const SizedBox(height: 12),
                        const Text('Nessun paziente trovato',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return Card(
                  child: ListView.separated(
                    itemCount: pts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = pts[i];
                      final sel = _selected?.id == p.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: sel ? AppTheme.primary : AppTheme.surfaceVariant,
                          foregroundColor: sel ? Colors.white : AppTheme.textSecondary,
                          child: Text(p.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(p.age != null ? '${p.age} anni · ${p.sex.label}' : p.sex.label),
                        selected: sel,
                        selectedTileColor: AppTheme.primary.withAlpha(12),
                        trailing: sel ? Icon(Icons.check_circle, color: AppTheme.primary) : null,
                        onTap: () => setState(() => _selected = p),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    'Selezionato: ${_selected!.name}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              FilledButton.icon(
                onPressed: _selected != null ? () => widget.onNext(_selected!) : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Avanti'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Parametri
// ─────────────────────────────────────────────────────────────────────────────

class _ParamsStep extends StatelessWidget {
  final Set<SkinParam> selectedParams;
  final void Function(Set<SkinParam>) onParamsChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _ParamsStep({
    super.key,
    required this.selectedParams,
    required this.onParamsChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parametri da analizzare',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          const Text('Seleziona i problemi di interesse. Lascia tutto deselezionato per analizzare tutte le zone.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: SkinParam.values.map((p) {
                final sel = selectedParams.contains(p);
                return GestureDetector(
                  onTap: () {
                    final updated = Set<SkinParam>.from(selectedParams);
                    if (sel) updated.remove(p); else updated.add(p);
                    onParamsChanged(updated);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: sel ? AppTheme.primary.withAlpha(15) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? AppTheme.primary : AppTheme.cardBorder,
                        width: sel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        p.label,
                        style: TextStyle(
                          color: sel ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Indietro')),
              FilledButton.icon(onPressed: onNext, icon: const Icon(Icons.arrow_forward), label: const Text('Avanti')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Acquisizione zone
// ─────────────────────────────────────────────────────────────────────────────

class _ZonesStep extends StatefulWidget {
  final Patient patient;
  final VoidCallback onBack;
  final Future<void> Function(List<double>) onFinish;

  const _ZonesStep({super.key, required this.patient, required this.onBack, required this.onFinish});

  @override
  State<_ZonesStep> createState() => _ZonesStepState();
}

class _ZonesStepState extends State<_ZonesStep> {
  bool _capturing = false;
  bool _analyzing = false;
  late DeviceProvider _deviceProvider;

  @override
  void initState() {
    super.initState();
    _deviceProvider = context.read<DeviceProvider>();
    _deviceProvider.onPhysicalButtonPressed = _onPhysicalButton;
  }

  @override
  void dispose() {
    if (_deviceProvider.onPhysicalButtonPressed == _onPhysicalButton) {
      _deviceProvider.onPhysicalButtonPressed = null;
    }
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing) return;
    if (!CameraService.instance.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotocamera non inizializzata — premi "Inizializza fotocamera" prima di scattare.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    setState(() => _capturing = true);
    _deviceProvider.deviceService.ledOn();
    await Future.delayed(const Duration(milliseconds: 600));
    final bytes = await CameraService.instance.captureFrameBytes();
    _deviceProvider.deviceService.ledOff();
    if (bytes != null && bytes.isNotEmpty && mounted) {
      await scan.saveZonePhoto(jpegBytes: bytes.toList());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acquisizione fallita — controlla che la fotocamera sia attiva.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (mounted) setState(() => _capturing = false);
  }

  void _onPhysicalButton() { if (!_capturing) _capture(); }

  Future<void> _startAnalysis() async {
    setState(() => _analyzing = true);
    // Assicura LED spento prima dell'elaborazione
    _deviceProvider.deviceService.ledOff();
    final scan = context.read<ScanProvider>();
    final photos = scan.capturedPhotos;

    final zoneRawScores = <String, List<double>>{};
    for (final entry in photos.entries) {
      try {
        final bytes = Uint8List.fromList(await File(entry.value.filePath).readAsBytes());
        final scores = await CameraService.instance.analyzeImage(bytes);
        zoneRawScores[entry.key] = scores;
      } catch (_) {}
    }

    final aggregated = aggregateScores(zoneScores: zoneRawScores);
    final scoreList = SkinParam.values.map((p) => aggregated[p] ?? 5.0).toList();

    await widget.onFinish(scoreList);
    if (mounted) setState(() => _analyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final zones = scan.pendingZones;
    final currentIdx = scan.currentZoneIndex;
    final captured = scan.capturedPhotos;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // ── Pannello diagramma ────────────────────────────────
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Expanded(
                  child: Card(
                    child: _DiagramPanel(zones: zones, captured: captured, currentIdx: currentIdx),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: zones.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final z = zones[i];
                      final photo = captured[z.key];
                      return GestureDetector(
                        onTap: () => scan.goToZone(i),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: i == currentIdx
                                  ? AppTheme.primary
                                  : (photo != null ? AppTheme.primaryLight : AppTheme.cardBorder),
                              width: i == currentIdx ? 2 : 1,
                            ),
                          ),
                          child: photo != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image.file(File(photo.filePath), fit: BoxFit.cover),
                                )
                              : const Icon(Icons.photo_camera, size: 20, color: AppTheme.textDisabled),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Fotocamera + controlli ────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (currentIdx < zones.length)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primary.withAlpha(15),
                            foregroundColor: AppTheme.primary,
                            child: Text(
                              '${currentIdx + 1}/${zones.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(zones[currentIdx].label,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                Text(zones[currentIdx].instruction,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (captured.containsKey(zones[currentIdx].key))
                            const Icon(Icons.check_circle, color: AppTheme.connected),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: const _CameraPreviewPanel(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Indietro')),
                    Row(
                      children: [
                        const Text('o premi il tasto fisico',
                            style: TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _capturing ? null : _capture,
                          icon: _capturing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.camera_alt),
                          label: Text(_capturing ? 'Acquisizione…' : 'Scatta foto'),
                        ),
                      ],
                    ),
                    if (scan.allZonesDone)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.connected),
                        onPressed: _analyzing ? null : _startAnalysis,
                        icon: _analyzing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.analytics),
                        label: Text(_analyzing ? 'Analisi in corso…' : 'Avvia analisi'),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diagramma viso con cerchi overlay
// ─────────────────────────────────────────────────────────────────────────────

class _DiagramPanel extends StatelessWidget {
  final List<ScanZone> zones;
  final Map<String, ZonePhoto> captured;
  final int currentIdx;

  const _DiagramPanel({required this.zones, required this.captured, required this.currentIdx});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/images/Diagram01.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.face, size: 80, color: AppTheme.cardBorder),
            ),
          ),
        ),
        CustomPaint(
          painter: _ZoneOverlayPainter(zones: zones, captured: captured, currentIdx: currentIdx),
        ),
      ],
    );
  }
}

class _ZoneOverlayPainter extends CustomPainter {
  final List<ScanZone> zones;
  final Map<String, ZonePhoto> captured;
  final int currentIdx;

  const _ZoneOverlayPainter({required this.zones, required this.captured, required this.currentIdx});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < zones.length; i++) {
      final z = zones[i];
      final cx = z.overlayX * size.width;
      final cy = z.overlayY * size.height;
      final r  = z.overlayRadius * size.width;
      final isDone    = captured.containsKey(z.key);
      final isCurrent = i == currentIdx;

      if (isCurrent) {
        canvas.drawCircle(
          Offset(cx, cy), r,
          Paint()..color = AppTheme.primary.withAlpha(25)..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..color = isCurrent ? AppTheme.primary : (isDone ? AppTheme.connected : AppTheme.textDisabled)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 2.5 : 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_ZoneOverlayPainter old) =>
      old.currentIdx != currentIdx || old.captured.length != captured.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera preview panel
// ─────────────────────────────────────────────────────────────────────────────

class _CameraPreviewPanel extends StatefulWidget {
  const _CameraPreviewPanel();
  @override
  State<_CameraPreviewPanel> createState() => _CameraPreviewPanelState();
}

class _CameraPreviewPanelState extends State<_CameraPreviewPanel> {
  @override
  Widget build(BuildContext context) {
    // ListenableBuilder reagisce a TUTTI i cambiamenti del CameraService
    return ListenableBuilder(
      listenable: CameraService.instance,
      builder: (_, __) {
        final cs = CameraService.instance;

        // ── In corso: spinner ──────────────────────────────────────────
        if (cs.isInitializing) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text('Apertura fotocamera…',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ],
          );
        }

        // ── Non inizializzata: errore + lista camera ───────────────────
        if (!cs.isInitialized) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off,
                  size: 48, color: AppTheme.textDisabled),
              const SizedBox(height: 12),
              if (cs.error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    cs.error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text('Fotocamera non disponibile',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
              ],
              // Lista fotocamere disponibili
              if (cs.cameras.isNotEmpty) ...[
                const Text('Seleziona fotocamera:',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                ...List.generate(cs.cameras.length, (i) {
                  final c = cs.cameras[i];
                  final label = _cameraLabel(c, i);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 32),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.videocam, size: 16),
                      label:
                          Text(label, style: const TextStyle(fontSize: 12)),
                      onPressed: () => cs.selectCamera(i),
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
              TextButton(
                onPressed: () => cs.reinitialize(),
                child: const Text('Reinizializza (auto-detect)'),
              ),
            ],
          );
        }

        // ── Inizializzata: preview ─────────────────────────────────────
        final controller = cs.controller;
        if (controller == null) return const SizedBox.shrink();

        return Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            if (cs.cameras.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: _CameraSelector(),
              ),
          ],
        );
      },
    );
  }

  String _cameraLabel(CameraDescription c, int index) {
    final name = c.name.length > 40 ? '${c.name.substring(0, 40)}…' : c.name;
    if (c.lensDirection == CameraLensDirection.external) return 'Esterna  [$name]';
    if (c.lensDirection == CameraLensDirection.front)    return 'Anteriore [$name]';
    return 'Camera $index [$name]';
  }
}

class _CameraSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cameras = CameraService.instance.cameras;
    return PopupMenuButton<int>(
      icon: const Icon(Icons.switch_camera, color: Colors.white70),
      tooltip: 'Cambia fotocamera',
      itemBuilder: (_) => List.generate(cameras.length, (i) {
        final c = cameras[i];
        final label = c.lensDirection == CameraLensDirection.external
            ? 'Analizzatore (esterna)'
            : c.lensDirection == CameraLensDirection.front
                ? 'Anteriore'
                : 'Posteriore';
        final shortName = c.name.length > 28 ? '${c.name.substring(0, 28)}…' : c.name;
        return PopupMenuItem<int>(
          value: i,
          child: Text('$label  [$shortName]', style: const TextStyle(fontSize: 12)),
        );
      }),
      onSelected: (i) => CameraService.instance.selectCamera(i),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nuovo paziente dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddPatientDialog extends StatefulWidget {
  const _AddPatientDialog();
  @override
  State<_AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<_AddPatientDialog> {
  final _nameCtrl = TextEditingController();
  final _telCtrl  = TextEditingController();
  Sex _sex = Sex.nonSpecificato;

  @override
  void dispose() { _nameCtrl.dispose(); _telCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo paziente'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome e cognome *'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telCtrl,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Sex>(
              value: _sex,
              decoration: const InputDecoration(labelText: 'Sesso'),
              items: Sex.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _sex = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            final p = Patient(name: _nameCtrl.text.trim(), sex: _sex, telephone: _telCtrl.text.trim());
            context.read<PatientProvider>().addPatient(p);
            Navigator.pop(context);
          },
          child: const Text('Salva'),
        ),
      ],
    );
  }
}
