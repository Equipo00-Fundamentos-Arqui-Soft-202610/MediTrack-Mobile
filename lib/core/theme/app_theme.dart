import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1565C0);
  static const Color accent = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFF42A5F5);
  static const Color blueSurface = Color(0xFFE3F2FD);
  static const Color stockAlert = Color(0xFFFF6F00);
  static const Color taken = Color(0xFF2E7D32);
  static const Color skipped = Color(0xFFC62828);
  static const Color textMain = Color(0xFF212121);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: textMain)),
  );
}
