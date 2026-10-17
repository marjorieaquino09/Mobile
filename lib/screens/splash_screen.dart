import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/auth_wave_background.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_store.dart';
import '../services/push_notification_service.dart';
import '../services/settings_store.dart';
import '../services/user_profile_store.dart';
import 'auth/login_screen.dart';
import 'home/main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
    unawaited(_openNextScreen());
  }

  Future<User?> _restoredUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) return currentUser;

    try {
      return await FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(seconds: 2),
          );
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

  Future<void> _runStartupTask(
    String taskName,
    Future<void> Function() task,
  ) async {
    try {
      await task().timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('Splash startup task "$taskName" failed: $error');
    }
  }

  Future<void> _openNextScreen() async {
    // Start restoring the session while the splash animation plays.
    final userFuture = _restoredUser();

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final user = await userFuture;

    if (!mounted) return;

    if (user != null) {
      // A failed refresh should not leave the user stuck on the splash screen.
      await Future.wait<void>([
        _runStartupTask(
          'settings refresh',
          () => SettingsStore.instance.reloadForCurrentUser(),
        ),
        _runStartupTask(
          'notification refresh',
          () => NotificationStore.instance.reloadForCurrentUser(),
        ),
        _runStartupTask(
          'profile refresh',
          () => UserProfileStore.instance.reload(),
        ),
        _runStartupTask(
          'push token binding',
          () => PushNotificationService.instance.bindTokenToCurrentUser(),
        ),
      ]);
    } else {
      UserProfileStore.instance.clear();
    }

    await _runStartupTask(
      'notification permission',
      () => PushNotificationService.instance.requestPermissionIfNeeded(),
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) {
          return user != null ? const MainShell() : const LoginScreen();
        },
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const AuthWaveBackground(
              topLeft: false,
              bottomRight: true,
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: sari.authBorder,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: sari.shadow,
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(29),
                              child: Image.asset(
                                'assets/logo.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: scheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.storefront_rounded,
                                      color: scheme.primary,
                                      size: 52,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sari',
                                style: GoogleFonts.outfit(
                                  color: scheme.onSurface,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                ' •',
                                style: GoogleFonts.outfit(
                                  color: sari.accentAmber,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.text('splashSubtitle'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: sari.mutedText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: 112,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                color: scheme.primary,
                                backgroundColor: sari.authBorder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
