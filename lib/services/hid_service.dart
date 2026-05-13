// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// VID e PID dell'analizzatore "Skin Observed System"
const int kVendorId = 0x0AC8;   // Z-Star Microelectronics
const int kProductId = 0x5678;

/// Risultato di una singola lettura HID: 8 valori raw dall'analizzatore
class HidReadResult {
  final bool success;
  final List<int> rawBytes; // 64 bytes del report
  final String? error;

  HidReadResult({required this.success, this.rawBytes = const [], this.error});
}

/// Servizio HID che wrappa le Win32 API tramite il pacchetto win32.
/// Il parsing dei byte reali andrà calibrato collegando il dispositivo.
class HidService {
  HidService._();
  static final HidService instance = HidService._();

  int _deviceHandle = INVALID_HANDLE_VALUE;
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  // ──────────────────────────────────────────────────────
  // 1. Trova il dispositivo HID con VID/PID corretti
  // ──────────────────────────────────────────────────────
  bool findAndOpen() {
    _close();

    final hidGuid = calloc<GUID>();
    HidD_GetHidGuid(hidGuid);

    // Ottieni handle al set di dispositivi HID attivi
    final deviceInfoSet = SetupDiGetClassDevs(
      hidGuid,
      nullptr,
      NULL,
      DIGCF_PRESENT | DIGCF_DEVICEINTERFACE,
    );

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
      calloc.free(hidGuid);
      return false;
    }

    final deviceInterfaceData = calloc<SP_DEVICE_INTERFACE_DATA>()
      ..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();

    int memberIndex = 0;
    bool found = false;

    while (SetupDiEnumDeviceInterfaces(
          deviceInfoSet,
          nullptr,
          hidGuid,
          memberIndex,
          deviceInterfaceData) !=
        0) {
      // Prima chiamata: ottieni dimensione richiesta
      final requiredSize = calloc<DWORD>();
      SetupDiGetDeviceInterfaceDetail(
          deviceInfoSet, deviceInterfaceData, nullptr, 0, requiredSize, nullptr);

      final bufferSize = requiredSize.value;
      final detailData =
          calloc<Uint8>(bufferSize) as Pointer<SP_DEVICE_INTERFACE_DETAIL_DATA_>;
      detailData.cast<DWORD>().value = isProcess64Bit() ? 8 : 6;

      final ok = SetupDiGetDeviceInterfaceDetail(deviceInfoSet,
          deviceInterfaceData, detailData, bufferSize, nullptr, nullptr);

      if (ok != 0) {
        // Estrai il path del device
        final devicePath = (detailData.cast<Uint8>() + 4)
            .cast<Utf16>()
            .toDartString();

        // Apri temporaneamente per leggere attributi
        final tempHandle = CreateFile(
          devicePath.toNativeUtf16(),
          0, // no access — solo attributi
          FILE_SHARE_READ | FILE_SHARE_WRITE,
          nullptr,
          OPEN_EXISTING,
          0,
          NULL,
        );

        if (tempHandle != INVALID_HANDLE_VALUE) {
          final attributes = calloc<HIDD_ATTRIBUTES>()
            ..ref.Size = sizeOf<HIDD_ATTRIBUTES>();

          if (HidD_GetAttributes(tempHandle, attributes) != 0) {
            if (attributes.ref.VendorID == kVendorId &&
                attributes.ref.ProductID == kProductId) {
              found = true;
              // Apri con accesso completo
              _deviceHandle = CreateFile(
                devicePath.toNativeUtf16(),
                GENERIC_READ | GENERIC_WRITE,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
                nullptr,
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                NULL,
              );
              _isOpen = _deviceHandle != INVALID_HANDLE_VALUE;
            }
          }
          calloc.free(attributes);
          CloseHandle(tempHandle);
        }
      }

      calloc.free(detailData);
      calloc.free(requiredSize);

      if (found) break;
      memberIndex++;
    }

    calloc.free(deviceInterfaceData);
    SetupDiDestroyDeviceInfoList(deviceInfoSet);
    calloc.free(hidGuid);

    return found && _isOpen;
  }

  // ──────────────────────────────────────────────────────
  // 2. Leggi un report HID (64 byte)
  // ──────────────────────────────────────────────────────
  HidReadResult readReport({int timeoutMs = 3000}) {
    if (!_isOpen) {
      return HidReadResult(success: false, error: 'Dispositivo non aperto');
    }

    const reportSize = 65; // 1 byte ReportID + 64 payload
    final buffer = calloc<Uint8>(reportSize);
    final bytesRead = calloc<DWORD>();
    final overlapped = calloc<OVERLAPPED>();
    final event = CreateEvent(nullptr, FALSE, FALSE, nullptr);
    overlapped.ref.hEvent = event;

    bool success = false;
    List<int> rawBytes = [];

    try {
      ReadFile(_deviceHandle, buffer, reportSize, bytesRead, overlapped);
      final waitResult = WaitForSingleObject(event, timeoutMs);

      if (waitResult == WAIT_OBJECT_0) {
        GetOverlappedResult(
            _deviceHandle, overlapped, bytesRead, FALSE);
        rawBytes = List.generate(
            bytesRead.value, (i) => buffer.elementAt(i).value);
        success = true;
      }
    } finally {
      CloseHandle(event);
      calloc.free(buffer);
      calloc.free(bytesRead);
      calloc.free(overlapped);
    }

    return HidReadResult(success: success, rawBytes: rawBytes);
  }

  // ──────────────────────────────────────────────────────
  // 3. Parse dei byte → 8 score 0.0–9.9
  //    NOTA: mappatura provvisoria, da calibrare
  //    con i byte reali del tuo analizzatore specifico.
  // ──────────────────────────────────────────────────────
  List<double> parseScores(List<int> rawBytes) {
    if (rawBytes.length < 17) return List.filled(8, 0.0);

    // Tentativo 1: bytes 1–8 = valori 0–255, scalati a 0.0–9.9
    return List.generate(8, (i) {
      final raw = rawBytes[1 + i];
      return double.parse(
          ((raw / 255.0) * 9.9).clamp(0.1, 9.9).toStringAsFixed(1));
    });
  }

  void _close() {
    if (_isOpen && _deviceHandle != INVALID_HANDLE_VALUE) {
      CloseHandle(_deviceHandle);
      _deviceHandle = INVALID_HANDLE_VALUE;
      _isOpen = false;
    }
  }

  void dispose() => _close();

  static bool isProcess64Bit() => sizeOf<IntPtr>() == 8;
}
