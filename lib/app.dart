// lib/app.dart
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đặc Sản Quê Hương POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // TODO: thay bằng go_router sau khi thêm các màn hình
      home: const LoginPage(),
    );
  }
}
