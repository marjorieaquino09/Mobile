
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notification_store.dart';
import '../../services/push_notification_service.dart';
import '../../services/settings_store.dart';
import '../home/main_shell.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (FirebaseAuth.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MainShell(),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppSnackbar.showError(
        context,
        l10n.text('loginEnterCredentials'),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await SettingsStore.instance.reloadForCurrentUser();
      await NotificationStore.instance.reloadForCurrentUser();

      try {
        await PushNotificationService.instance
            .bindTokenToCurrentUser();
      } catch (_) {
        // Push notification setup should not block login.
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MainShell(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = l10n.text('loginFailed');

      if (e.code == 'user-not-found') {
        message = l10n.text('loginNoAccountFound');
      } else if (e.code == 'wrong-password') {
        message = l10n.text('loginIncorrectPassword');
      } else if (e.code == 'invalid-credential') {
        message = l10n.text('loginInvalidCredentials');
      } else if (e.code == 'invalid-email') {
        message = l10n.text('resetInvalidEmail');
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }

      if (!mounted) return;
      AppSnackbar.showError(context, message);
    } catch (e) {
      if (!mounted) return;

      AppSnackbar.showError(
        context,
        l10n.text(
          'loginGenericError',
          values: {'error': '$e'},
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sari = context.sari;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight =
                (constraints.maxHeight - 32).clamp(0.0, double.infinity);

            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 440,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SARI BRAND
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Image.asset(
                                'assets/logo.jpg',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                ) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(19),
                                    ),
                                    child: Icon(
                                      Icons.eco_rounded,
                                      color: scheme.primary,
                                      size: 32,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sari',
                                  style: GoogleFonts.outfit(
                                    color: scheme.onSurface,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'STORE MANAGEMENT',
                                  style: GoogleFonts.outfit(
                                    color: sari.mutedText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 34),

                        // WELCOME
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: scheme.onSurface,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Sign in to your store account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: sari.mutedText,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 30),

                        // LOGIN CARD
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            24,
                            24,
                            25,
                          ),
                          decoration: BoxDecoration(
                            color: sari.authCardSurface,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: sari.authBorder,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: sari.shadow,
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              _LoginFieldLabel(
                                label: 'EMAIL ADDRESS',
                                color: sari.mutedText,
                              ),
                              const SizedBox(height: 10),

                              AppTextField(
                                controller: _emailController,
                                hintText: 'you@example.com',
                                prefixIcon:
                                    Icons.mail_outline_rounded,
                                keyboardType:
                                    TextInputType.emailAddress,
                              ),

                              const SizedBox(height: 23),

                              _LoginFieldLabel(
                                label: 'PASSWORD',
                                color: sari.mutedText,
                              ),
                              const SizedBox(height: 10),

                              AppTextField(
                                controller: _passwordController,
                                hintText: 'Enter your password',
                                prefixIcon:
                                    Icons.lock_outline_rounded,
                                obscureText: true,
                              ),

                              const SizedBox(height: 12),

                              // REMEMBER ME / FORGOT PASSWORD
                              Row(
                                children: [
                                  SizedBox(
                                    width: 32,
                                    height: 42,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                      activeColor: scheme.primary,
                                      checkColor: scheme.onPrimary,
                                      side: BorderSide(
                                        color: sari.mutedText,
                                        width: 1.4,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _rememberMe = !_rememberMe;
                                        });
                                      },
                                      child: Text(
                                        'Remember me',
                                        style: GoogleFonts.outfit(
                                          color: scheme.onSurface,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ForgotPasswordScreen(
                                            initialEmail:
                                                _emailController.text
                                                    .trim(),
                                          ),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets
                                          .symmetric(horizontal: 2),
                                      minimumSize:
                                          const Size(0, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize
                                              .shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.outfit(
                                        color: scheme.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              PrimaryButton(
                                label: 'Sign In',
                                height: 62,
                                isLoading: _isLoading,
                                onPressed: _login,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 23),

                        // SIGNUP FOOTER
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment:
                              WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            Text(
                              'New to Sari?',
                              style: GoogleFonts.outfit(
                                color: sari.mutedText,
                                fontSize: 15,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SignupScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                minimumSize: const Size(0, 44),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Create an account',
                                style: GoogleFonts.outfit(
                                  color: scheme.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginFieldLabel extends StatelessWidget {
  const _LoginFieldLabel({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
      ),
    );
  }
}
