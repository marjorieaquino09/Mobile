import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  static final DateFormat _storageFormat = DateFormat('yyyy-MM-dd');

  String _photoDataUrl = '';
  Uint8List? _photoBytes;
  DateTime? _birthDate;
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
    _phoneController.dispose();
    _addressController.dispose();
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
      _addressController.text = (data['address'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      final storedEmail = (data['email'] ?? '').toString().trim();
      if (storedEmail.isNotEmpty) {
        _emailController.text = storedEmail;
      }

      final dobRaw = (data['dateOfBirth'] ?? '').toString().trim();
      if (dobRaw.isNotEmpty) {
        _birthDate = DateTime.tryParse(dobRaw) ??
            (dobRaw.contains('/')
                ? null
                : DateTime.tryParse(dobRaw.replaceAll('/', '-')));
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: scheme.copyWith(
              primary: sari.warning,
              onPrimary: sari.onAccentAmber,
              surface: sari.cardSurfaceStrong,
              onSurface: scheme.onSurface,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: sari.cardSurfaceStrong,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
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

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return context.l10n.text('validPhone');
    }
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
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

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
      final payload = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'storeName': storeName,
        'email': email,
        'address': address,
        'phone': phone,
        'photoUrl': _photoDataUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_birthDate != null) {
        payload['dateOfBirth'] = _storageFormat.format(_birthDate!);
      }

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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
                          TextButton(
                            onPressed: _saving ? null : _save,
                            child: Text(
                              context.l10n.text('save'),
                              style: TextStyle(
                                color: _saving ? sari.faintText : sari.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            16 + bottomInset,
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _saving ? null : _pickPhoto,
                                  customBorder: const CircleBorder(),
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundColor: sari.fieldFill,
                                        backgroundImage: _photoBytes != null
                                            ? MemoryImage(_photoBytes!)
                                            : null,
                                        child: _photoBytes == null
                                            ? (_photoDataUrl.isNotEmpty
                                                ? ClipOval(
                                                    child: ProductImage(
                                                      imageUrl: _photoDataUrl,
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Icon(Icons.person,
                                                    size: 36,
                                                    color: scheme.onSurface))
                                            : null,
                                      ),
                                      Container(
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
                                          Icons.camera_alt,
                                          size: 14,
                                          color: sari.onAccentAmber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: Text(
                                context.l10n.text('tapChangeProfilePhoto'),
                                style: TextStyle(
                                  color: sari.faintText,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _sectionLabel(context.l10n.text('personalSection')),
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
                              hint: context.l10n.text('optionalUsernameHint'),
                              validator: _validateUsername,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9._]'),
                                ),
                                LengthLimitingTextInputFormatter(
                                  _maxUsernameLength,
                                ),
                              ],
                            ),
                            _birthdayField(),
                            const SizedBox(height: 8),
                            _sectionLabel(
                                context.l10n.text('storeContactSection')),
                            _field(
                              context.l10n.text('storeName'),
                              _storeController,
                              validator: (v) =>
                                  _required(v, context.l10n.text('storeName')),
                              textCapitalization: TextCapitalization.words,
                            ),
                            _field(
                              context.l10n.text('email'),
                              _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            _field(
                              context.l10n.text('phone'),
                              _phoneController,
                              keyboardType: TextInputType.phone,
                              hint: context.l10n.text('optional'),
                              validator: _validatePhone,
                            ),
                            _field(
                              context.l10n.text('address'),
                              _addressController,
                              maxLines: 2,
                              validator: (v) =>
                                  _required(v, context.l10n.text('address')),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: sari.warning,
                                  foregroundColor: sari.onAccentAmber,
                                  disabledBackgroundColor:
                                      sari.warning.withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
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
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: sari.mutedText,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    side: BorderSide(
                                      color: sari.cardBorder,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  context.l10n.text('cancel'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
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

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          text,
          style: TextStyle(
            color: sari.faintText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
      );

  Widget _birthdayField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _pickBirthDate,
          borderRadius: BorderRadius.circular(16),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.l10n.text('birthday'),
              labelStyle: TextStyle(color: sari.mutedText),
              filled: true,
              fillColor: sari.fieldFill.withValues(alpha: 0.45),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              suffixIcon: Icon(Icons.calendar_today_outlined,
                  color: sari.faintText, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: sari.success.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Text(
              _birthDate != null
                  ? DateFormat(
                      'MMM d, yyyy',
                      Localizations.localeOf(context).languageCode,
                    ).format(_birthDate!)
                  : context.l10n.text('selectBirthday'),
              style: TextStyle(
                color: _birthDate != null ? scheme.onSurface : sari.faintText,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        enabled: !_saving,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: sari.mutedText),
          hintStyle: TextStyle(color: sari.faintText, fontSize: 13),
          errorStyle: TextStyle(color: sari.warning),
          filled: true,
          fillColor: sari.fieldFill.withValues(alpha: 0.45),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: sari.success.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: sari.warning,
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: sari.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: sari.danger, width: 1.2),
          ),
        ),
      ),
    );
  }
}
