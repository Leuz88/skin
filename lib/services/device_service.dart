import 'dart:io';
import 'device_service_windows.dart';
import 'device_service_android.dart';

/// Interfaccia astratta per la comunicazione col dispositivo USB.
/// Windows → DeviceServiceWindows (Win32 FFI / HID)
/// Android → DeviceServiceAndroid (usb_serial — da implementare)
abstract class DeviceService {
  bool get isOpen;

  /// Cerca e apre il dispositivo con VID:0555 PID:0160.
  bool findAndOpen();

  /// Accende i LED dell'analizzatore.
  bool ledOn();

  /// Spegne i LED dell'analizzatore.
  bool ledOff();

  /// Controlla non-blocking se il tasto fisico è stato premuto.
  bool pollButtonPress();

  /// Lista tutti i dispositivi HID/USB connessi (diagnostica).
  List<ConnectedDeviceInfo> listAllDevices();

  void dispose();

  /// Factory: restituisce l'implementazione corretta per la piattaforma.
  static DeviceService create() {
    if (Platform.isWindows) return DeviceServiceWindows();
    if (Platform.isAndroid) return DeviceServiceAndroid();
    throw UnsupportedError('Piattaforma non supportata: ${Platform.operatingSystem}');
  }
}

/// Info diagnostica di un dispositivo connesso.
class ConnectedDeviceInfo {
  final int vendorId;
  final int productId;
  final int version;
  final String path;

  const ConnectedDeviceInfo({
    required this.vendorId,
    required this.productId,
    required this.version,
    required this.path,
  });

  @override
  String toString() =>
      'VID:${vendorId.toRadixString(16).padLeft(4, '0').toUpperCase()} '
      'PID:${productId.toRadixString(16).padLeft(4, '0').toUpperCase()} '
      'v${version.toRadixString(16)} '
      '→ $path';
}
