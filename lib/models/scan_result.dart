import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// I parametri della skin analysis, in ordine.
enum SkinParam {
  umidita,
  olio,
  texture,
  collagene,
  rughe,
  pigmentazione,
  sensibilita,
  pori,
}

extension SkinParamExt on SkinParam {
  String get label {
    const labels = [
      'Umidità',
      'Olio',
      'Texture',
      'Fibra Collagene',
      'Rughe',
      'Pigmentazione',
      'Sensibilità',
      'Pori',
    ];
    return labels[index];
  }

  String get unit => '/9.9';

  int get resultType => index + 1;
}

class SkinResult {
  final String id;
  final DateTime measDate;
  final String patientId;
  final bool ifMakeup;

  /// Score 0.0–9.9 per ciascuno dei 8 parametri (indice = SkinParam.index)
  final List<double> scores;

  /// Numero range per ciascun parametro (es. 11–15 per Umidità)
  final List<int> resultNos;

  final String picPath;
  final String spotInfo;
  final String acneInfo;

  SkinResult({
    String? id,
    required this.measDate,
    required this.patientId,
    required this.scores,
    required this.resultNos,
    this.ifMakeup = false,
    this.picPath = '',
    this.spotInfo = '',
    this.acneInfo = '',
  }) : id = id ?? _uuid.v4();

  double score(SkinParam param) => scores[param.index];
  int resultNo(SkinParam param) => resultNos[param.index];

  /// Punteggio medio globale
  double get averageScore =>
      scores.reduce((a, b) => a + b) / scores.length;

  SkinResult copyWith({List<double>? scores, List<int>? resultNos}) =>
      SkinResult(
        id: id,
        measDate: measDate,
        patientId: patientId,
        scores: scores ?? this.scores,
        resultNos: resultNos ?? this.resultNos,
        ifMakeup: ifMakeup,
        picPath: picPath,
        spotInfo: spotInfo,
        acneInfo: acneInfo,
      );

  Map<String, dynamic> toMap() => {
        'session_id': id,
        'scores': jsonEncode(scores),
        'result_nos': jsonEncode(resultNos),
        'analyzed_at': measDate.toIso8601String(),
      };

  factory SkinResult.fromMap(Map<String, dynamic> m, {required String patientId}) {
    final List<double> scores = (jsonDecode(m['scores'] as String) as List)
        .map((e) => (e as num).toDouble())
        .toList();
    final List<int> resultNos = (jsonDecode(m['result_nos'] as String) as List)
        .map((e) => (e as num).toInt())
        .toList();
    return SkinResult(
      id: m['session_id'] as String,
      measDate: DateTime.parse(m['analyzed_at'] as String),
      patientId: patientId,
      scores: scores,
      resultNos: resultNos,
    );
  }
}

/// Ranges dalla tabella Result del DB originale
class ScoreRange {
  final int resultNo;
  final SkinParam param;
  final double min;
  final double max;
  final String label;

  const ScoreRange({
    required this.resultNo,
    required this.param,
    required this.min,
    required this.max,
    required this.label,
  });
}

const List<ScoreRange> kScoreRanges = [
  // Umidità (type 1)
  ScoreRange(resultNo: 11, param: SkinParam.umidita, min: 0.0, max: 1.1, label: 'Molto secca'),
  ScoreRange(resultNo: 12, param: SkinParam.umidita, min: 1.1, max: 3.7, label: 'Secca'),
  ScoreRange(resultNo: 13, param: SkinParam.umidita, min: 3.7, max: 5.6, label: 'Normale'),
  ScoreRange(resultNo: 14, param: SkinParam.umidita, min: 5.6, max: 7.5, label: 'Idratata'),
  ScoreRange(resultNo: 15, param: SkinParam.umidita, min: 7.5, max: 9.9, label: 'Molto idratata'),
  // Olio (type 2)
  ScoreRange(resultNo: 21, param: SkinParam.olio, min: 0.0, max: 1.3, label: 'Molto secca'),
  ScoreRange(resultNo: 22, param: SkinParam.olio, min: 1.3, max: 3.7, label: 'Normale'),
  ScoreRange(resultNo: 23, param: SkinParam.olio, min: 3.7, max: 7.9, label: 'Mista'),
  ScoreRange(resultNo: 24, param: SkinParam.olio, min: 7.9, max: 9.1, label: 'Grassa'),
  ScoreRange(resultNo: 25, param: SkinParam.olio, min: 9.1, max: 9.9, label: 'Molto grassa'),
  // Texture (type 3)
  ScoreRange(resultNo: 31, param: SkinParam.texture, min: 0.0, max: 1.2, label: 'Molto liscia'),
  ScoreRange(resultNo: 32, param: SkinParam.texture, min: 1.2, max: 2.4, label: 'Liscia'),
  ScoreRange(resultNo: 33, param: SkinParam.texture, min: 2.4, max: 3.6, label: 'Normale'),
  ScoreRange(resultNo: 34, param: SkinParam.texture, min: 3.6, max: 6.6, label: 'Irregolare'),
  ScoreRange(resultNo: 35, param: SkinParam.texture, min: 6.6, max: 9.9, label: 'Molto irregolare'),
  // Collagene (type 4)
  ScoreRange(resultNo: 41, param: SkinParam.collagene, min: 0.0, max: 1.2, label: 'Ottimo'),
  ScoreRange(resultNo: 42, param: SkinParam.collagene, min: 1.2, max: 2.6, label: 'Buono'),
  ScoreRange(resultNo: 43, param: SkinParam.collagene, min: 2.6, max: 4.3, label: 'Nella norma'),
  ScoreRange(resultNo: 44, param: SkinParam.collagene, min: 4.3, max: 7.8, label: 'Ridotto'),
  ScoreRange(resultNo: 45, param: SkinParam.collagene, min: 7.8, max: 9.9, label: 'Molto ridotto'),
  // Rughe (type 5)
  ScoreRange(resultNo: 51, param: SkinParam.rughe, min: 0.0, max: 1.2, label: 'Assenti'),
  ScoreRange(resultNo: 52, param: SkinParam.rughe, min: 1.2, max: 2.4, label: 'Lievi'),
  ScoreRange(resultNo: 53, param: SkinParam.rughe, min: 2.4, max: 3.6, label: 'Moderate'),
  ScoreRange(resultNo: 54, param: SkinParam.rughe, min: 3.6, max: 6.6, label: 'Marcate'),
  ScoreRange(resultNo: 55, param: SkinParam.rughe, min: 6.6, max: 9.9, label: 'Profonde'),
  // Pigmentazione (type 6)
  ScoreRange(resultNo: 61, param: SkinParam.pigmentazione, min: 0.0, max: 1.6, label: 'Uniforme'),
  ScoreRange(resultNo: 62, param: SkinParam.pigmentazione, min: 1.6, max: 3.7, label: 'Lieve'),
  ScoreRange(resultNo: 63, param: SkinParam.pigmentazione, min: 3.7, max: 6.8, label: 'Moderata'),
  ScoreRange(resultNo: 64, param: SkinParam.pigmentazione, min: 6.8, max: 9.0, label: 'Marcata'),
  ScoreRange(resultNo: 65, param: SkinParam.pigmentazione, min: 9.0, max: 9.9, label: 'Intensa'),
  // Sensibilità (type 7)
  ScoreRange(resultNo: 71, param: SkinParam.sensibilita, min: 0.0, max: 1.6, label: 'Robusta'),
  ScoreRange(resultNo: 72, param: SkinParam.sensibilita, min: 1.6, max: 3.7, label: 'Normale'),
  ScoreRange(resultNo: 73, param: SkinParam.sensibilita, min: 3.7, max: 6.8, label: 'Sensibile'),
  ScoreRange(resultNo: 74, param: SkinParam.sensibilita, min: 6.8, max: 9.0, label: 'Molto sensibile'),
  ScoreRange(resultNo: 75, param: SkinParam.sensibilita, min: 9.0, max: 9.9, label: 'Ipersensibile'),
  // Pori (type 8)
  ScoreRange(resultNo: 81, param: SkinParam.pori, min: 0.0, max: 0.8, label: 'Minimi'),
  ScoreRange(resultNo: 82, param: SkinParam.pori, min: 0.8, max: 1.6, label: 'Piccoli'),
  ScoreRange(resultNo: 83, param: SkinParam.pori, min: 1.6, max: 2.7, label: 'Normali'),
  ScoreRange(resultNo: 84, param: SkinParam.pori, min: 2.7, max: 5.6, label: 'Allargati'),
  ScoreRange(resultNo: 85, param: SkinParam.pori, min: 5.6, max: 9.9, label: 'Molto allargati'),
];

/// Trova il range corretto per uno score
ScoreRange scoreRangeFor(SkinParam param, double score) {
  return kScoreRanges
      .where((r) => r.param == param && score >= r.min && score < r.max)
      .firstOrNull ??
      kScoreRanges.lastWhere((r) => r.param == param);
}
