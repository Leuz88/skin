import 'package:flutter/foundation.dart';
import '../models/scan_result.dart';
import '../providers/device_provider.dart';

class ScanProvider extends ChangeNotifier {
  final List<SkinResult> _results = [];
  SkinResult? _currentResult;
  String? _selectedPatientId;

  List<SkinResult> get results => List.unmodifiable(_results);
  SkinResult? get currentResult => _currentResult;
  String? get selectedPatientId => _selectedPatientId;

  List<SkinResult> resultsFor(String patientId) =>
      _results.where((r) => r.patientId == patientId).toList()
        ..sort((a, b) => b.measDate.compareTo(a.measDate));

  void updateDevice(DeviceProvider device) {
    device.onScanComplete = _onScanData;
  }

  void selectPatient(String id) {
    _selectedPatientId = id;
    notifyListeners();
  }

  void _onScanData(List<double> scores) {
    if (_selectedPatientId == null) return;
    final resultNos = List.generate(
      8,
      (i) {
        final param = SkinParam.values[i];
        final score = scores[i];
        return scoreRangeFor(param, score).resultNo;
      },
    );
    final result = SkinResult(
      measDate: DateTime.now(),
      patientId: _selectedPatientId!,
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
