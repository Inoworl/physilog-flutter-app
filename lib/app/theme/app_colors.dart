import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Deep Blue
  static const primary = Color(0xFF1565C0);
  static const primaryLight = Color(0xFF5E92F3);
  static const primaryDark = Color(0xFF003C8F);

  // Secondary - Teal
  static const secondary = Color(0xFF00897B);
  static const secondaryLight = Color(0xFF4DB6AC);
  static const secondaryDark = Color(0xFF005B4F);

  // Surface
  static const surface = Color(0xFFFAFAFA);
  static const surfaceDark = Color(0xFF121212);

  // Semantic
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF388E3C);
  static const warning = Color(0xFFF57C00);

  // Text
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textOnPrimary = Colors.white;

  // 計測UI専用カラー
  static const startColor = Color(0xFF2E7D32);
  static const endColor = Color(0xFFC62828);
  static const timerBg = Color(0xFF1A1A2E);
  static const timerText = Color(0xFF00E676);

  // 記録シート用
  static const tableHeader = Color(0xFFE3F2FD);
  static const tableStripe = Color(0xFFFAFAFA);
}

/// スペーシングシステム（4dpグリッドベース）
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}
