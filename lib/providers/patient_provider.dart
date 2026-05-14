import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import '../services/database_service.dart';
import '../services/photo_storage_service.dart';

class PatientProvider extends ChangeNotifier {
  final List<Patient> _patients = [];
  String _searchQuery = '';
  bool _loaded = false;

  List<Patient> get patients {
    final src = _loaded ? _patients : <Patient>[];
    if (_searchQuery.isEmpty) return List.unmodifiable(src);
    final q = _searchQuery.toLowerCase();
    return src.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  bool get loaded => _loaded;

  Future<void> loadFromDb() async {
    final rows = await DatabaseService.instance.getPatients();
    _patients
      ..clear()
      ..addAll(rows.map(Patient.fromMap));
    _loaded = true;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Patient? findById(String id) {
    try { return _patients.firstWhere((p) => p.id == id); }
    catch (_) { return null; }
  }

  Future<void> addPatient(Patient patient) async {
    await DatabaseService.instance.insertPatient(patient.toMap());
    _patients.insert(0, patient);
    notifyListeners();
  }

  Future<void> updatePatient(Patient updated) async {
    await DatabaseService.instance.updatePatient(updated.toMap());
    final idx = _patients.indexWhere((p) => p.id == updated.id);
    if (idx != -1) { _patients[idx] = updated; notifyListeners(); }
  }

  Future<void> removePatient(String id) async {
    await DatabaseService.instance.deletePatient(id);
    await PhotoStorageService.instance.deletePatientPhotos(id);
    _patients.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}

