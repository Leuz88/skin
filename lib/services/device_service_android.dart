import 'device_service.dart';

/// Stub Android — da implementare con il pacchetto usb_serial.
/// Tutte le operazioni sono no-op fino all'implementazione reale.
class DeviceServiceAndroid implements DeviceService {
  @override
  bool get isOpen => false;

  @override
  bool findAndOpen() => false;

  @override
  bool ledOn() => false;

  @override
  bool ledOff() => false;

  @override
  bool pollButtonPress() => false;

  @override
  List<ConnectedDeviceInfo> listAllDevices() => [];

  @override
  void dispose() {}
}
