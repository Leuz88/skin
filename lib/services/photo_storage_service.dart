import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gestisce il salvataggio delle foto scattate durante le sessioni.
///
/// Struttura:
///   {appSupportDir}/SkinAnalyzerPro/photos/{patientId}/{sessionId}/{zoneKey}.jpg
class PhotoStorageService {
  PhotoStorageService._();
  static final PhotoStorageService instance = PhotoStorageService._();

  String? _baseDir;

  Future<String> get baseDir async {
    if (_baseDir != null) return _baseDir!;
    final appDir = await getApplicationSupportDirectory();
    _baseDir = p.join(appDir.path, 'SkinAnalyzerPro', 'photos');
    await Directory(_baseDir!).create(recursive: true);
    return _baseDir!;
  }

  /// Salva i byte JPEG per una foto e restituisce il path assoluto.
  Future<String> savePhoto({
    required String patientId,
    required String sessionId,
    required String zoneKey,
    required List<int> jpegBytes,
  }) async {
    final base = await baseDir;
    final dir = Directory(p.join(base, patientId, sessionId));
    await dir.create(recursive: true);
    final path = p.join(dir.path, '$zoneKey.jpg');
    await File(path).writeAsBytes(jpegBytes);
    debugPrint('[PHOTO] Saved: $path');
    return path;
  }

  /// Cancella tutte le foto di una sessione dal disco.
  Future<void> deleteSessionPhotos(String patientId, String sessionId) async {
    final base = await baseDir;
    final dir = Directory(p.join(base, patientId, sessionId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      debugPrint('[PHOTO] Deleted session dir: ${dir.path}');
    }
  }

  /// Cancella tutte le foto di un paziente dal disco.
  Future<void> deletePatientPhotos(String patientId) async {
    final base = await baseDir;
    final dir = Directory(p.join(base, patientId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      debugPrint('[PHOTO] Deleted patient dir: ${dir.path}');
    }
  }

  /// Restituisce il path atteso per una foto (senza verificare che esista).
  Future<String> photoPath(String patientId, String sessionId, String zoneKey) async {
    final base = await baseDir;
    return p.join(base, patientId, sessionId, '$zoneKey.jpg');
  }
}
