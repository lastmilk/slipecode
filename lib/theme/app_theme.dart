import 'package:flutter/material.dart';

/// 应用配色与主题。
class AppColors {
  static const accent = Color(0xFF7C6CFF);
  static const accentAlt = Color(0xFF4CC9F0);
  static const success = Color(0xFF46C2A4);
  static const warning = Color(0xFFF0B429);
  static const error = Color(0xFFFF6B81);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0D14),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F6FB),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
