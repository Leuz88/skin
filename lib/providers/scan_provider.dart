import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/scan_result.dart';
import '../models/scan_zone.dart';
import '../providers/device_provider.dart';
import '../services/database_service.dart';
import '../services/photo_storage_service.dart';

const _uuid = Uuid();

/// Foto di una singola zona già acquisita durante la sessione in corso.
class ZonePhoto {
  final String zoneKey;
  final String filePath;
  final DateTime capturedAt;
  const ZonePhoto({required this.zoneKey, required this.filePath, required this.capturedAt});
}

class ScanProvider extends ChangeNotifier {
  // ─── storico risultati ───────────────────────────────────────
  final List<SkinResult> _results = [];
  SkinResult? _currentResult;

  // ─── sessione wizard in corso ────────────────────────────────
  String? _currentSessionId;
  String? _wizardPatientId;
  Set<SkinParam> _selectedParams = {};
  List<ScanZone> _pendingZones = [];
  int _currentZoneIndex = 0;
  final Map<String, ZonePhoto> _capturedPhotos = {};
  bool _wizardActive = false;

  // ─── getters ─────────────────────────────────────────────────
  List<SkinResult> get results => List.unmodifiable(_results);
  SkinResult? get currentResult => _currentResult;

  bool get wizardActive => _wizardActive;
  String? get wizardPatientId => _wizardPatientId;
  Set<SkinParam> get selectedParams => Set.unmodifiable(_selectedParams);
  List<ScanZone> get pendingZones => List.unmodifiable(_pendingZones);
  int get currentZoneIndex => _currentZoneIndex;
  ScanZone? get currentZone => _currentZoneIndex < _pendingZones.length ? _pendingZones[_currentZoneIndex] : null;
  Map<String, ZonePhoto> get capturedPhotos => Map.unmodifiable(_capturedPhotos);
  bool get allZonesDone => _pendingZones.isNotEmpty && _capturedPhotos.length >= _pendingZones.length;
  String? get currentSessionId => _currentSessionId;

  List<SkinResult> resultsFor(String patientId) =>
      _results.where((r) => r.patientId == patientId).toList()
        ..sort((a, b) => b.measDate.compareTo(a.measDate));

  // ─── carica storico dal DB ────────────────────────────────────
  Future<void> loadResultsForPatient(String patientId) async {
    final sessions = await DatabaseService.instance.getSessionsForPatient(patientId);
    for (final session in sessions) {
      if (session['status'] != 'complete') continue;
      final row = await DatabaseService.instance.getResult(session['id'] as String);
      if (row != null) {
        final result = SkinResult.fromMap(row, patientId: patientId);
        if (!_results.any((r) => r.id == result.id)) _results.add(result);
      }
    }
    notifyListeners();
  }

  /// Carica TUTTI i risultati completati dal DB (chiamato all'avvio).
  Future<void> loadAllResults() async {
    final rows = await DatabaseService.instance.getAllCompletedResults();
    for (final row in rows) {
      final patientId = row['patient_id'] as String;
      final result = SkinResult.fromMap(row, patientId: patientId);
      if (!_results.any((r) => r.id == result.id)) _results.add(result);
    }
    notifyListeners();
  }

  // ─── collegamento con DeviceProvider ─────────────────────────
  void updateDevice(DeviceProvider device) {
    device.onScanComplete = _onScanData;
  }

  // ─── WIZARD ──────────────────────────────────────────────────
  Future<void> startWizard({required String patientId}) async {
    _currentSessionId = _uuid.v4();
    _wizardPatientId = patientId;
    _selectedParams = {};
    _pendingZones = [];
    _currentZoneIndex = 0;
    _capturedPhotos.clear();
    _wizardActive = true;

    await DatabaseService.instance.insertSession({
      'id': _currentSessionId,
      'patient_id': patientId,
      'created_at': DateTime.now().toIso8601String(),
      'status': 'acquiring',
    });

    notifyListeners();
  }

  void selectParams(Set<SkinParam> params) {
    _selectedParams = Set.from(params);
    _pendingZones = zonesForParams(_selectedParams);
    _currentZoneIndex = 0;
    notifyListeners();
  }

  /// Salva la foto della zona corrente e avanza alla successiva.
  Future<void> saveZonePhoto({required List<int> jpegBytes}) async {
    final zone = currentZone;
    if (zone == null || _wizardPatientId == null || _currentSessionId == null) return;

    final path = await PhotoStorageService.instance.savePhoto(
      patientId: _wizardPatientId!,
      sessionId: _currentSessionId!,
      zoneKey: zone.key,
      jpegBytes: jpegBytes,
    );

    await DatabaseService.instance.insertPhoto({
      'id': _uuid.v4(),
      'session_id': _currentSessionId,
      'zone_key': zone.key,
      'file_path': path,
      'captured_at': DateTime.now().toIso8601String(),
    });

    _capturedPhotos[zone.key] = ZonePhoto(zoneKey: zone.key, filePath: path, capturedAt: DateTime.now());
    if (_currentZoneIndex < _pendingZones.length - 1) _currentZoneIndex++;
    notifyListeners();
  }

  void goToZone(int index) {
    if (index >= 0 && index < _pendingZones.length) {
      _currentZoneIndex = index;
      notifyListeners();
    }
  }

  /// Finalizza la sessione con i risultati dell'analisi.
  Future<SkinResult?> finalizeSession(List<double> scores) async {
    if (_wizardPatientId == null || _currentSessionId == null) return null;

    final resultNos = List.generate(8, (i) {
      return scoreRangeFor(SkinParam.values[i], scores[i]).resultNo;
    });

    final result = SkinResult(
      id: _currentSessionId!,
      measDate: DateTime.now(),
      patientId: _wizardPatientId!,
      scores: scores,
      resultNos: resultNos,
    );

    await DatabaseService.instance.upsertResult(result.toMap());
    await DatabaseService.instance.updateSessionStatus(_currentSessionId!, 'complete');

    _results.insert(0, result);
    _currentResult = result;
    _wizardActive = false;
    notifyListeners();
    return result;
  }

  Future<void> cancelWizard() async {
    if (_currentSessionId != null) {
      await DatabaseService.instance.deleteSession(_currentSessionId!);
      if (_wizardPatientId != null) {
        await PhotoStorageService.instance.deleteSessionPhotos(_wizardPatientId!, _currentSessionId!);
      }
    }
    _wizardActive = false;
    _capturedPhotos.clear();
    notifyListeners();
  }

  // ─── callback da DeviceProvider (scan veloce senza wizard) ───
  void _onScanData(List<double> scores) {
    if (_wizardPatientId == null) return;
    final resultNos = List.generate(8, (i) {
      return scoreRangeFor(SkinParam.values[i], scores[i]).resultNo;
    });
    final result = SkinResult(
      measDate: DateTime.now(),
      patientId: _wizardPatientId!,
      scores: scores,
      resultNos: resultNos,
    );
    _results.insert(0, result);
    _currentResult = result;
    notifyListeners();
  }

  void clearCurrent() {
    _currentResult = null;
    notifyListeners();
  }
}

