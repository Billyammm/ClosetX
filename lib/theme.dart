import 'package:flutter/material.dart';

const ink = Color(0xFF26251F);
const muted = Color(0xFF77766E);
const paper = Color(0xFFF7F5F0);
const line = Color(0xFFEAE7DF);
const accent = Color(0xFFB46750);
const sage = Color(0xFFE6E9DF);

ThemeData buildClosetTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    surface: paper,
    primary: ink,
    secondary: accent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: sage,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) ? ink : muted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: accent, width: 1.4),
      ),
    ),
  );
}

TextStyle headingStyle(double size) => TextStyle(
  color: ink,
  fontSize: size,
  fontWeight: FontWeight.w700,
  height: 1.08,
  letterSpacing: -0.7,
);
