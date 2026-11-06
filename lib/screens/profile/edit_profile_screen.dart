import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../services/user_profile_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';

/// Standalone edit-profile page — opened from Profile (not embedded in Settings).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _storeController = TextEditingController();
  final _emailController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String _photoDataUrl = '';
  Uint8List? _photoBytes;
  bool _loading = true;
  bool _saving = false;

  /// Firestore docs are limited to ~1MB; keep raw picks under this so the
  /// base64 `data:` URL (~4/3 size) still fits with other profile fields.
  static const int _maxPhotoBytes = 500 * 1024;
  static const int _maxUsernameLength = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _storeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _emailController.text = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      _firstNameController.text = (data['firstName'] ?? '').toString();
      _lastNameController.text = (data['lastName'] ?? '').toString();
      _usernameController.text = (data['username'] ?? '').toString();
      _storeController.text = (data['storeName'] ?? '').toString();
      final storedEmail = (data['email'] ?? '').toString().trim();
      if (storedEmail.isNotEmpty) {
        _emailController.text = storedEmail;
      }

      final photo = (data['photoUrl'] ?? '').toString();
      if (photo.isNotEmpty) {
        _photoDataUrl = photo;
        if (photo.startsWith('data:image')) {
          try {
            _photoBytes = base64Decode(photo.split(',').last);
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.text(
              'profileLoadFailed',
              values: {'error': '$e'},
            )),
            backgroundColor: sari.danger,
          ),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: sari.cardSurfaceStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: sari.faintText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: sari.success),
                title: Text(context.l10n.text('gallery'),
                    style: TextStyle(color: scheme.onSurface)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: sari.success),
                title: Text(context.l10n.text('camera'),
                    style: TextStyle(color: scheme.onSurface)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (_photoDataUrl.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: sari.danger),
                  title: Text(context.l10n.text('removePhoto'),
                      style: TextStyle(color: sari.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _photoBytes = null;
                      _photoDataUrl = '';
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 55,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxPhotoBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.text('photoTooLarge'),
            ),
            backgroundColor: sari.danger,
          ),
        );
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text(
            'couldNotPickPhoto',
            values: {'error': '$e'},
          )),
          backgroundColor: sari.danger,
        ),
      );
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return context.l10n.text('requiredField', values: {'field': label});
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return context.l10n.text(
        'requiredField',
        values: {'field': context.l10n.text('email')},
      );
    }
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!ok) return context.l10n.text('validEmail');
    return null;
  }

  String? _validateUsername(String? value) {
    final username = (value ?? '').trim();
    if (username.isEmpty) return null; // optional
    if (username.length < 3) {
      return context.l10n.text('usernameMinLength');
    }
    if (username.length > _maxUsernameLength) {
      return context.l10n.text('usernameTooLong');
    }
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      return context.l10n.text('usernameCharacters');
    }
    return null;
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.text('noSignedInUserLogin')),
          backgroundColor: sari.danger,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final storeName = _storeController.text.trim();

    const maxEncodedChars = 900 * 1024;
    if (_photoDataUrl.startsWith('data:image') &&
        _photoDataUrl.length > maxEncodedChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.text('profilePhotoTooLarge'),
          ),
          backgroundColor: sari.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Hindi na kasama ang phone, address, at birthday. Dahil `merge: true`,
      // mananatili ang dati nang naka-save na values sa database.
      final payload = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'storeName': storeName,
        'email': email,
        'photoUrl': _photoDataUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final appL10n = context.l10n;
      final messenger = ScaffoldMessenger.maybeOf(context);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      String successMessage = appL10n.text('profileSaved');

      if (user.email != null &&
          user.email!.toLowerCase() != email.toLowerCase()) {
        try {
          await user.verifyBeforeUpdateEmail(email);
          successMessage = appL10n.text('profileEmailUpdated');
        } catch (e) {
          debugPrint('Auth email update skipped: $e');
          successMessage = appL10n.text('profileEmailNotUpdated');
        }
      }

      final display = '$firstName $lastName'.trim();
      if (display.isNotEmpty) {
        try {
          await user.updateDisplayName(display);
        } catch (e) {
          debugPrint('Display name update skipped: $e');
        }
      }

      await UserProfileStore.instance.reload();

      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: scheme.primary,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.text(
            'profileSaveFailed',
            values: {'error': '$e'},
          )),
          backgroundColor: sari.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: sari.screenGradient),
        child: SafeArea(
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: sari.success),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon:
                                Icon(Icons.arrow_back, color: scheme.onSurface),
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                          ),
                          Expanded(
                            child: Text(
                              context.l10n.text('editProfile'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Para nasa gitna ang title (kapareho ng laki ng back button)
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            18,
                            8,
                            18,
                            16 + bottomInset,
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            _photoPicker(),
                            const SizedBox(height: 18),
                            _sectionCard(
                              title: context.l10n.text('personalSection'),
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _field(
                                        context.l10n.text('firstName'),
                                        _firstNameController,
                                        validator: (v) => _required(
                                            v, context.l10n.text('firstName')),
                                        textCapitalization:
                                            TextCapitalization.words,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _field(
                                        context.l10n.text('lastName'),
                                        _lastNameController,
                                        validator: (v) => _required(
                                            v, context.l10n.text('lastName')),
                                        textCapitalization:
                                            TextCapitalization.words,
                                      ),
                                    ),
                                  ],
                                ),
                                _field(
                                  context.l10n.text('username'),
                                  _usernameController,
                                  hint: context
                                      .l10n
                                      .text('optionalUsernameHint'),
                                  validator: _validateUsername,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9._]'),
                                    ),
                                    LengthLimitingTextInputFormatter(
                                      _maxUsernameLength,
                                    ),
                                  ],
                                  isLast: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _sectionCard(
                              title: context.l10n.text('storeContactSection'),
                              children: [
                                _field(
                                  context.l10n.text('storeName'),
                                  _storeController,
                                  validator: (v) => _required(
                                      v, context.l10n.text('storeName')),
                                  textCapitalization:
                                      TextCapitalization.words,
                                ),
                                _field(
                                  context.l10n.text('email'),
                                  _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                  isLast: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: sari.warning,
                                  foregroundColor: sari.onAccentAmber,
                                  disabledBackgroundColor:
                                      sari.warning.withValues(alpha: 0.45),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: _saving
                                    ? SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: sari.onAccentAmber,
                                        ),
                                      )
                                    : Text(
                                        context.l10n.text('saveProfile'),
                                        style: TextStyle(
                                          color: sari.onAccentAmber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: sari.mutedText,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: Text(
                                  context.l10n.text('cancel'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _photoPicker() {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : _pickPhoto,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sari.success.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 42,
                    backgroundColor: sari.fieldFill,
                    backgroundImage:
                        _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                    child: _photoBytes == null
                        ? (_photoDataUrl.isNotEmpty
                            ? ClipOval(
                                child: ProductImage(
                                  imageUrl: _photoDataUrl,
                                  width: 84,
                                  height: 84,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(Icons.person,
                                size: 38, color: scheme.onSurface))
                        : null,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: sari.warning,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sari.cardSurfaceStrong,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: sari.onAccentAmber,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.text('tapChangeProfilePhoto'),
          style: TextStyle(
            color: sari.faintText,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  /// Card na may pamagat, para malinaw ang grupo ng mga field.
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: sari.cardSurfaceStrong.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sari.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: sari.faintText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? hint,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        enabled: !_saving,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: TextStyle(color: scheme.onSurface, fontSize: 14.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: sari.mutedText, fontSize: 14),
          hintStyle: TextStyle(color: sari.faintText, fontSize: 13),
          errorStyle: TextStyle(color: sari.warning, fontSize: 11.5),
          filled: true,
          fillColor: sari.fieldFill.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: sari.success.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: sari.warning,
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: sari.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: sari.danger, width: 1.2),
          ),
        ),
      ),
    );
  }
}