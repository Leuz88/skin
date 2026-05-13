// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// VID e PID dell'analizzatore "Skin Observed System"
/// Identificato via diagnostica HID (appare solo quando collegato)
const int kVendorId = 0x0555;
const int kProductId = 0x0160;

/// Comandi output HID per i LED (da calibrare con USBPcap se necessario)
/// Molti analizzatori cinesi VID:0555 usano questo schema
const List<int> kLedOnCommand  = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
const List<int> kLedOffCommand = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];

// ── HIDD_ATTRIBUTES: non inclusa in win32 5.x, definita manualmente ─────────
final class HIDD_ATTRIBUTES extends Struct {
  @Uint32()
  external int Size;
  @Uint16()
  external int VendorID;
  @Uint16()
  external int ProductID;
  @Uint16()
  external int VersionNumber;
}

// ── Caricamento diretto di hid.dll ──────────────────────────────────────────
typedef _GetHidGuidNative = Void Function(Pointer<GUID> hidGuid);
typedef _GetHidGuidDart = void Function(Pointer<GUID> hidGuid);

typedef _GetAttributesNative = Int32 Function(
    IntPtr device, Pointer<HIDD_ATTRIBUTES> attrs);
typedef _GetAttributesDart = int Function(
    int device, Pointer<HIDD_ATTRIBUTES> attrs);

class _HidDll {
  static final _lib = DynamicLibrary.open('hid.dll');

  static final getHidGuid =
      _lib.lookupFunction<_GetHidGuidNative, _GetHidGuidDart>(
          'HidD_GetHidGuid');

  static final getAttributes =
      _lib.lookupFunction<_GetAttributesNative, _GetAttributesDart>(
          'HidD_GetAttributes');
}

/// Risultato di una singola lettura HID: 8 valori raw dall'analizzatore
class HidReadResult {
  final bool success;
  final List<int> rawBytes; // 64 bytes del report
  final String? error;

  HidReadResult({required this.success, this.rawBytes = const [], this.error});
}

/// Info diagnostica di un dispositivo HID trovato
class HidDeviceInfo {
  final int vendorId;
  final int productId;
  final int version;
  final String path;

  HidDeviceInfo({
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

/// Servizio HID che wrappa le Win32 API tramite il pacchetto win32.
/// Il parsing dei byte reali andrà calibrato collegando il dispositivo.
class HidService {
  HidService._();
  static final HidService instance = HidService._();

  int _deviceHandle = INVALID_HANDLE_VALUE;
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  // ──────────────────────────────────────────────────────
  // 0. Elenca tutti i dispositivi HID connessi (diagnostica)
  // ──────────────────────────────────────────────────────
  List<HidDeviceInfo> listAllDevices() {
    final result = <HidDeviceInfo>[];
    final hidGuid = calloc<GUID>();
    _HidDll.getHidGuid(hidGuid);

    final deviceInfoSet = SetupDiGetClassDevs(
      hidGuid,
      nullptr,
      NULL,
      DIGCF_PRESENT | DIGCF_DEVICEINTERFACE,
    );

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
      calloc.free(hidGuid);
      return result;
    }

    final deviceInterfaceData = calloc<SP_DEVICE_INTERFACE_DATA>()
      ..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
    int memberIndex = 0;

    while (SetupDiEnumDeviceInterfaces(
            deviceInfoSet, nullptr, hidGuid, memberIndex, deviceInterfaceData) !=
        0) {
      final requiredSize = calloc<DWORD>();
      SetupDiGetDeviceInterfaceDetail(
          deviceInfoSet, deviceInterfaceData, nullptr, 0, requiredSize, nullptr);

      final bufferSize = requiredSize.value;
      if (bufferSize > 0) {
        final detailData = calloc<Uint8>(bufferSize)
            as Pointer<SP_DEVICE_INTERFACE_DETAIL_DATA_>;
        detailData.cast<DWORD>().value = isProcess64Bit() ? 8 : 6;

        final ok = SetupDiGetDeviceInterfaceDetail(deviceInfoSet,
            deviceInterfaceData, detailData, bufferSize, nullptr, nullptr);
        if (ok != 0) {
          final devicePath =
              (detailData.cast<Uint8>() + 4).cast<Utf16>().toDartString();
          final pathPtr = devicePath.toNativeUtf16();
          try {
            final tempHandle = CreateFile(
              pathPtr,
              0,
              FILE_SHARE_READ | FILE_SHARE_WRITE,
              nullptr,
              OPEN_EXISTING,
              0,
              NULL,
            );
            if (tempHandle != INVALID_HANDLE_VALUE) {
              final attributes = calloc<HIDD_ATTRIBUTES>();
              attributes.ref.Size = sizeOf<HIDD_ATTRIBUTES>();
              if (_HidDll.getAttributes(tempHandle, attributes) != 0) {
                result.add(HidDeviceInfo(
                  vendorId: attributes.ref.VendorID,
                  productId: attributes.ref.ProductID,
                  version: attributes.ref.VersionNumber,
                  path: devicePath,
                ));
              }
              calloc.free(attributes);
              CloseHandle(tempHandle);
            }
          } finally {
            calloc.free(pathPtr);
          }
        }
        calloc.free(detailData);
      }
      calloc.free(requiredSize);
      memberIndex++;
    }

    calloc.free(deviceInterfaceData);
    SetupDiDestroyDeviceInfoList(deviceInfoSet);
    calloc.free(hidGuid);
    return result;
  }

  // ──────────────────────────────────────────────────────
  // 1. Trova il dispositivo HID con VID/PID corretti
  // ──────────────────────────────────────────────────────
  bool findAndOpen() {
    _close();

    final hidGuid = calloc<GUID>();
    _HidDll.getHidGuid(hidGuid);

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
        final pathPtr = devicePath.toNativeUtf16();

        try {
          // Apri temporaneamente per leggere attributi
          final tempHandle = CreateFile(
            pathPtr,
            0, // no access — solo attributi
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            nullptr,
            OPEN_EXISTING,
            0,
            NULL,
          );

          if (tempHandle != INVALID_HANDLE_VALUE) {
            final attributes = calloc<HIDD_ATTRIBUTES>();
            attributes.ref.Size = sizeOf<HIDD_ATTRIBUTES>();

            if (_HidDll.getAttributes(tempHandle, attributes) != 0) {
              if (attributes.ref.VendorID == kVendorId &&
                  attributes.ref.ProductID == kProductId) {
                found = true;
                // Prima prova accesso completo, poi fallback read-only
                _deviceHandle = CreateFile(
                  pathPtr,
                  GENERIC_READ | GENERIC_WRITE,
                  FILE_SHARE_READ | FILE_SHARE_WRITE,
                  nullptr,
                  OPEN_EXISTING,
                  FILE_FLAG_OVERLAPPED,
                  NULL,
                );
                if (_deviceHandle == INVALID_HANDLE_VALUE) {
                  _deviceHandle = CreateFile(
                    pathPtr,
                    GENERIC_READ,
                    FILE_SHARE_READ | FILE_SHARE_WRITE,
                    nullptr,
                    OPEN_EXISTING,
                    FILE_FLAG_OVERLAPPED,
                    NULL,
                  );
                }
                _isOpen = _deviceHandle != INVALID_HANDLE_VALUE;
              }
            }
            calloc.free(attributes);
            CloseHandle(tempHandle);
          }
        } finally {
          calloc.free(pathPtr);
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
  // 2. Lettura non-bloccante del tasto fisico
  //    Usa I/O asincrono: emette il read e controlla subito
  //    se c'è già un risultato (bWait=FALSE).
  //    Chiamare a ogni tick di timer (es. 100ms).
  // ──────────────────────────────────────────────────────
  Pointer<OVERLAPPED>? _buttonOverlapped;
  Pointer<Uint8>? _buttonBuffer;
  bool _buttonReadPending = false;

  /// Avvia o controlla la lettura del tasto fisico.
  /// Restituisce true se è stato ricevuto un report (tasto premuto).
  bool pollButtonPress() {
    if (!_isOpen) return false;

    const reportSize = 65;

    // Prima chiamata: alloca e avvia la lettura asincrona
    if (!_buttonReadPending) {
      _buttonBuffer ??= calloc<Uint8>(reportSize);
      _buttonOverlapped ??= calloc<OVERLAPPED>();
      final event = CreateEvent(nullptr, TRUE, FALSE, nullptr);
      _buttonOverlapped!.ref.hEvent = event;

      ReadFile(_deviceHandle, _buttonBuffer!, reportSize, nullptr,
          _buttonOverlapped!);
      _buttonReadPending = true;
      return false;
    }

    // Controlla se il risultato è disponibile (NON bloccante)
    final bytesRead = calloc<DWORD>();
    final hasResult = GetOverlappedResult(
            _deviceHandle, _buttonOverlapped!, bytesRead, FALSE) !=
        0;
    calloc.free(bytesRead);

    if (hasResult) {
      // Report ricevuto → resetta per il prossimo ciclo
      _buttonReadPending = false;
      CloseHandle(_buttonOverlapped!.ref.hEvent);
      calloc.free(_buttonOverlapped!);
      calloc.free(_buttonBuffer!);
      _buttonOverlapped = null;
      _buttonBuffer = null;
      return true;
    }
    return false;
  }

  // ──────────────────────────────────────────────────────
  // 3. Invia un output report HID al dispositivo
  //    Usato per accendere/spegnere i LED.
  //
  //    Il protocollo esatto è da calibrare con USBPcap/Wireshark.
  //    Comandi noti di molti analizzatori cinesi compatibili:
  //      LED_ON  = [0x00, 0x01, 0x00, 0x00, ...]
  //      LED_OFF = [0x00, 0x00, 0x00, 0x00, ...]
  //    Il primo byte è sempre il Report ID (0x00 se non usato).
  // ──────────────────────────────────────────────────────

  /// Accende i LED dell'analizzatore
  bool ledOn() => _sendOutputReport(kLedOnCommand);

  /// Spegne i LED dell'analizzatore
  bool ledOff() => _sendOutputReport(kLedOffCommand);

  bool _sendOutputReport(List<int> payload) {
    if (!_isOpen) return false;

    const reportSize = 65; // ReportID (1) + payload (64)
    final buffer = calloc<Uint8>(reportSize);

    // Riempie il buffer: primo byte = ReportID 0x00
    buffer[0] = 0x00;
    for (int i = 0; i < payload.length && i < reportSize - 1; i++) {
      buffer[1 + i] = payload[i];
    }

    final overlapped = calloc<OVERLAPPED>();
    final event = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    overlapped.ref.hEvent = event;
    final bytesWritten = calloc<DWORD>();

    bool success = false;
    try {
      WriteFile(_deviceHandle, buffer, reportSize, bytesWritten, overlapped);
      final waitResult = WaitForSingleObject(event, 500); // max 500ms
      if (waitResult == WAIT_OBJECT_0) {
        GetOverlappedResult(_deviceHandle, overlapped, bytesWritten, FALSE);
        success = bytesWritten.value > 0;
      }
    } finally {
      CloseHandle(event);
      calloc.free(bytesWritten);
      calloc.free(overlapped);
      calloc.free(buffer);
    }

    debugPrint('[HID] sendOutputReport ${payload.map((b) => '0x${b.toRadixString(16).padLeft(2,'0')}').join(' ')} → success=$success');
    return success;
  }

  // ──────────────────────────────────────────────────────
  // 4. Parse dei byte → 8 score 0.0–9.9 (non più usato
  //    per l'analisi principale, mantenuto per reference)
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
    // Cancella lettura button pendente
    if (_buttonReadPending && _buttonOverlapped != null) {
      CancelIo(_deviceHandle);
      _buttonReadPending = false;
      CloseHandle(_buttonOverlapped!.ref.hEvent);
      calloc.free(_buttonOverlapped!);
      if (_buttonBuffer != null) calloc.free(_buttonBuffer!);
      _buttonOverlapped = null;
      _buttonBuffer = null;
    }
    if (_isOpen && _deviceHandle != INVALID_HANDLE_VALUE) {
      CloseHandle(_deviceHandle);
      _deviceHandle = INVALID_HANDLE_VALUE;
      _isOpen = false;
    }
  }

  void dispose() => _close();

  static bool isProcess64Bit() => sizeOf<IntPtr>() == 8;
}
