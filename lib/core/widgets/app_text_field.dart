
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.hintText,
    this.labelText,
    this.controller,
    this.prefixIcon,
    this.obscureText = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.onChanged,
    this.maxLines = 1,
    this.focusNode,
  });

  final String hintText;
  final String? labelText;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType keyboardType;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.obscureText != widget.obscureText) {
      _isObscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;
    final hasToggle = widget.obscureText;

    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      enabled: widget.enabled,
      obscureText: hasToggle && _isObscured,
      maxLines: hasToggle ? 1 : widget.maxLines,
      onChanged: widget.onChanged,
      style: GoogleFonts.outfit(
        color: scheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: GoogleFonts.outfit(
          color: sari.faintText,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: sari.fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 17,
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(
                widget.prefixIcon,
                color: scheme.primary,
                size: 21,
              ),
        suffixIcon: hasToggle
            ? IconButton(
                tooltip: _isObscured
                    ? 'Show password'
                    : 'Hide password',
                onPressed: widget.enabled
                    ? () => setState(
                          () => _isObscured = !_isObscured,
                        )
                    : null,
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: scheme.primary,
                  size: 21,
                ),
              )
            : widget.suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
      ),
    );

    if (widget.labelText == null || widget.labelText!.isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.labelText!,
          style: GoogleFonts.outfit(
            color: sari.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}
