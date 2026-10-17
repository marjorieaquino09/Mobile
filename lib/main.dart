import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/notification_store.dart';
import 'services/push_notification_service.dart';
import 'services/settings_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase already initialized: $e");
  }

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // Load persistent configurations before runApp to prevent theme/state flash
  await Future.wait([
    SettingsStore.instance.load(),
    NotificationStore.instance.load(),
    ThemeController.instance.load(),
  ]);

  try {
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Push init skipped: $e');
  }

  runApp(const SariApp());
}

class SariApp extends StatelessWidget {
  const SariApp({super.key});

  static SystemUiOverlayStyle _overlayFor(Brightness brightness) {
    final light = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      statusBarBrightness: light ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          light ? AppColors.lightBackground : AppColors.darkBackground,
      systemNavigationBarIconBrightness:
          light ? Brightness.dark : Brightness.light,
    );
  }

  static Brightness _resolveBrightness(
    BuildContext context,
    ThemeMode mode,
  ) {
    switch (mode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        SettingsStore.instance,
      ]),
      builder: (context, _) {
        final themeMode = ThemeController.instance.mode;
        return MaterialApp(
          title: 'Sari',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          locale: Locale(SettingsStore.instance.languageCode),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final brightness = _resolveBrightness(context, themeMode);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _overlayFor(brightness),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
