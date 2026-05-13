import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/device_provider.dart';
import 'providers/scan_provider.dart';
import 'providers/patient_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProxyProvider<DeviceProvider, ScanProvider>(
          create: (ctx) => ScanProvider(),
          update: (ctx, device, scan) => scan!..updateDevice(device),
        ),
      ],
      child: const SkinAnalyzerApp(),
    ),
  );
}
