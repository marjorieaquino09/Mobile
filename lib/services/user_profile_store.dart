import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Shared signed-in user profile for Home / Inventory headers (and elsewhere).
class UserProfileStore extends ChangeNotifier {
  UserProfileStore._();
  static final UserProfileStore instance = UserProfileStore._();

  String _displayName = '';
  String _storeName = '';
  String _photoUrl = '';
  String _username = '';
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String? _uid;

  String get displayName => _displayName;
  String get storeName => _storeName;
  String get photoUrl => _photoUrl;
  String get username => _username;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Prefer full name; fall back to username / Auth displayName.
  String get headerName {
    if (_displayName.isNotEmpty) return _displayName;
    if (_username.isNotEmpty) return _username;
    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;
    return 'User';
  }

  String get headerStoreName {
    if (_storeName.isNotEmpty) return _storeName;
    return 'Sari-Sari Store';
  }

  Future<void> ensureLoaded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _resetLocal();
      notifyListeners();
      return;
    }
    if (_loaded && _uid == user.uid && _error == null) return;
    await reload();
  }

  Future<void> reload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _resetLocal();
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    _uid = user.uid;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        _displayName = user.displayName?.trim() ?? '';
        _username = '';
        _storeName = '';
        _photoUrl = '';
        _loaded = true;
        _loading = false;
        _error = null;
        notifyListeners();
        return;
      }

      final data = doc.data()!;
      
      // Binabasa na ang web fields ('full_name', 'store_name', 'profile_image')
      final rawFullName = (data['full_name'] ?? '').toString().trim();
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      
      final fullName = rawFullName.isNotEmpty 
          ? rawFullName 
          : [firstName, lastName].where((part) => part.isNotEmpty).join(' ');

      final username = (data['username'] ?? '').toString().trim();
      final store = (data['store_name'] ?? data['storeName'] ?? '').toString().trim();
      final photo = (data['profile_image'] ?? data['photoUrl'] ?? '').toString().trim();

      _displayName = fullName.isNotEmpty
          ? fullName
          : (username.isNotEmpty ? username : (user.displayName?.trim() ?? ''));
      _username = username;
      _storeName = store;
      _photoUrl = photo;
      _loaded = true;
      _loading = false;
      _error = null;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[UserProfileStore] load failed: $e\n$st');
      _displayName = user.displayName?.trim() ?? '';
      _username = '';
      _storeName = '';
      _photoUrl = '';
      _loaded = true;
      _loading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  void clear() {
    _resetLocal();
    notifyListeners();
  }

  void _resetLocal() {
    _displayName = '';
    _storeName = '';
    _photoUrl = '';
    _username = '';
    _loading = false;
    _loaded = false;
    _error = null;
    _uid = null;
  }
}