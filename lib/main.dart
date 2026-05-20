// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/printing/thermal_printer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(ThermalPrinterService.instance.warmup());
  runApp(const PosApp());
}

// ignore: depend_on_referenced_packages
void unawaited(Future<void> future) {
  future.ignore();
}
