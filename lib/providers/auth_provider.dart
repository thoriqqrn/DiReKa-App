import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/disease_type.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  AuthStatus _status = AuthStatus.initial;
  User? _firebaseUser;
  UserModel? _userModel;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isNewGoogleUser = false;

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isNewGoogleUser => _isNewGoogleUser;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;
      if (user != null) {
        await _loadUserModel(user.uid);
        _status = AuthStatus.authenticated;
      } else {
        _userModel = null;
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModel(String uid) async {
    _userModel = await _userService.getUser(uid);
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.loginWithEmail(email: email, password: password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required DateTime dateOfBirth,
    required double weight,
    required double height,
    required DiseaseType diseaseType,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        dateOfBirth: dateOfBirth,
        weight: weight,
        height: height,
        diseaseType: diseaseType,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _clearError();
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        _setLoading(false);
        return false;
      }
      _isNewGoogleUser = result.additionalUserInfo?.isNewUser == true;
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Login dengan Google gagal. Coba lagi.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> completeGoogleProfile({
    required DiseaseType diseaseType,
    required DateTime dateOfBirth,
    required double weight,
    required double height,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final user = _firebaseUser!;
      final userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Pengguna',
        email: user.email ?? '',
        diseaseType: diseaseType,
        dateOfBirth: dateOfBirth,
        weight: weight,
        height: height,
        createdAt: DateTime.now(),
      );
      await _userService.saveUser(userModel);
      _userModel = userModel;
      _isNewGoogleUser = false;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (_) {
      _setError('Gagal menyimpan profil. Coba lagi.');
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> updateProfile(UserModel updated) async {
    _setLoading(true);
    _clearError();
    try {
      await _userService.updateUser(updated);
      _userModel = updated;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (_) {
      _setError('Gagal memperbarui profil. Coba lagi.');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() => _clearError();

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan. Periksa email Anda.';
      case 'wrong-password':
        return 'Kata sandi salah. Coba lagi.';
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'email-already-in-use':
        return 'Email sudah digunakan oleh akun lain.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba beberapa saat lagi.';
      default:
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }
}
