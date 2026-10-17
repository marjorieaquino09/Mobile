import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading(
    BuildContext context, {
    double size = 28,
    FontWeight weight = FontWeight.w700,
    double height = 1.15,
    double letterSpacing = -0.5,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: theme.colorScheme.onSurface,
    );
  }

  static TextStyle body(
    BuildContext context, {
    double size = 15,
    FontWeight weight = FontWeight.w400,
    double height = 1.4,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  static TextStyle button(
    BuildContext context, {
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: color ?? theme.colorScheme.onPrimary,
    );
  }

  static TextStyle caption(
    BuildContext context, {
    double size = 12,
    FontWeight weight = FontWeight.w500,
  }) {
    final theme = Theme.of(context);
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      color: theme.colorScheme.outline,
    );
  }
}

// Global helpers for auth & common text styling
TextStyle authHeadingStyle({Color? color, double size = 30}) {
  return GoogleFonts.outfit(
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.6,
    color: color,
  );
}

TextStyle authBodyStyle({Color? color, double size = 15}) {
  return GoogleFonts.outfit(
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: color,
  );
}
