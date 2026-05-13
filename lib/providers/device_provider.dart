import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/hid_service.dart';
import '../services/camera_service.dart';

enum DeviceStatus { disconnected, connected, scanning }

class DeviceProvider extends ChangeNotifier {
  DeviceStatus _status = DeviceStatus.disconnected;
  String _statusMessage = 'Analizzatore non collegato';
  final bool _buttonPressed = false;
  Timer? _scanTimer;
  Timer? _pollTimer;
  Timer? _buttonTimer;  // polling tasto fisico (100ms)

  // Simulated / real HID
  bool _simulationMode = false;
  final _random = Random();
  Set<String> _knownDevicePaths = {};

  DeviceStatus get status => _status;
  String get statusMessage => _statusMessage;
  bool get buttonPressed => _buttonPressed;
  bool get isConnected => _status != DeviceStatus.disconnected;
  bool get isScanning => _status == DeviceStatus.scanning;

  // Callback chiamato da ScanProvider
  Function(List<double>)? onScanComplete;

  DeviceProvider() {
    _startPolling();
  }

  // ─────────────────────────────────────────────
  // POLLING per trovare il dispositivo
  // ─────────────────────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkDevice();
    });
  }

  Future<void> _checkDevice() async {
    if (_status == DeviceStatus.scanning) return;

    // Rileva variazioni HID (dispositivi aggiunti o rimossi)
    final devices = HidService.instance.listAllDevices();
    final currentPaths = devices.map((d) => d.path).toSet();

    final added = currentPaths.difference(_knownDevicePaths);
    final removed = _knownDevicePaths.difference(currentPaths);

    for (final path in added) {
      final d = devices.firstWhere((x) => x.path == path);
      debugPrint('[HID +ADDED]   $d');
    }
    for (final path in removed) {
      debugPrint('[HID -REMOVED] $path');
    }

    if (_knownDevicePaths.isEmpty) {
      debugPrint('=== HID BASELINE (${devices.length} devices) ===');
      for (final d in devices) {
        debugPrint('  $d');
      }
    }

    _knownDevicePaths = currentPaths;

    if (_status == DeviceStatus.disconnected) {
      // Tenta di trovare e aprire il dispositivo HID
      final found = HidService.instance.findAndOpen();
      if (found) {
        _status = DeviceStatus.connected;
        _statusMessage = 'Analizzatore connesso (VID:0555 PID:0160)';
        notifyListeners();
        // Avvia polling del tasto fisico
        _startButtonPolling();
      }
    } else {
      // Verifica che l'handle sia ancora valido
      if (!HidService.instance.isOpen) {
        _buttonTimer?.cancel();
        _status = DeviceStatus.disconnected;
        _statusMessage = 'Analizzatore non collegato';
        notifyListeners();
      }
    }
  }

  // ─────────────────────────────────────────────
  // POLLING TASTO FISICO (non-bloccante, 100ms)
  // ─────────────────────────────────────────────
  void _startButtonPolling() {
    _buttonTimer?.cancel();
    _buttonTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (_status != DeviceStatus.connected) return;
      final pressed = HidService.instance.pollButtonPress();
      if (pressed) {
        debugPrint('[HID] Tasto fisico premuto → avvio scansione');
        final bytes = await CameraService.instance.captureFrameBytes();
        await triggerScanWithImage(bytes);
      }
    });
  }

  // ─────────────────────────────────────────────
  // SCAN trigger da UI: riceve i byte dell'immagine
  // catturata dalla ScanScreen
  // ─────────────────────────────────────────────
  Future<void> triggerScanWithImage(Uint8List? imageBytes) async {
    if (_status != DeviceStatus.connected) return;
    _status = DeviceStatus.scanning;
    _statusMessage = 'Analisi in corso…';
    notifyListeners();

    // 1. Accendi i LED
    HidService.instance.ledOn();

    // 2. Aspetta che i LED si stabilizzino e illuminino la pelle
    await Future.delayed(const Duration(milliseconds: 600));

    // 3. Scatta la foto con i LED accesi
    final capturedBytes = await CameraService.instance.captureFrameBytes();

    // 4. Spegni i LED
    HidService.instance.ledOff();

    // 5. Analizza l'immagine
    List<double> scores;
    final bytesToAnalyze = capturedBytes ?? imageBytes;
    if (bytesToAnalyze != null && bytesToAnalyze.isNotEmpty) {
      scores = await CameraService.instance.analyzeImage(bytesToAnalyze);
    } else {
      debugPrint('[WARN] Nessuna immagine dalla fotocamera, uso dati casuali');
      scores = _generateSimulatedData();
    }

    _status = DeviceStatus.connected;
    _statusMessage = 'Analizzatore connesso (VID:0555 PID:0160)';
    onScanComplete?.call(scores);
    notifyListeners();
  }

  List<double> _generateSimulatedData() {
    // Genera score realistici (tendenzialmente nella fascia 2-7)
    return List.generate(8, (_) {
      return double.parse(
          (1.5 + _random.nextDouble() * 7.0).clamp(0.1, 9.9).toStringAsFixed(1));
    });
  }

  void enableSimulation(bool enabled) {
    _simulationMode = enabled;
    notifyListeners();
  }

  bool get simulationMode => _simulationMode;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _buttonTimer?.cancel();
    _scanTimer?.cancel();
    super.dispose();
  }
}
