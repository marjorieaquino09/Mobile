import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  DateTime? _birthDate;
  bool _isLoading = false;

  static final DateFormat _storageFormat = DateFormat('yyyy-MM-dd');

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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - 13, now.month, now.day);
    final earliest = DateTime(now.year - 100, now.month, now.day);
    final initial = _birthDate ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(earliest)
          ? earliest
          : (initial.isAfter(latest) ? latest : initial),
      firstDate: earliest,
      lastDate: latest,
      helpText: context.l10n.text('selectBirthday'),
      cancelText: context.l10n.text('cancel'),
      confirmText: context.l10n.text('save'),
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  bool _isValidBirthDate(DateTime date) {
    final now = DateTime.now();
    final thirteenYearsAgo = DateTime(now.year - 13, now.month, now.day);
    final hundredYearsAgo = DateTime(now.year - 100, now.month, now.day);

    return !date.isAfter(thirteenYearsAgo) && !date.isBefore(hundredYearsAgo);
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
        password.isEmpty ||
        _birthDate == null) {
      AppSnackbar.showError(context, l10n.text('signupAllFields'));
      return;
    }

    if (!_isValidBirthDate(_birthDate!)) {
      AppSnackbar.showError(context, l10n.text('signupValidBirthday'));
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
      final dobIso = _storageFormat.format(_birthDate!);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': firstName,
        'lastName': lastName,
        'storeName': storeName,
        'email': email,
        'dateOfBirth': dobIso,
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
    final hasDate = _birthDate != null;

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
                            fontSize: 29,
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
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(18),
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
                              _SignupFieldLabel(
                                label: 'PERSONAL DETAILS',
                                color: sari.mutedText,
                              ),
                              const SizedBox(height: 10),
                              AppTextField(
                                controller: _firstNameController,
                                hintText: l10n.text('firstName'),
                                prefixIcon: Icons.badge_outlined,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _lastNameController,
                                hintText: l10n.text('lastName'),
                                prefixIcon: Icons.badge_outlined,
                              ),
                              const SizedBox(height: 16),
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
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isLoading ? null : _pickBirthDate,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Ink(
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: sari.fieldFill,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: sari.authBorder,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            color: scheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              hasDate
                                                  ? DateFormat(
                                                      'MMM d, yyyy',
                                                      Localizations.localeOf(
                                                        context,
                                                      ).languageCode,
                                                    ).format(_birthDate!)
                                                  : l10n.text('selectBirthday'),
                                              style: GoogleFonts.outfit(
                                                color: hasDate
                                                    ? scheme.onSurface
                                                    : sari.faintText,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: sari.mutedText,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
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
