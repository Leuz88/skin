// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';
import 'device_service.dart';

const int kVendorId = 0x0555;
const int kProductId = 0x0160;

const List<int> kLedOnCommand  = [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
const List<int> kLedOffCommand = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];

// ── HIDD_ATTRIBUTES ───────────────────────────────────────────────────────────
final class HIDD_ATTRIBUTES extends Struct {
  @Uint32() external int Size;
  @Uint16() external int VendorID;
  @Uint16() external int ProductID;
  @Uint16() external int VersionNumber;
}

typedef _GetHidGuidNative = Void Function(Pointer<GUID> hidGuid);
typedef _GetHidGuidDart   = void Function(Pointer<GUID> hidGuid);
typedef _GetAttributesNative = Int32 Function(IntPtr device, Pointer<HIDD_ATTRIBUTES> attrs);
typedef _GetAttributesDart   = int   Function(int device,   Pointer<HIDD_ATTRIBUTES> attrs);

class _HidDll {
  static final _lib = DynamicLibrary.open('hid.dll');
  static final getHidGuid   = _lib.lookupFunction<_GetHidGuidNative,   _GetHidGuidDart>  ('HidD_GetHidGuid');
  static final getAttributes = _lib.lookupFunction<_GetAttributesNative, _GetAttributesDart>('HidD_GetAttributes');
}

// ─────────────────────────────────────────────────────────────────────────────

class DeviceServiceWindows implements DeviceService {
  int _deviceHandle = INVALID_HANDLE_VALUE;
  bool _isOpen = false;

  @override
  bool get isOpen => _isOpen;

  // ── 0. Lista dispositivi (diagnostica) ───────────────────────────────────
  @override
  List<ConnectedDeviceInfo> listAllDevices() {
    final result = <ConnectedDeviceInfo>[];
    final hidGuid = calloc<GUID>();
    _HidDll.getHidGuid(hidGuid);

    final deviceInfoSet = SetupDiGetClassDevs(hidGuid, nullptr, NULL, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (deviceInfoSet == INVALID_HANDLE_VALUE) { calloc.free(hidGuid); return result; }

    final ifData = calloc<SP_DEVICE_INTERFACE_DATA>()..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
    int idx = 0;

    while (SetupDiEnumDeviceInterfaces(deviceInfoSet, nullptr, hidGuid, idx, ifData) != 0) {
      final reqSize = calloc<DWORD>();
      SetupDiGetDeviceInterfaceDetail(deviceInfoSet, ifData, nullptr, 0, reqSize, nullptr);
      final bufSize = reqSize.value;
      if (bufSize > 0) {
        final detail = calloc<Uint8>(bufSize) as Pointer<SP_DEVICE_INTERFACE_DETAIL_DATA_>;
        detail.cast<DWORD>().value = _is64bit ? 8 : 6;
        if (SetupDiGetDeviceInterfaceDetail(deviceInfoSet, ifData, detail, bufSize, nullptr, nullptr) != 0) {
          final path = (detail.cast<Uint8>() + 4).cast<Utf16>().toDartString();
          final pathPtr = path.toNativeUtf16();
          try {
            final h = CreateFile(pathPtr, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, NULL);
            if (h != INVALID_HANDLE_VALUE) {
              final attrs = calloc<HIDD_ATTRIBUTES>()..ref.Size = sizeOf<HIDD_ATTRIBUTES>();
              if (_HidDll.getAttributes(h, attrs) != 0) {
                result.add(ConnectedDeviceInfo(vendorId: attrs.ref.VendorID, productId: attrs.ref.ProductID, version: attrs.ref.VersionNumber, path: path));
              }
              calloc.free(attrs);
              CloseHandle(h);
            }
          } finally { calloc.free(pathPtr); }
        }
        calloc.free(detail);
      }
      calloc.free(reqSize);
      idx++;
    }

    calloc.free(ifData);
    SetupDiDestroyDeviceInfoList(deviceInfoSet);
    calloc.free(hidGuid);
    return result;
  }

  // ── 1. Trova e apre il dispositivo ────────────────────────────────────────
  @override
  bool findAndOpen() {
    _close();
    final hidGuid = calloc<GUID>();
    _HidDll.getHidGuid(hidGuid);

    final deviceInfoSet = SetupDiGetClassDevs(hidGuid, nullptr, NULL, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (deviceInfoSet == INVALID_HANDLE_VALUE) { calloc.free(hidGuid); return false; }

    final ifData = calloc<SP_DEVICE_INTERFACE_DATA>()..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
    int idx = 0;
    bool found = false;

    while (SetupDiEnumDeviceInterfaces(deviceInfoSet, nullptr, hidGuid, idx, ifData) != 0) {
      final reqSize = calloc<DWORD>();
      SetupDiGetDeviceInterfaceDetail(deviceInfoSet, ifData, nullptr, 0, reqSize, nullptr);
      final bufSize = reqSize.value;
      final detail = calloc<Uint8>(bufSize) as Pointer<SP_DEVICE_INTERFACE_DETAIL_DATA_>;
      detail.cast<DWORD>().value = _is64bit ? 8 : 6;

      if (SetupDiGetDeviceInterfaceDetail(deviceInfoSet, ifData, detail, bufSize, nullptr, nullptr) != 0) {
        final path = (detail.cast<Uint8>() + 4).cast<Utf16>().toDartString();
        final pathPtr = path.toNativeUtf16();
        try {
          final tmp = CreateFile(pathPtr, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, NULL);
          if (tmp != INVALID_HANDLE_VALUE) {
            final attrs = calloc<HIDD_ATTRIBUTES>()..ref.Size = sizeOf<HIDD_ATTRIBUTES>();
            if (_HidDll.getAttributes(tmp, attrs) != 0 &&
                attrs.ref.VendorID == kVendorId && attrs.ref.ProductID == kProductId) {
              found = true;
              _deviceHandle = CreateFile(pathPtr, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL);
              if (_deviceHandle == INVALID_HANDLE_VALUE) {
                _deviceHandle = CreateFile(pathPtr, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, NULL);
              }
              _isOpen = _deviceHandle != INVALID_HANDLE_VALUE;
            }
            calloc.free(attrs);
            CloseHandle(tmp);
          }
        } finally { calloc.free(pathPtr); }
      }

      calloc.free(detail);
      calloc.free(reqSize);
      if (found) break;
      idx++;
    }

    calloc.free(ifData);
    SetupDiDestroyDeviceInfoList(deviceInfoSet);
    calloc.free(hidGuid);
    return found && _isOpen;
  }

  // ── 2. Polling tasto fisico (non bloccante) ────────────────────────────────
  Pointer<OVERLAPPED>? _btnOverlapped;
  Pointer<Uint8>? _btnBuffer;
  bool _btnPending = false;

  @override
  bool pollButtonPress() {
    if (!_isOpen) return false;
    const reportSize = 65;
    if (!_btnPending) {
      _btnBuffer ??= calloc<Uint8>(reportSize);
      _btnOverlapped ??= calloc<OVERLAPPED>();
      _btnOverlapped!.ref.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
      ReadFile(_deviceHandle, _btnBuffer!, reportSize, nullptr, _btnOverlapped!);
      _btnPending = true;
      return false;
    }
    final bytesRead = calloc<DWORD>();
    final done = GetOverlappedResult(_deviceHandle, _btnOverlapped!, bytesRead, FALSE) != 0;
    calloc.free(bytesRead);
    if (done) {
      _btnPending = false;
      CloseHandle(_btnOverlapped!.ref.hEvent);
      calloc.free(_btnOverlapped!);
      calloc.free(_btnBuffer!);
      _btnOverlapped = null;
      _btnBuffer = null;
      return true;
    }
    return false;
  }

  // ── 3. LED on/off ─────────────────────────────────────────────────────────
  @override
  bool ledOn() => _writeReport(kLedOnCommand);

  @override
  bool ledOff() => _writeReport(kLedOffCommand);

  bool _writeReport(List<int> payload) {
    if (!_isOpen) return false;
    const size = 65;
    final buf = calloc<Uint8>(size);
    buf[0] = 0x00;
    for (int i = 0; i < payload.length && i < size - 1; i++) buf[1 + i] = payload[i];

    final ov = calloc<OVERLAPPED>();
    final ev = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    ov.ref.hEvent = ev;
    final written = calloc<DWORD>();
    bool ok = false;
    try {
      WriteFile(_deviceHandle, buf, size, written, ov);
      if (WaitForSingleObject(ev, 500) == WAIT_OBJECT_0) {
        GetOverlappedResult(_deviceHandle, ov, written, FALSE);
        ok = written.value > 0;
      }
    } finally {
      CloseHandle(ev);
      calloc.free(written);
      calloc.free(ov);
      calloc.free(buf);
    }
    debugPrint('[HID] writeReport ${payload.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')} ok=$ok');
    return ok;
  }

  // ── 4. Cleanup ────────────────────────────────────────────────────────────
  void _close() {
    if (_btnPending && _btnOverlapped != null) {
      CancelIo(_deviceHandle);
      _btnPending = false;
      CloseHandle(_btnOverlapped!.ref.hEvent);
      calloc.free(_btnOverlapped!);
      if (_btnBuffer != null) calloc.free(_btnBuffer!);
      _btnOverlapped = null;
      _btnBuffer = null;
    }
    if (_isOpen && _deviceHandle != INVALID_HANDLE_VALUE) {
      CloseHandle(_deviceHandle);
      _deviceHandle = INVALID_HANDLE_VALUE;
      _isOpen = false;
    }
  }

  @override
  void dispose() => _close();

  static bool get _is64bit => sizeOf<IntPtr>() == 8;
}
