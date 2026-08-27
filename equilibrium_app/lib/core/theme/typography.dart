import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EqTypography {
  static TextTheme getTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1.0),
      displayMedium: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displaySmall: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      
      headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
      
      titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
      
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );
  }
}
