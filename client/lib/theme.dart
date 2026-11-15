import 'package:flutter/material.dart';

class GH {
  static const bg = Color(0xFF0A0B10);
  static const bg2 = Color(0xFF11131A);
  static const panel = Color(0xFF161922);
  static const panel2 = Color(0xFF1C2029);
  static const line = Color(0xFF262B36);
  static const pink = Color(0xFFFF2E63);
  static const cyan = Color(0xFF00E5D0);
  static const gold = Color(0xFFFFC93C);
  static const text = Color(0xFFEDEFF5);
  static const muted = Color(0xFF8A90A0);
  static const green = Color(0xFF3EE08F);
  static const red = Color(0xFFFF5A5A);

  // Pixel-art tokens: ink = hard outline, hi/lo = bevel edges.
  static const ink = Color(0xFF05060A);
  static const hi = Color(0xFF343B49);
  static const lo = Color(0xFF0B0D13);
  static const pixelFont = 'monospace';

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: false);
    final textTheme = base.textTheme
        .apply(
          bodyColor: text,
          displayColor: text,
          fontFamily: pixelFont,
        )
        .copyWith(
          bodyLarge: const TextStyle(
              fontFamily: pixelFont,
              color: text,
              fontSize: 15,
              height: 1.45),
          bodyMedium: const TextStyle(
              fontFamily: pixelFont,
              color: text,
              fontSize: 13,
              height: 1.45),
          titleLarge: const TextStyle(
              fontFamily: pixelFont,
              color: text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2),
          labelLarge: const TextStyle(
              fontFamily: pixelFont,
              color: text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0),
        );
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: pink,
        secondary: cyan,
        surface: panel,
      ),
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: panel2,
        contentTextStyle: TextStyle(
            fontFamily: pixelFont, color: text, fontWeight: FontWeight.w700),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: ink, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: ink, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

TextStyle moneyStyle({double size = 20, Color color = GH.gold}) => TextStyle(
      fontFamily: GH.pixelFont,
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.3,
      height: 1.1,
    );

TextStyle labelStyle({double size = 12, Color color = GH.muted}) => TextStyle(
      fontFamily: GH.pixelFont,
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
