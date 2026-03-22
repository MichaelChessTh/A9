import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4285F4), // Google Blue
    primary: const Color(0xFF4285F4),
    secondary: const Color(0xFFEA4335), // Google Red
    tertiary: const Color(0xFFFBBC04), // Google Yellow
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF202124),
  ),
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
  scaffoldBackgroundColor: const Color(0xFFF8F9FA),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    iconTheme: const IconThemeData(color: Color(0xFF202124)),
    titleTextStyle: GoogleFonts.outfit(
      color: const Color(0xFF202124),
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  ),
);
