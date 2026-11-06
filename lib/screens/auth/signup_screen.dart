import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/app_localizations.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _storeNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final l10n = context.l10n;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final storeName = _storeNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        storeName.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      AppSnackbar.showError(context, l10n.text('signupAllFields'));
      return;
    }

    if (password != confirmPassword) {
      AppSnackbar.showError(context, l10n.text('passwordMismatch'));
      return;
    }

    if (password.length < 6) {
      AppSnackbar.showError(context, l10n.text('passwordLength'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': firstName,
        'lastName': lastName,
        'storeName': storeName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      AppSnackbar.showSuccess(context, l10n.text('signupSuccess'));
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      AppSnackbar.showError(context, e.message ?? l10n.text('signupError'));
    } catch (e) {
      AppSnackbar.showError(
        context,
        l10n.text('signupFailed', values: {'error': '$e'}),
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
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minContentHeight =
                constraints.maxHeight > 32 ? constraints.maxHeight - 32 : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minContentHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo & Brand Name
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _SariLogo(
                              size: 48,
                              fallbackColor: scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sari',
                                  style: GoogleFonts.outfit(
                                    color: scheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'STORE MANAGEMENT',
                                  style: GoogleFonts.outfit(
                                    color: sari.mutedText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Create your account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: scheme.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.12,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register your store to get started',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: sari.mutedText,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Form Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: sari.authCardSurface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: sari.authBorder),
                            boxShadow: [
                              BoxShadow(
                                color: sari.shadow,
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Personal Details Section
                              _SignupFieldLabel(
                                label: 'PERSONAL DETAILS',
                                color: sari.mutedText,
                              ),
                              const SizedBox(height: 10),
                              
                              // First & Last Name Side-by-Side (2 Columns)
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _firstNameController,
                                      hintText: l10n.text('firstName'),
                                      prefixIcon: Icons.badge_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: AppTextField(
                                      controller: _lastNameController,
                                      hintText: l10n.text('lastName'),
                                      prefixIcon: Icons.badge_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Store Details Section
                              _SignupFieldLabel(
                                label: 'STORE DETAILS',
                                color: sari.mutedText,
                              ),
                              const SizedBox(height: 10),
                              AppTextField(
                                controller: _storeNameController,
                                hintText: 'Store name',
                                prefixIcon: Icons.storefront_outlined,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _emailController,
                                hintText: 'Email address',
                                prefixIcon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _passwordController,
                                hintText: 'Password',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: true,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _confirmPasswordController,
                                hintText: 'Confirm password',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: true,
                              ),
                              const SizedBox(height: 20),

                              PrimaryButton(
                                label: 'Create Account',
                                isLoading: _isLoading,
                                onPressed: _signUp,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Login Link Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                '${l10n.text('signupAlreadyHaveAccount')} ',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: sari.mutedText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                minimumSize: const Size(0, 48),
                              ),
                              child: Text(
                                'Log In',
                                style: GoogleFonts.outfit(
                                  color: scheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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

class _SariLogo extends StatelessWidget {
  const _SariLogo({required this.size, required this.fallbackColor});

  final double size;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fallbackColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: fallbackColor,
              size: size * 0.54,
            ),
          );
        },
      ),
    );
  }
}

class _SignupFieldLabel extends StatelessWidget {
  const _SignupFieldLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}