import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/device_service.dart';
import '../services/camera_service.dart';

enum DeviceStatus { disconnected, connected, scanning }

class DeviceProvider extends ChangeNotifier {
  DeviceStatus _status = DeviceStatus.disconnected;
  String _statusMessage = 'Analizzatore non collegato';
  Timer? _scanTimer;
  Timer? _pollTimer;
  Timer? _buttonTimer;

  final _random = Random();
  Set<String> _knownDevicePaths = {};

  final DeviceService _device = DeviceService.create();

  DeviceStatus get status => _status;
  String get statusMessage => _statusMessage;
  bool get isConnected => _status != DeviceStatus.disconnected;
  bool get isScanning => _status == DeviceStatus.scanning;

  Function(List<double>)? onScanComplete;

  DeviceProvider() {
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkDevice();
    });
  }

  Future<void> _checkDevice() async {
    if (_status == DeviceStatus.scanning) return;

    final devices = _device.listAllDevices();
    final currentPaths = devices.map((d) => d.path).toSet();
    final added   = currentPaths.difference(_knownDevicePaths);
    final removed = _knownDevicePaths.difference(currentPaths);

    for (final path in added)   debugPrint('[DEV +ADDED]   ${devices.firstWhere((x) => x.path == path)}');
    for (final path in removed) debugPrint('[DEV -REMOVED] $path');
    if (_knownDevicePaths.isEmpty) {
      debugPrint('=== DEVICES BASELINE (${devices.length}) ===');
      for (final d in devices) debugPrint('  $d');
    }
    _knownDevicePaths = currentPaths;

    if (_status == DeviceStatus.disconnected) {
      if (_device.findAndOpen()) {
        _status = DeviceStatus.connected;
        _statusMessage = 'Analizzatore connesso (VID:0555 PID:0160)';
        notifyListeners();
        _startButtonPolling();
      }
    } else {
      if (!_device.isOpen) {
        _buttonTimer?.cancel();
        _status = DeviceStatus.disconnected;
        _statusMessage = 'Analizzatore non collegato';
        notifyListeners();
      }
    }
  }

  DateTime? _lastButtonPressTime;

  void _startButtonPolling() {
    _buttonTimer?.cancel();
    _lastButtonPressTime = null;
    _buttonTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (_status != DeviceStatus.connected) return;
      if (_device.pollButtonPress()) {
        final now = DateTime.now();
        if (_lastButtonPressTime == null ||
            now.difference(_lastButtonPressTime!) >
                const Duration(milliseconds: 1500)) {
          _lastButtonPressTime = now;
          debugPrint('[DEV] Tasto fisico premuto');
          onPhysicalButtonPressed?.call();
        } else {
          debugPrint('[DEV] Tasto ignorato (debounce)');
        }
      }
    });
  }

  /// Callback per il tasto fisico — usato dal ScanWizard
  Function()? onPhysicalButtonPressed;

  Future<void> triggerScanWithImage(Uint8List? imageBytes) async {
    if (_status != DeviceStatus.connected) return;
    _status = DeviceStatus.scanning;
    _statusMessage = 'Analisi in corsoâ€¦';
    notifyListeners();

    _device.ledOn();
    await Future.delayed(const Duration(milliseconds: 600));
    final capturedBytes = await CameraService.instance.captureFrameBytes();
    _device.ledOff();

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

  DeviceService get deviceService => _device;

  List<double> _generateSimulatedData() =>
      List.generate(8, (_) => double.parse(
          (1.5 + _random.nextDouble() * 7.0).clamp(0.1, 9.9).toStringAsFixed(1)));

  @override
  void dispose() {
    _pollTimer?.cancel();
    _buttonTimer?.cancel();
    _scanTimer?.cancel();
    _device.dispose();
    super.dispose();
  }
}
