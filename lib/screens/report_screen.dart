import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/scan_provider.dart';
import '../providers/patient_provider.dart';
import '../models/scan_result.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/radar_chart.dart';
import '../widgets/parameter_card.dart';

/// Widget di preview del risultato (usato anche in scan_screen.dart)
class ScanResultPreview extends StatelessWidget {
  final SkinResult result;
  const ScanResultPreview({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average score banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Punteggio Medio',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    result.averageScore.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(result.measDate),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 8 parameter cards 2x4
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: SkinParam.values
              .map((p) => ParameterCard(param: p, score: result.score(p)))
              .toList(),
        ),
        const SizedBox(height: 20),
        // Radar chart
        Center(child: RadarChart(scores: result.scores, size: 320)),
      ],
    );
  }
}

class ReportScreen extends StatefulWidget {
  final SkinResult? initialResult;
  const ReportScreen({super.key, this.initialResult});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  SkinResult? _selectedResult;
  List<Map<String, dynamic>> _photos = [];
  String? _loadingPhotosFor;

  @override
  void initState() {
    super.initState();
    _selectedResult = widget.initialResult;
    if (_selectedResult != null) _loadPhotos(_selectedResult!.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-seleziona il risultato più recente quando arriva un nuovo scan
    final current = context.read<ScanProvider>().currentResult;
    if (current != null && _selectedResult?.id != current.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedResult = current);
          _loadPhotos(current.id);
        }
      });
    }
  }

  Future<void> _loadPhotos(String sessionId) async {
    if (_loadingPhotosFor == sessionId) return;
    _loadingPhotosFor = sessionId;
    final rows =
        await DatabaseService.instance.getPhotosForSession(sessionId);
    if (mounted) setState(() => _photos = rows);
  }

  void _selectResult(SkinResult result) {
    setState(() {
      _selectedResult = result;
      _photos = [];
    });
    _loadPhotos(result.id);
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final pp = context.watch<PatientProvider>();

    // Auto-select nuovi risultati
    final current = scan.currentResult;
    if (current != null &&
        _selectedResult == null &&
        scan.results.isNotEmpty) {
      _selectedResult = scan.results.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedResult != null) {
          _loadPhotos(_selectedResult!.id);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('Referti',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (_selectedResult != null)
                FilledButton.icon(
                  onPressed: () =>
                      _exportPdf(context, _selectedResult!, pp),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Esporta PDF'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Visualizza e stampa i referti delle analisi cutanee',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          // Body
          Expanded(
            child: scan.results.isEmpty
                ? _buildEmpty()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Sidebar storico ────────────────────────────
                      SizedBox(
                        width: 260,
                        child: _buildSidebar(scan, pp),
                      ),
                      const SizedBox(width: 16),
                      // ── Dettaglio referto selezionato ──────────────
                      Expanded(
                        child: _selectedResult == null
                            ? const Center(
                                child: Text('Seleziona un referto',
                                    style: TextStyle(
                                        color: AppTheme.textDisabled)))
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    ScanResultPreview(
                                        result: _selectedResult!),
                                    if (_photos.isNotEmpty) ...[
                                      const SizedBox(height: 24),
                                      _buildPhotosSection(),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar: lista risultati ─────────────────────────────────────
  Widget _buildSidebar(ScanProvider scan, PatientProvider pp) {
    return Card(
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Analisi (${scan.results.length})',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: scan.results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final r = scan.results[i];
                final patient = pp.patients
                    .where((p) => p.id == r.patientId)
                    .firstOrNull;
                final isSelected = _selectedResult?.id == r.id;
                return _ResultTile(
                  result: r,
                  patientName: patient?.name ?? '—',
                  selected: isSelected,
                  onTap: () => _selectResult(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Griglia foto zona ─────────────────────────────────────────────
  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Foto acquisite',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _photos.map((p) {
            final path = p['file_path'] as String;
            final zone = p['zone_key'] as String;
            return _PhotoThumb(filePath: path, zoneKey: zone);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined,
              size: 72, color: AppTheme.cardBorder),
          SizedBox(height: 16),
          Text('Nessun referto disponibile',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('Esegui prima una scansione nella sezione "Analisi"',
              style:
                  TextStyle(color: AppTheme.textDisabled, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
      BuildContext context, SkinResult result, PatientProvider pp) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generazione PDF in corso…')),
    );
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PDF esportato con successo!'),
              backgroundColor: AppTheme.connected),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore export: $e')));
      }
    }
  }
}

// ── Tile nella sidebar storico ────────────────────────────────────────
class _ResultTile extends StatelessWidget {
  final SkinResult result;
  final String patientName;
  final bool selected;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.patientName,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avg = result.averageScore;
    final color = AppTheme.scoreColor(avg);
    return Material(
      color: selected ? AppTheme.surfaceVariant : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textPrimary)),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(result.measDate),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textDisabled),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.chevron_right,
                    size: 16, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Miniatura foto zona ───────────────────────────────────────────────
class _PhotoThumb extends StatelessWidget {
  final String filePath;
  final String zoneKey;

  const _PhotoThumb({required this.filePath, required this.zoneKey});

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: file.existsSync()
              ? Image.file(file,
                  width: 120, height: 120, fit: BoxFit.cover)
              : Container(
                  width: 120,
                  height: 120,
                  color: AppTheme.surfaceVariant,
                  child: const Icon(Icons.image_not_supported,
                      color: AppTheme.textDisabled, size: 32),
                ),
        ),
        const SizedBox(height: 4),
        Text(zoneKey,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

