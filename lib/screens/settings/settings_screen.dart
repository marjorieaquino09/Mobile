import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/theme_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/push_notification_service.dart';
import '../../services/settings_store.dart';
import '../../services/user_profile_store.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  final SettingsStore _settings = SettingsStore.instance;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    _syncPushWithOs();
  }

  /// If OS permission was revoked, reflect that in the Settings toggle.
  Future<void> _syncPushWithOs() async {
    try {
      final granted =
          await PushNotificationService.instance.isOsPermissionGranted;
      if (!granted && _settings.pushEnabled) {
        await _settings.setPush(false);
      }
    } catch (_) {}
  }

  Future<void> _pickLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: sari.cardSurfaceStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: sari.success.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: sari.faintText.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  l10n.text('selectLanguage'),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                for (final code in const ['en', 'fil'])
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, code),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.languageName(code),
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (code == _settings.languageCode)
                              Icon(
                                Icons.check_rounded,
                                color: sari.warning,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) await _settings.setLanguage(selected);
  }

  Future<void> _pickThemeMode() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = ctx.l10n;
        final sheetSari = ctx.sari;
        final sheetScheme = Theme.of(ctx).colorScheme;
        final options = <(ThemeMode, String)>[
          (ThemeMode.system, l10n.text('themeSystem')),
          (ThemeMode.light, l10n.text('themeLight')),
          (ThemeMode.dark, l10n.text('themeDark')),
        ];
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: sheetSari.cardSurfaceStrong,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: sheetSari.cardBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: sheetSari.faintText.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  l10n.text('selectAppearance'),
                  style: TextStyle(
                    color: sheetScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                for (final option in options)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, option.$1),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.$2,
                                style: TextStyle(
                                  color: sheetScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (option.$1 == _settings.themeMode)
                              Icon(
                                Icons.check_rounded,
                                color: sheetSari.warning,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      await ThemeController.instance.setThemeMode(selected);
    }
  }

  Future<void> _editTaxRate() async {
    final l10n = context.l10n;
    final controller =
        TextEditingController(text: _settings.taxRate.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sari.cardSurfaceStrong,
        title: Text(
          l10n.text('taxRateTitle'),
          style: TextStyle(color: scheme.onSurface),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            labelText: l10n.text('percent'),
            suffixText: '%',
            labelStyle: TextStyle(color: sari.mutedText),
            filled: true,
            fillColor: sari.fieldFill.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.text('cancel'),
              style: TextStyle(color: sari.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.text('validTaxRate'))),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: Text(l10n.text('save')),
          ),
        ],
      ),
    );
    if (result != null) {
      await _settings.setTaxRate(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.text(
                'taxRateSet',
                values: {'rate': _settings.taxRate.toStringAsFixed(0)},
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onPushChanged(bool enable) async {
    final l10n = context.l10n;
    if (_pushBusy) return;
    setState(() => _pushBusy = true);
    try {
      if (enable) {
        final granted =
            await PushNotificationService.instance.enableFromSettings();
        if (!mounted) return;
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.text('pushPermissionOff')),
              action: SnackBarAction(
                label: l10n.text('open'),
                textColor: sari.warning,
                onPressed: () {
                  PushNotificationService.instance.openSystemSettings();
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.text('pushEnabled'))),
          );
        }
      } else {
        await PushNotificationService.instance.disableFromSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.text('pushDisabled'))),
        );
      }
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  Future<void> _logout() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: sari.cardSurfaceStrong,
        title: Text(
          l10n.text('logOutTitle'),
          style: TextStyle(color: scheme.onSurface),
        ),
        content: Text(
          l10n.text('logOutMessage'),
          style: TextStyle(color: sari.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.text('cancel'),
              style: TextStyle(color: sari.mutedText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: sari.danger,
              foregroundColor: scheme.onError,
            ),
            child: Text(l10n.text('logOut')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    UserProfileStore.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: sari.screenGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: scheme.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.text('settings'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _settings,
                    builder: (context, _) {
                      final l10n = context.l10n;
                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _sectionLabel(l10n.text('languageSection')),
                          _tileCard(
                            children: [
                              _navRow(
                                icon: Icons.language_rounded,
                                title: l10n.text('language'),
                                subtitle: l10n.text('languageSubtitle'),
                                onTap: _pickLanguage,
                                value:
                                    l10n.languageName(_settings.languageCode),
                              ),
                              _divider(),
                              _navRow(
                                icon: Icons.palette_outlined,
                                title: l10n.text('appearance'),
                                subtitle: l10n.text('appearanceSubtitle'),
                                onTap: _pickThemeMode,
                                value: l10n.themeModeName(
                                  switch (_settings.themeMode) {
                                    ThemeMode.light => 'light',
                                    ThemeMode.dark => 'dark',
                                    ThemeMode.system => 'system',
                                  },
                                ),
                              ),
                            ],
                          ),
                          _sectionLabel(l10n.text('accountSection')),
                          _tileCard(
                            children: [
                              _navRow(
                                icon: Icons.lock_outline_rounded,
                                title: l10n.text('changePassword'),
                                subtitle: l10n.text('changePasswordSubtitle'),
                                onTap: _showChangePassword,
                              ),
                            ],
                          ),
                          _sectionLabel(l10n.text('storeSection')),
                          _tileCard(
                            children: [
                              _valueRow(
                                icon: Icons.payments_outlined,
                                title: l10n.text('currency'),
                                subtitle: l10n.text('currencySubtitle'),
                                value: '₱ PHP',
                                showEdit: false,
                              ),
                              _divider(),
                              _valueRow(
                                icon: Icons.percent_rounded,
                                title: l10n.text('taxRate'),
                                subtitle: l10n.text('taxRateSubtitle'),
                                value:
                                    '${_settings.taxRate.toStringAsFixed(0)}%',
                                onTap: _editTaxRate,
                              ),
                            ],
                          ),
                          _sectionLabel(l10n.text('notificationsSection')),
                          _tileCard(
                            children: [
                              _switchRow(
                                icon: Icons.notifications_active_outlined,
                                title: l10n.text('pushNotifications'),
                                subtitle: _pushBusy
                                    ? l10n.text('updating')
                                    : l10n.text('pushSubtitle'),
                                value: _settings.pushEnabled,
                                onChanged: _pushBusy ? null : _onPushChanged,
                              ),
                              _divider(),
                              _switchRow(
                                icon: Icons.inventory_2_outlined,
                                title: l10n.text('lowStockAlerts'),
                                subtitle: l10n.text('lowStockSubtitle'),
                                value: _settings.lowStockEnabled,
                                onChanged: (v) => _settings.setLowStock(v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton.icon(
                              onPressed: _logout,
                              icon: Icon(
                                Icons.logout_rounded,
                                color: sari.logoutForeground,
                                size: 18,
                              ),
                              label: Text(
                                l10n.text('logOut'),
                                style: TextStyle(
                                  color: sari.logoutForeground,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: sari.logoutBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: sari.danger.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePassword() async {
    final l10n = context.l10n;
    final currentController = TextEditingController();
    final controller = TextEditingController();
    final confirm = TextEditingController();
    var saving = false;
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: sari.cardSurfaceStrong,
            title: Text(
              l10n.text('changePassword'),
              style: TextStyle(color: scheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: obscureCurrent,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.text('currentPassword'),
                    labelStyle: TextStyle(color: sari.mutedText),
                    filled: true,
                    fillColor: sari.fieldFill.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: sari.faintText,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureCurrent = !obscureCurrent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  obscureText: obscureNew,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.text('newPassword'),
                    labelStyle: TextStyle(color: sari.mutedText),
                    filled: true,
                    fillColor: sari.fieldFill.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: sari.faintText,
                        size: 20,
                      ),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirm,
                  obscureText: obscureConfirm,
                  style: TextStyle(color: scheme.onSurface),
                  decoration: InputDecoration(
                    labelText: l10n.text('confirmPassword'),
                    labelStyle: TextStyle(color: sari.mutedText),
                    filled: true,
                    fillColor: sari.fieldFill.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: sari.faintText,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureConfirm = !obscureConfirm,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(
                  l10n.text('cancel'),
                  style: TextStyle(color: sari.mutedText),
                ),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final current = currentController.text;
                        final pass = controller.text;
                        if (current.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.text('enterCurrentPassword')),
                            ),
                          );
                          return;
                        }
                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.text('passwordLength'))),
                          );
                          return;
                        }
                        if (pass != confirm.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.text('passwordMismatch'))),
                          );
                          return;
                        }

                        final user = FirebaseAuth.instance.currentUser;
                        final email = user?.email;
                        if (user == null || email == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.text('noSignedInUser')),
                              backgroundColor: sari.danger,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => saving = true);
                        try {
                          final cred = EmailAuthProvider.credential(
                            email: email,
                            password: current,
                          );
                          await user.reauthenticateWithCredential(cred);
                          await user.updatePassword(pass);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.text('passwordUpdated')),
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          final msg = switch (e.code) {
                            'wrong-password' ||
                            'invalid-credential' =>
                              l10n.text('currentPasswordIncorrect'),
                            'requires-recent-login' => l10n.text('loginAgain'),
                            'weak-password' => l10n.text('strongerPassword'),
                            _ => e.message ?? l10n.text('passwordUpdateFailed'),
                          };
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: sari.danger,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.text(
                                'failed',
                                values: {'error': '$e'},
                              )),
                              backgroundColor: sari.danger,
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.text('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Layout helpers ──────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: sari.faintText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _tileCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: sari.cardSurfaceStrong.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: sari.glassBorder,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: Column(children: children),
          ),
        ),
      );

  Widget _divider() => Divider(
        color: sari.glassBorder.withValues(alpha: 0.6),
        thickness: 1,
        height: 1,
        indent: 58,
      );

  Widget _leadingIcon(IconData icon) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: sari.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: sari.success, size: 18),
      );

  Widget _titleBlock(String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sari.mutedText,
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
        ],
      );

  static const EdgeInsets _rowPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 11);

  Widget _navRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? value,
  }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: _rowPadding,
          child: Row(
            children: [
              _leadingIcon(icon),
              const SizedBox(width: 12),
              Expanded(child: _titleBlock(title, subtitle)),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: sari.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: sari.warning, size: 20),
            ],
          ),
        ),
      );

  Widget _valueRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    VoidCallback? onTap,
    bool showEdit = true,
  }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: _rowPadding,
          child: Row(
            children: [
              _leadingIcon(icon),
              const SizedBox(width: 12),
              Expanded(child: _titleBlock(title, subtitle)),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: sari.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              if (showEdit) ...[
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 16, color: sari.faintText),
              ],
            ],
          ),
        ),
      );

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            _leadingIcon(icon),
            const SizedBox(width: 12),
            Expanded(child: _titleBlock(title, subtitle)),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeThumbColor: sari.warning,
                activeTrackColor: sari.warning.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      );
}