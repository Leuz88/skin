import 'scan_result.dart';

/// Una zona del viso da fotografare durante la sessione.
class ScanZone {
  final String key;
  final String label;
  final String instruction;

  /// Parametri cutanei rilevati principalmente da questa zona.
  final List<SkinParam> params;

  /// Posizione del cerchio di indicazione overlay sulla figura Diagram01.png
  /// in coordinate normalizzate (0.0–1.0 relativo alla dimensione del widget).
  final double overlayX;
  final double overlayY;
  final double overlayRadius;

  const ScanZone({
    required this.key,
    required this.label,
    required this.instruction,
    required this.params,
    required this.overlayX,
    required this.overlayY,
    this.overlayRadius = 0.10,
  });
}

/// Le 5 zone standard per l'analisi cutanea del viso.
/// L'ordine corrisponde alla sequenza di acquisizione consigliata.
const List<ScanZone> kScanZones = [
  ScanZone(
    key: 'forehead',
    label: 'Fronte',
    instruction: 'Posiziona l\'analizzatore al centro della fronte',
    params: [SkinParam.rughe, SkinParam.texture, SkinParam.olio],
    overlayX: 0.50,
    overlayY: 0.16,
    overlayRadius: 0.11,
  ),
  ScanZone(
    key: 'cheek_left',
    label: 'Guancia sinistra',
    instruction: 'Posiziona l\'analizzatore sulla guancia sinistra',
    params: [SkinParam.umidita, SkinParam.pigmentazione, SkinParam.collagene],
    overlayX: 0.25,
    overlayY: 0.50,
    overlayRadius: 0.10,
  ),
  ScanZone(
    key: 'nose',
    label: 'Naso',
    instruction: 'Posiziona l\'analizzatore sul dorso del naso',
    params: [SkinParam.olio, SkinParam.pori],
    overlayX: 0.50,
    overlayY: 0.48,
    overlayRadius: 0.08,
  ),
  ScanZone(
    key: 'cheek_right',
    label: 'Guancia destra',
    instruction: 'Posiziona l\'analizzatore sulla guancia destra',
    params: [SkinParam.sensibilita, SkinParam.pori, SkinParam.collagene],
    overlayX: 0.75,
    overlayY: 0.50,
    overlayRadius: 0.10,
  ),
  ScanZone(
    key: 'periocular',
    label: 'Area perioculare',
    instruction: 'Posiziona l\'analizzatore sull\'area intorno agli occhi',
    params: [SkinParam.rughe, SkinParam.collagene],
    overlayX: 0.50,
    overlayY: 0.32,
    overlayRadius: 0.09,
  ),
];

/// Dato un insieme di parametri selezionati, restituisce le zone necessarie.
List<ScanZone> zonesForParams(Set<SkinParam> selectedParams) {
  if (selectedParams.isEmpty) return List.from(kScanZones);
  return kScanZones
      .where((z) => z.params.any((p) => selectedParams.contains(p)))
      .toList();
}

/// Dato un insieme di foto acquisite (zoneKey → filePath),
/// calcola gli score per ogni parametro aggregando le zone.
/// Ogni parametro prende lo score dalla sua zona primaria (indice 0 in params).
Map<SkinParam, double> aggregateScores({
  required Map<String, List<double>> zoneScores, // zoneKey → 8 scores raw
}) {
  final result = <SkinParam, double>{};

  for (final zone in kScanZones) {
    final scores = zoneScores[zone.key];
    if (scores == null) continue;
    for (final param in zone.params) {
      // Prendi il valore dal canale corrispondente al parametro nella zona
      final rawScore = scores[param.index];
      // Media se più zone coprono lo stesso parametro
      if (result.containsKey(param)) {
        result[param] = (result[param]! + rawScore) / 2.0;
      } else {
        result[param] = rawScore;
      }
    }
  }

  // Parametri non coperti → default 5.0
  for (final param in SkinParam.values) {
    result.putIfAbsent(param, () => 5.0);
  }

  return result;
}
