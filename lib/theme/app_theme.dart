import 'package:flutter/material.dart';

/// Light and night themes. A calm green seed, as fits a book of hadith.
class AppTheme {
  static const _seed = Color(0xFF2E6B4F);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
    );
  }
}

/// Text style for the matn: large, with room between lines for tashkeel.
TextStyle matnStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge!.copyWith(height: 2.1, fontSize: 22);
