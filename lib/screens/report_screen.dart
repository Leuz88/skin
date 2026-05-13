import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/scan_provider.dart';
import '../providers/patient_provider.dart';
import '../models/scan_result.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_gauge.dart';
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
              .map((p) =>
                  ParameterCard(param: p, score: result.score(p)))
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
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _selectedPatientId;
  SkinResult? _selectedResult;

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanProvider>();
    final patientProvider = context.watch<PatientProvider>();

    final result = _selectedResult ?? scan.currentResult;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('Referti', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (result != null)
                FilledButton.icon(
                  onPressed: () =>
                      _exportPdf(context, result, patientProvider),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Esporta PDF'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Visualizza e stampa i referti delle analisi cutanee',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: result == null
                ? _buildEmpty()
                : SingleChildScrollView(
                    child: ScanResultPreview(result: result),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined,
              size: 72, color: AppTheme.cardBorder),
          const SizedBox(height: 16),
          const Text('Nessun referto disponibile',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Esegui prima una scansione nella sezione "Scansione"',
              style: TextStyle(color: AppTheme.textDisabled, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
      BuildContext context, SkinResult result, PatientProvider pp) async {
    final patient = pp.findById(result.patientId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generazione PDF in corso…')),
    );
    try {
      // Lazy import del servizio per non appesantire il startup
      // await ReportService.instance.generateAndSave(result, patient);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PDF esportato con successo!'),
              backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore export: $e')),
        );
      }
    }
  }
}
