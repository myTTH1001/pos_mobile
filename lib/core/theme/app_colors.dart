// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF1A56DB); // blue
  static const primaryLight = Color(0xFFEBF2FF);
  static const primaryDark = Color(0xFF1342AD);

  // Accent
  static const accent = Color(0xFF0EA5E9);

  // Neutrals
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderFocus = Color(0xFF1A56DB);

  // Text
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFFCBD5E1);

  // Status
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Order status colors
  static const draft = Color(0xFF94A3B8);
  static const confirmed = Color(0xFF3B82F6);
  static const paid = Color(0xFF10B981);
  static const cancelled = Color(0xFFEF4444);
}
