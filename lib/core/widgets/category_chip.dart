import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final sari = context.sari;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? sari.accentAmber : sari.fieldFill,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected
                  ? sari.accentAmber
                  : theme.brightness == Brightness.dark
                      ? sari.cardBorder
                      : sari.cardBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: selected ? sari.onAccentAmber : sari.bodyText,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
