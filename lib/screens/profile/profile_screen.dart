import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_image.dart';
import '../dashboard/dashboard_section.dart';
import '../orders/orders_screen.dart';
import '../settings/settings_screen.dart';
import '../credit/credit_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userName;
  final ValueChanged<String>? onNameChanged;

  const ProfileScreen({
    super.key,
    this.userName,
    this.onNameChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _MenuEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget destination;

  const _MenuEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destination,
  });
}

class _ProfileScreenState extends State<ProfileScreen> {
  SariColors get sari => context.sari;
  ColorScheme get scheme => Theme.of(context).colorScheme;

  String _name = '';
  String _username = '';
  String _storeName = '';
  String _address = '';
  String _email = '';
  String _phone = '';
  String _photoUrl = '';
  Uint8List? _imageBytes;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          
          // Sinusuportahan na nito ang 'full_name', 'store_name', at 'profile_image' mula sa web
          final fullName = (data['full_name'] ?? data['firstName'] ?? '').toString();
          final store = (data['store_name'] ?? data['storeName'] ?? '').toString();
          final photo = (data['profile_image'] ?? data['photoUrl'] ?? '').toString();
          
          Uint8List? bytes;
          if (photo.startsWith('data:image')) {
            try {
              bytes = base64Decode(photo.split(',').last);
            } catch (_) {}
          }

          if (!mounted) return;
          setState(() {
            _name = fullName.isNotEmpty ? fullName : (widget.userName ?? 'User');
            _username = (data['username'] ?? '').toString().trim();
            _storeName = store.isNotEmpty ? store : 'My Store';
            _address = (data['address'] ?? '').toString();
            _email = (data['email'] ?? user.email ?? '').toString();
            _phone = (data['phone'] ?? '').toString();
            _photoUrl = photo;
            _imageBytes = bytes;
            _loading = false;
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        _setFallbackData();
        setState(() {
          _loadError = context.l10n.text('profileLoadError');
          _loading = false;
        });
        return;
      }
    }
    _setFallbackData();
    if (mounted) setState(() => _loading = false);
  }

  void _setFallbackData() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _name = (widget.userName != null && widget.userName!.isNotEmpty)
          ? widget.userName!
          : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!
              : 'User');
      _username = '';
      _storeName = 'My Store';
      _email = user?.email ?? '';
      _phone = '';
      _address = '';
    });
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (updated == true && mounted) {
      await _fetchUserData();
      if (widget.onNameChanged != null) {
        widget.onNameChanged!(_name);
      }
    }
  }

  Widget _avatar({double radius = 26}) {
    Widget avatar;
    if (_imageBytes != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: sari.success,
        backgroundImage: MemoryImage(_imageBytes!),
      );
    } else if (_photoUrl.isNotEmpty && !_photoUrl.startsWith('data:image')) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: sari.success,
        child: ClipOval(
          child: ProductImage(
            imageUrl: _photoUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: sari.success,
        child: Text(
          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
          style: TextStyle(
            color: sari.onAccent,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.7,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _openEditProfile,
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
              child: avatar,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
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
                  size: 10,
                  color: sari.onAccentAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 360 ? 14.0 : 18.0;
    final l10n = context.l10n;

    final contactRows = <Widget>[
      if (_phone.isNotEmpty) _contactRow(Icons.phone_outlined, _phone),
      if (_address.isNotEmpty)
        _contactRow(Icons.location_on_outlined, _address, maxLines: 2),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(gradient: sari.screenGradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: sari.warning,
            backgroundColor: sari.cardSurfaceStrong,
            onRefresh: _fetchUserData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(horizontal, 6, horizontal, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                    child: Text(
                      l10n.text('profileTitle'),
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (_loadError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: sari.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sari.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _loadError!,
                        style: TextStyle(
                          color: sari.warning,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],

                  // ── Compact identity card ───────────────────────────────
                  _glassCard(
                    child: _loading
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: sari.success,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _avatar(),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: scheme.onSurface,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (_username.isNotEmpty)
                                              Text(
                                                '@$_username',
                                                style: TextStyle(
                                                  color: sari.warning,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            if (_storeName.isNotEmpty)
                                              _storeChip(_storeName),
                                          ],
                                        ),
                                        if (_email.isNotEmpty) ...[
                                          const SizedBox(height: 5),
                                          Text(
                                            _email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: sari.mutedText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _editButton(l10n.text('edit')),
                                ],
                              ),
                              if (contactRows.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Divider(
                                  color: sari.glassBorder,
                                  height: 1,
                                  thickness: 1,
                                ),
                                const SizedBox(height: 10),
                                for (var i = 0; i < contactRows.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  contactRows[i],
                                ],
                              ],
                            ],
                          ),
                  ),

                  if (!_loading) ...[
                    const SizedBox(height: 12),
                    const DashboardSection(),
                  ],

                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      l10n.text('manage'),
                      style: TextStyle(
                        color: sari.faintText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _menuGroup([
                    _MenuEntry(
                      icon: Icons.receipt_long_rounded,
                      title: l10n.text('orders'),
                      subtitle: l10n.text('ordersSubtitle'),
                      destination: const OrdersScreen(),
                    ),
                    _MenuEntry(
                      icon: Icons.assignment_outlined,
                      title: l10n.text('creditUtang'),
                      subtitle: l10n.text('creditUtangSubtitle'),
                      destination: const CreditScreen(),
                    ),
                    _MenuEntry(
                      icon: Icons.settings_outlined,
                      title: l10n.text('settings'),
                      subtitle: l10n.text('settingsMenuSubtitle'),
                      destination: const SettingsScreen(),
                    ),
                  ]),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: sari.cardSurfaceStrong.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sari.glassBorder,
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _editButton(String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openEditProfile,
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: sari.warning, width: 1.3),
            ),
            child: Icon(
              Icons.edit_outlined,
              size: 16,
              color: sari.warning,
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sari.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storefront_outlined, size: 13, color: sari.success),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: sari.success,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: sari.mutedText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuGroup(List<_MenuEntry> entries) {
    return Container(
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
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                _menuRow(entries[i]),
                if (i < entries.length - 1)
                  Divider(
                    color: sari.glassBorder.withValues(alpha: 0.6),
                    height: 1,
                    thickness: 1,
                    indent: 62,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(_MenuEntry entry) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => entry.destination),
        );
        if (mounted) await _fetchUserData();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sari.success.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(entry.icon, color: sari.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sari.mutedText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: sari.warning,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}