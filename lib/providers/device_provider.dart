import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/scan_result.dart';

enum DeviceStatus { disconnected, connected, scanning }

/// Messaggio inviato dall'isolate HID verso il main thread
class _HidMessage {
  final bool connected;
  final List<double>? scanData; // 8 scores se scan completato
  _HidMessage({required this.connected, this.scanData});
}

class DeviceProvider extends ChangeNotifier {
  DeviceStatus _status = DeviceStatus.disconnected;
  String _statusMessage = 'Analizzatore non collegato';
  bool _buttonPressed = false;
  Timer? _scanTimer;
  Timer? _pollTimer;

  // Simulated / real HID
  bool _simulationMode = true; // true finché non calibriamo i byte reali
  final _random = Random();

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
    if (_simulationMode) {
      // In simulation mode il dispositivo è sempre "connected"
      if (_status == DeviceStatus.disconnected) {
        _status = DeviceStatus.connected;
        _statusMessage = 'Analizzatore connesso [SIMULAZIONE]';
        notifyListeners();
      }
      return;
    }

    // ── Real HID check via win32 FFI (vedi hid_service.dart) ──
    // final found = await HidService.instance.findDevice();
    // if (found && _status == DeviceStatus.disconnected) {
    //   _status = DeviceStatus.connected;
    //   _statusMessage = 'Analizzatore connesso (VID:0AC8 PID:5678)';
    //   notifyListeners();
    //   _listenForButton();
    // } else if (!found && _status != DeviceStatus.disconnected) {
    //   _status = DeviceStatus.disconnected;
    //   _statusMessage = 'Analizzatore non collegato';
    //   notifyListeners();
    // }
  }

  // ─────────────────────────────────────────────
  // SCAN trigger (da tasto touch o da UI)
  // ─────────────────────────────────────────────
  void triggerScan() {
    if (_status != DeviceStatus.connected) return;
    _status = DeviceStatus.scanning;
    _statusMessage = 'Scansione in corso…';
    notifyListeners();

    // Simula un'acquisizione da 3 secondi
    _scanTimer = Timer(const Duration(seconds: 3), () {
      final data = _simulationMode
          ? _generateSimulatedData()
          : <double>[]; // verrà sostituito con dati reali HID
      _status = DeviceStatus.connected;
      _statusMessage = 'Analizzatore connesso';
      onScanComplete?.call(data);
      notifyListeners();
    });
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
    _scanTimer?.cancel();
    super.dispose();
  }
}
