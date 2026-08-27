import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle display = GoogleFonts.fraunces(
    fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.mistWhite,
  );
  static TextStyle heading = GoogleFonts.fraunces(
    fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.mistWhite,
  );
  static TextStyle body = GoogleFonts.manrope(
    fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.mistWhite,
  );
  static TextStyle label = GoogleFonts.manrope(
    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dawnAmber,
  );
  static TextStyle data = GoogleFonts.ibmPlexMono(
    fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.restLavender,
  );
}