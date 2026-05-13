import 'package:flutter/foundation.dart';
import '../models/patient.dart';

class PatientProvider extends ChangeNotifier {
  final List<Patient> _patients = [
    // Demo patients
    Patient(
      id: 'demo-001',
      name: 'Maria Rossi',
      sex: Sex.femmina,
      birthday: DateTime(1985, 3, 14),
      telephone: '333 1234567',
      email: 'maria.rossi@email.com',
    ),
    Patient(
      id: 'demo-002',
      name: 'Luca Bianchi',
      sex: Sex.maschio,
      birthday: DateTime(1978, 7, 22),
      telephone: '347 9876543',
    ),
  ];

  String _searchQuery = '';

  List<Patient> get patients {
    if (_searchQuery.isEmpty) return List.unmodifiable(_patients);
    final q = _searchQuery.toLowerCase();
    return _patients
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Patient? findById(String id) {
    try {
      return _patients.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void addPatient(Patient patient) {
    _patients.insert(0, patient);
    notifyListeners();
  }

  void updatePatient(Patient updated) {
    final idx = _patients.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _patients[idx] = updated;
      notifyListeners();
    }
  }

  void removePatient(String id) {
    _patients.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
