import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  // ────────────────────────────────────────────────────────────
  // Init
  // ────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Force open so the DB is ready before the first screen renders
    await instance.db;
    debugPrint('[DB] Database ready');
  }

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'SkinAnalyzerPro'));
    await dbDir.create(recursive: true);
    final dbPath = p.join(dbDir.path, 'skin_analyzer.db');
    debugPrint('[DB] Path: $dbPath');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        sex         INTEGER NOT NULL DEFAULT 2,
        birthday    TEXT,
        telephone   TEXT NOT NULL DEFAULT '',
        email       TEXT NOT NULL DEFAULT '',
        remark      TEXT NOT NULL DEFAULT '',
        created_at  TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id          TEXT PRIMARY KEY,
        patient_id  TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        with_makeup INTEGER NOT NULL DEFAULT 0,
        notes       TEXT NOT NULL DEFAULT '',
        status      TEXT NOT NULL DEFAULT 'acquiring',
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE session_photos (
        id           TEXT PRIMARY KEY,
        session_id   TEXT NOT NULL,
        zone_key     TEXT NOT NULL,
        file_path    TEXT NOT NULL,
        captured_at  TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE session_results (
        session_id   TEXT PRIMARY KEY,
        scores       TEXT NOT NULL,
        result_nos   TEXT NOT NULL,
        analyzed_at  TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_sessions_patient ON sessions(patient_id)');
    await db.execute('CREATE INDEX idx_photos_session ON session_photos(session_id)');
  }

  // ────────────────────────────────────────────────────────────
  // PATIENTS
  // ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPatients() async {
    final d = await db;
    return d.query('patients', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getPatient(String id) async {
    final d = await db;
    final rows = await d.query('patients', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insertPatient(Map<String, dynamic> map) async {
    final d = await db;
    await d.insert('patients', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePatient(Map<String, dynamic> map) async {
    final d = await db;
    await d.update('patients', map, where: 'id = ?', whereArgs: [map['id']]);
  }

  Future<void> deletePatient(String id) async {
    final d = await db;
    await d.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────────────────────────────────────────
  // SESSIONS
  // ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSessionsForPatient(String patientId) async {
    final d = await db;
    return d.query('sessions', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getSession(String id) async {
    final d = await db;
    final rows = await d.query('sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> insertSession(Map<String, dynamic> map) async {
    final d = await db;
    await d.insert('sessions', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSessionStatus(String id, String status) async {
    final d = await db;
    await d.update('sessions', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSession(String id) async {
    final d = await db;
    await d.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────────────────────────────────────────
  // SESSION PHOTOS
  // ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPhotosForSession(String sessionId) async {
    final d = await db;
    return d.query('session_photos', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'captured_at ASC');
  }

  Future<void> insertPhoto(Map<String, dynamic> map) async {
    final d = await db;
    await d.insert('session_photos', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePhoto(String id) async {
    final d = await db;
    await d.delete('session_photos', where: 'id = ?', whereArgs: [id]);
  }

  // ────────────────────────────────────────────────────────────
  // SESSION RESULTS
  // ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getResult(String sessionId) async {
    final d = await db;
    final rows = await d.query('session_results', where: 'session_id = ?', whereArgs: [sessionId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertResult(Map<String, dynamic> map) async {
    final d = await db;
    await d.insert('session_results', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Restituisce tutti i risultati completati con il patient_id del session owner.
  /// Ordinati per data analisi decrescente.
  Future<List<Map<String, dynamic>>> getAllCompletedResults() async {
    final d = await db;
    return d.rawQuery('''
      SELECT sr.session_id, sr.scores, sr.result_nos, sr.analyzed_at,
             s.patient_id
      FROM session_results sr
      JOIN sessions s ON s.id = sr.session_id
      WHERE s.status = 'complete'
      ORDER BY sr.analyzed_at DESC
    ''');
  }
}
