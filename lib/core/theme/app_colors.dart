import 'package:flutter/material.dart';

/// LumaCraft design system — centralized color palette.
/// Dark, cinematic theme with teal accent for a premium video editor feel.
class AppColors {
  AppColors._();

  // --- Surface & Background ---
  static const Color scaffoldDark = Color(0xFF0D0D0D);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color cardDark = Color(0xFF16213E);
  static const Color cardDarkAlt = Color(0xFF1B2838);

  // --- Accent ---
  static const Color accent = Color(0xFF00D4AA);
  static const Color accentLight = Color(0xFF33E8C0);
  static const Color accentDim = Color(0xFF007A63);

  // --- Semantic ---
  static const Color error = Color(0xFFFF4C6A);
  static const Color warning = Color(0xFFFFB347);
  static const Color success = Color(0xFF00D4AA);

  // --- Text ---
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // --- Misc ---
  static const Color divider = Color(0xFF2D3748);
  static const Color playerBg = Color(0xFF000000);

  // --- Gradient ---
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF00B4D8)],
  );
}
