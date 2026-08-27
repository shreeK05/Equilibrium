import 'package:flutter/material.dart';

class EqTokens {
  // Spacing
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // Radii
  static const double radius4 = 4.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius24 = 24.0;

  static const Radius circularRadius4 = Radius.circular(radius4);
  static const Radius circularRadius8 = Radius.circular(radius8);
  static const Radius circularRadius12 = Radius.circular(radius12);
  static const Radius circularRadius16 = Radius.circular(radius16);

  static const BorderRadius border4 = BorderRadius.all(circularRadius4);
  static const BorderRadius border8 = BorderRadius.all(circularRadius8);
  static const BorderRadius border12 = BorderRadius.all(circularRadius12);
  static const BorderRadius border16 = BorderRadius.all(circularRadius16);

  // Animations
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);
}
