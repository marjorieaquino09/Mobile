export '../../core/widgets/app_text_field.dart';
export '../../core/widgets/auth_wave_background.dart';
export '../../core/widgets/outlined_pill_button.dart';
export '../../core/widgets/primary_button.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/outlined_pill_button.dart';

TextStyle authHeadingStyle(BuildContext context, {double size = 30}) {
  return GoogleFonts.outfit(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.6,
  );
}

TextStyle authBodyStyle(BuildContext context, {double size = 15}) {
  return GoogleFonts.outfit(
    color: context.sari.mutedText,
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}

// Backward-compatible AuthTextField alias
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hintText: hintText,
      prefixIcon: prefixIcon,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
    );
  }
}

// Backward-compatible AuthButton alias
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.height = 54,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedPillButton(
        label: label,
        onPressed: onPressed,
        height: height,
      );
    }
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      height: height,
      isLoading: isLoading,
    );
  }
}
