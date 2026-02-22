import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // フォントファミリー定数
  static const _fontBody = 'NotoSansJP';
  static const _fontMono = 'RobotoMono';

  // 画面タイトル: 24sp Bold
  static const screenTitle = TextStyle(
    fontFamily: _fontBody,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  // セクション見出し: 18sp SemiBold
  static const sectionTitle = TextStyle(
    fontFamily: _fontBody,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // カード見出し: 16sp Medium
  static const cardTitle = TextStyle(
    fontFamily: _fontBody,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // 本文: 14sp Regular
  static const body = TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  // キャプション: 12sp Regular
  static const caption = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // タイム表示（大）: 48sp Bold RobotoMono
  static const timeDisplay = TextStyle(
    fontFamily: _fontMono,
    fontSize: 48,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
  );

  // タイム表示（中）: 24sp Bold RobotoMono
  static const timeDisplayMedium = TextStyle(
    fontFamily: _fontMono,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 1,
  );

  // タイム表示（小）: 16sp Medium RobotoMono
  static const timeDisplaySmall = TextStyle(
    fontFamily: _fontMono,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  // 精度表示（既存互換）
  static const accuracy = TextStyle(
    fontFamily: _fontMono,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Color(0xFF757575),
  );
}
