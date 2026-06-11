import 'package:flutter/material.dart';

/// Light + dark themes seeded from the fox orange. Letter/grid contrast is
/// carried by onSurface vs surfaceContainer tones in both modes.
abstract final class AppTheme {
  static const Color _seed = Color(0xFFE8762F);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
