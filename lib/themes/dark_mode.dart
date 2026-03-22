import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4285F4),
    brightness: Brightness.dark,
    primary: const Color(0xFF4285F4), // Bright Blue
    secondary: const Color(0xFFEA4335), // Bright Red
    tertiary: const Color(0xFFFBBC04), // Bright Yellow
    surface: const Color(0xFF121417),
    onSurface: const Color(0xFFF8F9FA),
  ),
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
  scaffoldBackgroundColor: const Color(
    0xFF000000,
  ), // Exact black for OLED neon contrast
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: GoogleFonts.outfit(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: const Color(0xFF1A1D20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1A1D20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF333333), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF333333), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  ),
);
