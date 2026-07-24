import 'package:flutter/material.dart';

/// Dark teal / blue-green sci-fi palette (Phase 0.2 UI direction).
abstract final class AppColors {
  static const Color backgroundDeep = Color(0xFF061416);
  static const Color backgroundMid = Color(0xFF0A2428);
  static const Color surface = Color(0xFF0F2F33);
  static const Color surfaceElevated = Color(0xFF143A3F);
  static const Color rail = Color(0xFF071A1C);
  static const Color outline = Color(0xFF24555A);
  static const Color primary = Color(0xFF2A9B9B);
  static const Color primaryBright = Color(0xFF3DBFBF);
  static const Color onSurface = Color(0xFFE2F1F1);
  static const Color onSurfaceMuted = Color(0xFF9BB8B8);
  static const Color danger = Color(0xFFE07A6A);
  static const Color warning = Color(0xFFD4A84B);

  /// Register row accents (used fully in Phase 3; tokens locked in 0.2).
  static const Color rowCleared = Color(0xFF1A3A32);
  static const Color rowUnclearedPast = Color(0xFF12282C);
  static const Color rowAutoFuture = Color(0xFF16384A);
  static const Color rowManualFuture = Color(0xFF3A2E16);
}
