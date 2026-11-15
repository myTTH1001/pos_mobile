// lib/main.dart
import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/server_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.load();
  runApp(const PosApp());
}
