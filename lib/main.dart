import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/device_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/patient_provider.dart';
import 'services/camera_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza SQLite (FFI per Windows/desktop)
  await DatabaseService.initialize();

  // Inizializza la fotocamera in background
  CameraService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()..loadFromDb()),
        ChangeNotifierProxyProvider<DeviceProvider, ScanProvider>(
          create: (ctx) => ScanProvider()..loadAllResults(),
          update: (ctx, device, scan) => scan!..updateDevice(device),
        ),
      ],
      child: const SkinAnalyzerApp(),
    ),
  );
}
