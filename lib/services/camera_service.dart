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

  /// ValueListenable per osservare lo stato inizializzazione senza rebuild globali.
  final ValueNotifier<bool> isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isInitializingNotifier = ValueNotifier(false);
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  // ──────────────────────────────────────────────────────
  // Inizializzazione: enumera le fotocamere e apre quella USB
  // ──────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initializing || isInitialized) return;
    _initializing = true;
    isInitializingNotifier.value = true;
    errorNotifier.value = null;
    notifyListeners();

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'Nessuna fotocamera trovata';
        _initializing = false;
        isInitializingNotifier.value = false;
        errorNotifier.value = _error;
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
    isInitializingNotifier.value = false;
    isInitializedNotifier.value = isInitialized;
    if (_error != null) errorNotifier.value = _error;
    notifyListeners();
  }

  /// Forza re-inizializzazione (utile dopo un fallimento o per cambiare camera).
  Future<void> reinitialize() async {
    await _controller?.dispose();
    _controller = null;
    _error = null;
    _initializing = false;
    isInitializedNotifier.value = false;
    isInitializingNotifier.value = false;
    errorNotifier.value = null;
    notifyListeners();
    await initialize();
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
      isInitializedNotifier.value = true;
      notifyListeners();
    } catch (e) {
      _error = 'Impossibile aprire la fotocamera: $e';
      _controller = null;
      isInitializedNotifier.value = false;
      notifyListeners();
    }
  }

  /// Scambia fotocamera (utile se ce ne sono più di una)
  Future<void> selectCamera(int index) async {
    if (index < 0 || index >= _cameras.length) return;
    _initializing = true;
    isInitializingNotifier.value = true;
    errorNotifier.value = null;
    isInitializedNotifier.value = false;
    notifyListeners();
    await _openCamera(_cameras[index]);
    _initializing = false;
    isInitializingNotifier.value = false;
    if (_error != null) errorNotifier.value = _error;
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

// Gira in un isolate separato (non blocca la UI).
// Algoritmo basato su analisi colorimetrica e morfologica dell'immagine cutanea.
List<double> _analyzeInIsolate(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return List.filled(8, 5.0);

  final w = image.width;
  final h = image.height;

  // Campiona la regione centrale (50% dell'immagine) dove c'è la pelle
  final x0 = w ~/ 4;
  final y0 = h ~/ 4;
  final x1 = w * 3 ~/ 4;
  final y1 = h * 3 ~/ 4;

  double sumR = 0, sumG = 0, sumB = 0, sumGray = 0;
  double sumEdge = 0;
  int shinyPixels = 0; // pixel > 220 brightness → riflesso sebacea
  int darkPixels = 0;  // pixel < 55 brightness  → pori visibili
  int strongEdgePixels = 0; // gradiente > 18 → rughe/irregolarità marcate
  int count = 0;
  final grayList = <double>[];

  // Prima passata: statistiche colore
  for (int y = y0; y < y1; y += 2) {
    for (int x = x0; x < x1; x += 2) {
      final p = image.getPixel(x, y);
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final gray = 0.299 * r + 0.587 * g + 0.114 * b;
      sumR += r;
      sumG += g;
      sumB += b;
      sumGray += gray;
      grayList.add(gray);
      if (gray > 220) shinyPixels++;
      if (gray < 55 && r < 70) darkPixels++;
      count++;
    }
  }

  if (count == 0) return List.filled(8, 5.0);

  // Seconda passata: rilevamento bordi (gradiente semplice)
  for (int y = y0 + 1; y < y1 - 1; y += 2) {
    for (int x = x0 + 1; x < x1 - 1; x += 2) {
      final p00 = image.getPixel(x, y);
      final p10 = image.getPixel(x + 1, y);
      final p01 = image.getPixel(x, y + 1);
      final g00 = 0.299 * p00.r + 0.587 * p00.g + 0.114 * p00.b;
      final g10 = 0.299 * p10.r + 0.587 * p10.g + 0.114 * p10.b;
      final g01 = 0.299 * p01.r + 0.587 * p01.g + 0.114 * p01.b;
      final mag = ((g10 - g00).abs() + (g01 - g00).abs()) / 2.0;
      sumEdge += mag;
      if (mag > 18) strongEdgePixels++;
    }
  }

  final avgR = sumR / count;
  final avgG = sumG / count;
  final avgB = sumB / count;
  final avgGray = sumGray / count; // 0–255

  // Varianza della luminanza → pigmentazione / irregolarità cromatica
  double sumSq = 0;
  for (final v in grayList) sumSq += (v - avgGray) * (v - avgGray);
  final grayStdDev = (sumSq / grayList.length == 0)
      ? 0.0
      : (sumSq / grayList.length).abs() < 1e-9
          ? 0.0
          : (sumSq / grayList.length);
  final stdDev = grayStdDev < 0 ? 0.0 : grayStdDev < 1e9 ? grayStdDev : 0.0;
  // Safe sqrt
  final graySD = stdDev > 0 ? _sqrt(stdDev) : 0.0;

  final avgEdge = sumEdge / count;                   // magnitudine media bordi
  final shinyRatio = shinyPixels / count;            // 0–1: riflesso (sebo)
  final darkRatio = darkPixels / count;              // 0–1: punti scuri (pori)
  final strongEdgeRatio = strongEdgePixels / count;  // 0–1: bordi marcati (rughe)

  // Indice di rossore: eccesso del rosso rispetto a verde e blu
  final redness = (avgR - (avgG + avgB) / 2).clamp(0.0, 255.0);

  // Perdita di calore cromatico (collagene): più la pelle è pallida/giallastra,
  // maggiore è la perdita. Warmth = (R-B)/(R+G+B). Collagene ridotto → basso warmth.
  final warmthDenom = avgR + avgG + avgB;
  final warmth = warmthDenom > 1 ? (avgR - avgB) / warmthDenom : 0.0; // -0.33..+0.33
  final collageLoss = (0.33 - warmth).clamp(0.0, 0.66); // 0=ottimo, 0.66=pessimo

  // ── Normalizzazione 0.0–9.9 ─────────────────────────────────────
  double norm(double v, double lo, double hi) =>
      ((v.clamp(lo, hi) - lo) / (hi - lo) * 9.9).clamp(0.0, 9.9);

  double s(double v) => double.parse(v.toStringAsFixed(1));

  return [
    s(norm(avgGray, 60.0, 210.0)),          // Umidità:       luminosità → idratazione
    s(norm(shinyRatio, 0.0, 0.18)),         // Olio:          riflessi speculari → sebo
    s(norm(avgEdge, 1.5, 22.0)),            // Texture:       densità bordi medi → rugosità
    s(norm(collageLoss, 0.05, 0.55)),       // Collagene:     perdita calore cromatico
    s(norm(strongEdgeRatio, 0.0, 0.28)),    // Rughe:         bordi forti → solchi profondi
    s(norm(graySD, 8.0, 55.0)),             // Pigmentazione: varianza lum. → macchie
    s(norm(redness, 3.0, 55.0)),            // Sensibilità:   eccesso rosso → eritema
    s(norm(darkRatio, 0.002, 0.07)),        // Pori:          punti scuri → pori dilatati
  ];
}

// Safe sqrt senza dart:math in isolate
double _sqrt(double x) {
  if (x <= 0) return 0.0;
  double r = x / 2;
  for (int i = 0; i < 20; i++) r = (r + x / r) / 2;
  return r;
}
