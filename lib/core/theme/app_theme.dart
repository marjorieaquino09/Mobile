import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Semantic custom tokens that adapt across Light and Dark modes.
@immutable
class SariColors extends ThemeExtension<SariColors> {
  const SariColors({
    required this.screenGradient,
    required this.cardSurface,
    required this.cardSurfaceStrong,
    required this.cardBorder,
    required this.fieldFill,
    required this.mutedText,
    required this.faintText,
    required this.headingText,
    required this.bodyText,
    required this.accentAmber,
    required this.onAccentAmber,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.chartBar,
    required this.chartLabel,
    required this.navBarBackground,
    required this.navBarBorder,
    required this.navBarScanBg,
    required this.navBarScanFg,
    required this.onAccent,
    required this.imagePlaceholder,
    required this.shadow,
    required this.logoutBackground,
    required this.logoutForeground,
    required this.divider,
    required this.chipSelectedFg,
    required this.authCardSurface,
    required this.authFieldFill,
    required this.authHint,
    required this.authBorder,
    required this.glassBorder,
    required this.modalGradient,
    required this.brandBackdrop,
    required this.authAccent,
    required this.authOnAccent,
    required this.authText,
    required this.authMuted,
    required this.waveDark,
    required this.waveLight,
  });

  final LinearGradient screenGradient;
  final Color cardSurface;
  final Color cardSurfaceStrong;
  final Color cardBorder;
  final Color fieldFill;
  final Color mutedText;
  final Color faintText;
  final Color headingText;
  final Color bodyText;
  final Color accentAmber;
  final Color onAccentAmber;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color chartBar;
  final Color chartLabel;
  final Color navBarBackground;
  final Color navBarBorder;
  final Color navBarScanBg;
  final Color navBarScanFg;
  final Color onAccent;
  final Color imagePlaceholder;
  final Color shadow;
  final Color logoutBackground;
  final Color logoutForeground;
  final Color divider;
  final Color chipSelectedFg;
  final Color authCardSurface;
  final Color authFieldFill;
  final Color authHint;
  final Color authBorder;
  final Color glassBorder;
  final LinearGradient modalGradient;
  final Color brandBackdrop;
  final Color authAccent;
  final Color authOnAccent;
  final Color authText;
  final Color authMuted;
  final Color waveDark;
  final Color waveLight;

  static final SariColors light = SariColors(
    screenGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.lightBackground, Color(0xFFF7F6EC)],
    ),
    cardSurface: AppColors.lightCard,
    cardSurfaceStrong: AppColors.lightCard,
    cardBorder: AppColors.lightBorder,
    fieldFill: AppColors.lightInputFill,
    mutedText: AppColors.lightMuted,
    faintText: AppColors.lightFaint,
    headingText: AppColors.lightHeading,
    bodyText: AppColors.lightBody,
    accentAmber: AppColors.accentAmber,
    onAccentAmber: AppColors.onAccentAmber,
    success: AppColors.lightPrimary,
    warning: AppColors.accentAmber,
    danger: AppColors.lightError,
    info: const Color(0xFF4A7C9B),
    chartBar: AppColors.lightPrimary,
    chartLabel: AppColors.lightMuted,
    navBarBackground: AppColors.lightCard,
    navBarBorder: AppColors.lightBorder,
    navBarScanBg: AppColors.lightPrimary,
    navBarScanFg: AppColors.lightOnPrimary,
    onAccent: AppColors.lightOnPrimary,
    imagePlaceholder: AppColors.pureWhite,
    shadow: Colors.black.withValues(alpha: 0.06),
    logoutBackground: const Color(0xFFFDF0ED),
    logoutForeground: AppColors.lightError,
    divider: AppColors.lightBorder,
    chipSelectedFg: AppColors.onAccentAmber,
    authCardSurface: AppColors.lightCard,
    authFieldFill: AppColors.lightInputFill,
    authHint: AppColors.lightFaint,
    authBorder: AppColors.lightBorder,
    glassBorder: AppColors.lightBorder,
    modalGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.lightCard, AppColors.lightBackground],
    ),
    brandBackdrop: AppColors.lightBackground,
    authAccent: AppColors.lightPrimary,
    authOnAccent: AppColors.lightOnPrimary,
    authText: AppColors.lightHeading,
    authMuted: AppColors.lightMuted,
    waveDark: AppColors.lightWaveDark,
    waveLight: AppColors.lightWaveLight.withValues(alpha: 0.35),
  );

  static final SariColors dark = SariColors(
    screenGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.darkBackground, Color(0xFF132A23)],
    ),
    cardSurface: AppColors.darkCard,
    cardSurfaceStrong: AppColors.darkCard,
    cardBorder: AppColors.darkBorder,
    fieldFill: AppColors.darkInputFill,
    mutedText: AppColors.darkMuted,
    faintText: AppColors.darkFaint,
    headingText: AppColors.darkHeading,
    bodyText: AppColors.darkBody,
    accentAmber: AppColors.accentAmber,
    onAccentAmber: AppColors.onAccentAmber,
    success: AppColors.darkPrimary,
    warning: AppColors.accentAmber,
    danger: AppColors.darkError,
    info: const Color(0xFF88B8D6),
    chartBar: AppColors.darkPrimary,
    chartLabel: AppColors.darkMuted,
    navBarBackground: AppColors.darkCard,
    navBarBorder: AppColors.darkBorder,
    navBarScanBg: AppColors.darkPrimary,
    navBarScanFg: AppColors.darkOnPrimary,
    onAccent: AppColors.darkOnPrimary,
    imagePlaceholder: AppColors.pureWhite,
    shadow: Colors.black.withValues(alpha: 0.35),
    logoutBackground: const Color(0xFF381D1A),
    logoutForeground: AppColors.darkError,
    divider: AppColors.darkBorder,
    chipSelectedFg: AppColors.onAccentAmber,
    authCardSurface: AppColors.darkCard,
    authFieldFill: AppColors.darkInputFill,
    authHint: AppColors.darkFaint,
    authBorder: AppColors.darkBorder,
    glassBorder: AppColors.darkBorder,
    modalGradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [AppColors.darkCard, AppColors.darkBackground],
    ),
    brandBackdrop: AppColors.darkBackground,
    authAccent: AppColors.darkPrimary,
    authOnAccent: AppColors.darkOnPrimary,
    authText: AppColors.darkHeading,
    authMuted: AppColors.darkMuted,
    waveDark: AppColors.darkWaveDark,
    waveLight: AppColors.darkWaveLight.withValues(alpha: 0.25),
  );

  @override
  SariColors copyWith({
    LinearGradient? screenGradient,
    Color? cardSurface,
    Color? cardSurfaceStrong,
    Color? cardBorder,
    Color? fieldFill,
    Color? mutedText,
    Color? faintText,
    Color? headingText,
    Color? bodyText,
    Color? accentAmber,
    Color? onAccentAmber,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? chartBar,
    Color? chartLabel,
    Color? navBarBackground,
    Color? navBarBorder,
    Color? navBarScanBg,
    Color? navBarScanFg,
    Color? onAccent,
    Color? imagePlaceholder,
    Color? shadow,
    Color? logoutBackground,
    Color? logoutForeground,
    Color? divider,
    Color? chipSelectedFg,
    Color? authCardSurface,
    Color? authFieldFill,
    Color? authHint,
    Color? authBorder,
    Color? glassBorder,
    LinearGradient? modalGradient,
    Color? brandBackdrop,
    Color? authAccent,
    Color? authOnAccent,
    Color? authText,
    Color? authMuted,
    Color? waveDark,
    Color? waveLight,
  }) {
    return SariColors(
      screenGradient: screenGradient ?? this.screenGradient,
      cardSurface: cardSurface ?? this.cardSurface,
      cardSurfaceStrong: cardSurfaceStrong ?? this.cardSurfaceStrong,
      cardBorder: cardBorder ?? this.cardBorder,
      fieldFill: fieldFill ?? this.fieldFill,
      mutedText: mutedText ?? this.mutedText,
      faintText: faintText ?? this.faintText,
      headingText: headingText ?? this.headingText,
      bodyText: bodyText ?? this.bodyText,
      accentAmber: accentAmber ?? this.accentAmber,
      onAccentAmber: onAccentAmber ?? this.onAccentAmber,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      chartBar: chartBar ?? this.chartBar,
      chartLabel: chartLabel ?? this.chartLabel,
      navBarBackground: navBarBackground ?? this.navBarBackground,
      navBarBorder: navBarBorder ?? this.navBarBorder,
      navBarScanBg: navBarScanBg ?? this.navBarScanBg,
      navBarScanFg: navBarScanFg ?? this.navBarScanFg,
      onAccent: onAccent ?? this.onAccent,
      imagePlaceholder: imagePlaceholder ?? this.imagePlaceholder,
      shadow: shadow ?? this.shadow,
      logoutBackground: logoutBackground ?? this.logoutBackground,
      logoutForeground: logoutForeground ?? this.logoutForeground,
      divider: divider ?? this.divider,
      chipSelectedFg: chipSelectedFg ?? this.chipSelectedFg,
      authCardSurface: authCardSurface ?? this.authCardSurface,
      authFieldFill: authFieldFill ?? this.authFieldFill,
      authHint: authHint ?? this.authHint,
      authBorder: authBorder ?? this.authBorder,
      glassBorder: glassBorder ?? this.glassBorder,
      modalGradient: modalGradient ?? this.modalGradient,
      brandBackdrop: brandBackdrop ?? this.brandBackdrop,
      authAccent: authAccent ?? this.authAccent,
      authOnAccent: authOnAccent ?? this.authOnAccent,
      authText: authText ?? this.authText,
      authMuted: authMuted ?? this.authMuted,
      waveDark: waveDark ?? this.waveDark,
      waveLight: waveLight ?? this.waveLight,
    );
  }

  @override
  SariColors lerp(ThemeExtension<SariColors>? other, double t) {
    if (other is! SariColors) return this;
    Color lerpC(Color a, Color b) => Color.lerp(a, b, t)!;
    return SariColors(
      screenGradient: t < 0.5 ? screenGradient : other.screenGradient,
      cardSurface: lerpC(cardSurface, other.cardSurface),
      cardSurfaceStrong: lerpC(cardSurfaceStrong, other.cardSurfaceStrong),
      cardBorder: lerpC(cardBorder, other.cardBorder),
      fieldFill: lerpC(fieldFill, other.fieldFill),
      mutedText: lerpC(mutedText, other.mutedText),
      faintText: lerpC(faintText, other.faintText),
      headingText: lerpC(headingText, other.headingText),
      bodyText: lerpC(bodyText, other.bodyText),
      accentAmber: lerpC(accentAmber, other.accentAmber),
      onAccentAmber: lerpC(onAccentAmber, other.onAccentAmber),
      success: lerpC(success, other.success),
      warning: lerpC(warning, other.warning),
      danger: lerpC(danger, other.danger),
      info: lerpC(info, other.info),
      chartBar: lerpC(chartBar, other.chartBar),
      chartLabel: lerpC(chartLabel, other.chartLabel),
      navBarBackground: lerpC(navBarBackground, other.navBarBackground),
      navBarBorder: lerpC(navBarBorder, other.navBarBorder),
      navBarScanBg: lerpC(navBarScanBg, other.navBarScanBg),
      navBarScanFg: lerpC(navBarScanFg, other.navBarScanFg),
      onAccent: lerpC(onAccent, other.onAccent),
      imagePlaceholder: lerpC(imagePlaceholder, other.imagePlaceholder),
      shadow: lerpC(shadow, other.shadow),
      logoutBackground: lerpC(logoutBackground, other.logoutBackground),
      logoutForeground: lerpC(logoutForeground, other.logoutForeground),
      divider: lerpC(divider, other.divider),
      chipSelectedFg: lerpC(chipSelectedFg, other.chipSelectedFg),
      authCardSurface: lerpC(authCardSurface, other.authCardSurface),
      authFieldFill: lerpC(authFieldFill, other.authFieldFill),
      authHint: lerpC(authHint, other.authHint),
      authBorder: lerpC(authBorder, other.authBorder),
      glassBorder: lerpC(glassBorder, other.glassBorder),
      modalGradient: t < 0.5 ? modalGradient : other.modalGradient,
      brandBackdrop: lerpC(brandBackdrop, other.brandBackdrop),
      authAccent: lerpC(authAccent, other.authAccent),
      authOnAccent: lerpC(authOnAccent, other.authOnAccent),
      authText: lerpC(authText, other.authText),
      authMuted: lerpC(authMuted, other.authMuted),
      waveDark: lerpC(waveDark, other.waveDark),
      waveLight: lerpC(waveLight, other.waveLight),
    );
  }
}

typedef AppCustomColors = SariColors;

extension SariThemeContext on BuildContext {
  SariColors get sari =>
      Theme.of(this).extension<SariColors>() ?? SariColors.light;
  AppCustomColors get customColors => sari;
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme);

    const colorScheme = ColorScheme.light(
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightOnPrimary,
      secondary: AppColors.lightHeading,
      onSecondary: AppColors.lightOnPrimary,
      tertiary: AppColors.accentAmber,
      onTertiary: AppColors.onAccentAmber,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightHeading,
      surfaceContainerHighest: AppColors.lightInputFill,
      onSurfaceVariant: AppColors.lightBody,
      outline: AppColors.lightMuted,
      outlineVariant: AppColors.lightBorder,
      error: AppColors.lightError,
      onError: AppColors.lightOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.lightHeading,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.lightHeading,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.lightHeading,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.lightBody,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.lightBody,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.lightMuted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.lightHeading),
        titleTextStyle: TextStyle(
          color: AppColors.lightHeading,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightPrimary,
          foregroundColor: AppColors.lightOnPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          side: const BorderSide(color: AppColors.lightPrimary, width: 1.3),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lightPrimary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightInputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.outfit(
          color: AppColors.lightMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.lightPrimary,
        suffixIconColor: AppColors.lightPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              const BorderSide(color: AppColors.lightPrimary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.lightError, width: 1.3),
        ),
      ),
      // FIX: CardTheme -> CardThemeData
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),
      // FIX: DialogTheme -> DialogThemeData
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.lightHeading,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: AppColors.lightBody,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.lightHeading,
        contentTextStyle: GoogleFonts.outfit(
          color: AppColors.pureWhite,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: AppColors.lightInputFill,
        selectedColor: AppColors.accentAmber,
        side: BorderSide.none,
        labelStyle: GoogleFonts.outfit(
          color: AppColors.lightBody,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.lightPrimary;
          return AppColors.lightMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.lightPrimary.withValues(alpha: 0.35);
          }
          return AppColors.lightInputFill;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.lightPrimary;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.lightPrimary;
          return AppColors.lightMuted;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.lightPrimary,
      ),
      extensions: [SariColors.light],
    );
  }

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme);

    const colorScheme = ColorScheme.dark(
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.darkOnPrimary,
      secondary: AppColors.darkHeading,
      onSecondary: AppColors.darkOnPrimary,
      tertiary: AppColors.accentAmber,
      onTertiary: AppColors.onAccentAmber,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkHeading,
      surfaceContainerHighest: AppColors.darkInputFill,
      onSurfaceVariant: AppColors.darkBody,
      outline: AppColors.darkMuted,
      outlineVariant: AppColors.darkBorder,
      error: AppColors.darkError,
      onError: AppColors.darkOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: colorScheme,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          color: AppColors.darkHeading,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          color: AppColors.darkHeading,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          color: AppColors.darkHeading,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: AppColors.darkBody,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.darkBody,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.darkMuted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.darkHeading),
        titleTextStyle: TextStyle(
          color: AppColors.darkHeading,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkOnPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          side: const BorderSide(color: AppColors.darkPrimary, width: 1.3),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: GoogleFonts.outfit(
          color: AppColors.darkMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: AppColors.darkPrimary,
        suffixIconColor: AppColors.darkPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              const BorderSide(color: AppColors.darkPrimary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.darkError, width: 1.3),
        ),
      ),
      // FIX: CardTheme -> CardThemeData
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      // FIX: DialogTheme -> DialogThemeData
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.darkHeading,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: AppColors.darkBody,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkCard,
        contentTextStyle: GoogleFonts.outfit(
          color: AppColors.darkHeading,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        backgroundColor: AppColors.darkInputFill,
        selectedColor: AppColors.accentAmber,
        side: BorderSide.none,
        labelStyle: GoogleFonts.outfit(
          color: AppColors.darkBody,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.darkPrimary;
          return AppColors.darkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.darkPrimary.withValues(alpha: 0.35);
          }
          return AppColors.darkInputFill;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.darkPrimary;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return AppColors.darkPrimary;
          return AppColors.darkMuted;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.darkPrimary,
      ),
      extensions: [SariColors.dark],
    );
  }

  static ThemeData get theme => dark;
}
