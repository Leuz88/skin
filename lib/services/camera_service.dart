import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CameraService extends ChangeNotifier {
  CameraService._();
  static final CameraService instance = CameraService._();

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _initializing = false;
  String? _error;

  bool get isInitialized => _controller?.value.isInitialized == true;
  bool get isInitializing => _initializing;
  CameraController? get controller => _controller;
  String? get error => _error;
  List<CameraDescription> get cameras => _cameras;

  // ──────────────────────────────────────────────────────
  // Inizializzazione: enumera le fotocamere e apre quella USB
  // ──────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initializing || isInitialized) return;
    _initializing = true;
    notifyListeners();

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'Nessuna fotocamera trovata';
        _initializing = false;
        notifyListeners();
        return;
      }

      debugPrint('=== CAMERAS FOUND (${_cameras.length}) ===');
      for (final c in _cameras) {
        debugPrint('  [${c.lensDirection.name}] ${c.name}');
      }

      // Preferisce la fotocamera esterna USB (analizzatore)
      final camera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.external,
        orElse: () => _cameras.first,
      );
      debugPrint('=== SELECTED CAMERA: ${camera.name} ===');

      await _openCamera(camera);
    } catch (e) {
      _error = 'Errore fotocamera: $e';
      debugPrint('CameraService init error: $e');
    }

    _initializing = false;
    notifyListeners();
  }

  Future<void> _openCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Impossibile aprire la fotocamera: $e';
      _controller = null;
      notifyListeners();
    }
  }

  /// Scambia fotocamera (utile se ce ne sono più di una)
  Future<void> selectCamera(int index) async {
    if (index < 0 || index >= _cameras.length) return;
    _initializing = true;
    notifyListeners();
    await _openCamera(_cameras[index]);
    _initializing = false;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────
  // Scatta una foto e restituisce i byte
  // ──────────────────────────────────────────────────────
  Future<Uint8List?> captureFrameBytes() async {
    if (!isInitialized) return null;
    try {
      final file = await _controller!.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('captureFrame error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────
  // Analisi immagine → 8 score 0.0–9.9
  // Mapping provvisorio basato su statistiche colore/texture.
  // Da sostituire con SkinDetector reale quando disponibile.
  // ──────────────────────────────────────────────────────
  Future<List<double>> analyzeImage(Uint8List bytes) async {
    return compute(_analyzeInIsolate, bytes);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// Gira in un isolate separato (non blocca la UI)
List<double> _analyzeInIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return List.filled(8, 5.0);

  // Campiona la regione centrale (dove c'è la pelle)
  final cx = image.width ~/ 2;
  final cy = image.height ~/ 2;
  final radius = (image.width * 0.25).round();

  double sumR = 0, sumG = 0, sumB = 0;
  double sumEdge = 0;
  int count = 0;
  int prevGray = -1;

  for (int y = cy - radius; y < cy + radius; y += 3) {
    for (int x = cx - radius; x < cx + radius; x += 3) {
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
      final p = image.getPixel(x, y);
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final gray = (0.299 * r + 0.587 * g + 0.114 * b);

      sumR += r;
      sumG += g;
      sumB += b;
      if (prevGray >= 0) sumEdge += (gray - prevGray).abs();
      prevGray = gray.toInt();
      count++;
    }
  }

  if (count == 0) return List.filled(8, 5.0);

  final avgR = sumR / count / 255.0;
  final avgG = sumG / count / 255.0;
  final avgB = sumB / count / 255.0;
  final brightness = (avgR + avgG + avgB) / 3.0;
  final edge = (sumEdge / count / 255.0).clamp(0.0, 1.0);
  final redness = (avgR - (avgG + avgB) / 2).clamp(0.0, 1.0);
  final oiliness = (avgG * 1.1 + brightness * 0.4).clamp(0.0, 1.0);

  double s(double v) =>
      double.parse((v * 9.9).clamp(0.5, 9.9).toStringAsFixed(1));

  return [
    s(brightness * 1.1),      // Umidità    — pelle idratata riflette di più
    s(oiliness * 0.8),         // Olio/Sebo  — canale verde + luminosità
    s(1.0 - edge * 3),         // Texture    — meno bordi = texture più liscia
    s(avgR * 0.9),             // Collagene  — tono caldo
    s(edge * 5.0),             // Rughe      — densità bordi
    s(1.0 - redness * 4),      // Pigmentaz. — inversione arrossamento
    s(redness * 5.0),          // Sensibilità— rossore
    s(edge * 3.0),             // Pori       — microdettagli
  ];
}
