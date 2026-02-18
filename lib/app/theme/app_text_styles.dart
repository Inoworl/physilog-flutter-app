import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // タイム表示用（モノスペース）
  static const timeDisplay = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 48,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
  );

  static const timeDisplaySmall = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
  );

  // 精度表示
  static const accuracy = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF757575),
  );
}
