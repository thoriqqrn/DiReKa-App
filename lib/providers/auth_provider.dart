import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/activity_level.dart';
import '../models/hemodialysis_data.dart';
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
  List<LinkedFamilyAccount> _linkedFamilyAccounts = [];
  StreamSubscription<UserModel?>? _userModelSubscription;

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  UserModel? get currentUser => _userModel; // alias untuk kemudahan akses
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isNewGoogleUser => _isNewGoogleUser;
  List<LinkedFamilyAccount> get linkedFamilyAccounts => _linkedFamilyAccounts;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;
      try {
        if (user != null) {
          await _loadUserModel(user.uid);
          _listenUserModel(user.uid);
          await loadLinkedFamilyAccounts();
          if (_userModel != null) {
            await _authService.syncLinkedFamilyAllData(_userModel!);
          }
          _status = AuthStatus.authenticated;
          // Update day streak saat user login
          await _updateDayStreak();
        } else {
          await _userModelSubscription?.cancel();
          _userModelSubscription = null;
          _userModel = null;
          _linkedFamilyAccounts = [];
          _status = AuthStatus.unauthenticated;
        }
      } catch (e) {
        // Jangan biarkan status tetap "initial" karena bisa bikin splash freeze.
        _userModel = null;
          _linkedFamilyAccounts = [];
        _errorMessage =
            'Gagal memuat profil pengguna. Periksa izin Firestore (users/{uid}).';
        _status = user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      }
      notifyListeners();
    }, onError: (_) {
      _userModel = null;
      _linkedFamilyAccounts = [];
      _errorMessage = 'Terjadi kesalahan pada autentikasi.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  Future<void> _loadUserModel(String uid) async {
    _userModel = await _userService.getUser(uid);
  }

  void _listenUserModel(String uid) {
    _userModelSubscription?.cancel();
    _userModelSubscription = _userService.userStream(uid).listen((user) {
      if (user != null) {
        _userModel = user;
        notifyListeners();
      }
    });
  }

  /// Update day streak: increment jika login hari ini, reset jika kemarin tidak login
  Future<void> _updateDayStreak() async {
    if (_userModel == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastLogin = _userModel!.lastLoginDate;
    final yesterday = today.subtract(const Duration(days: 1));

    int newStreak = _userModel!.currentStreak;
    int newLongest = _userModel!.longestStreak;
    List<DateTime> updatedLogins = [..._userModel!.loginDates];

    // Cek apakah sudah login hari ini
    final hasLoginToday =
        lastLogin != null &&
        lastLogin.year == today.year &&
        lastLogin.month == today.month &&
        lastLogin.day == today.day;

    if (!hasLoginToday) {
      // Belum login hari ini
      if (lastLogin != null &&
          lastLogin.year == yesterday.year &&
          lastLogin.month == yesterday.month &&
          lastLogin.day == yesterday.day) {
        // Login kemarin → increment streak
        newStreak++;
      } else {
        // Tidak login kemarin atau pertama kali → reset streak ke 1
        newStreak = 1;
      }

      // Update longest streak jika perlu
      if (newStreak > newLongest) {
        newLongest = newStreak;
      }

      // Tambah hari ini ke loginDates
      updatedLogins.add(today);

      // Update userModel
      final updated = _userModel!.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongest,
        lastLoginDate: today,
        loginDates: updatedLogins,
      );

      // Simpan ke Firestore
      await _userService.updateUser(updated);
      _userModel = updated;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      final credential = await _authService.loginWithEmail(
        email: email,
        password: password,
      );
      // Pastikan userModel ter-load sebelum navigasi — authStateChanges
      // listener berjalan async dan mungkin belum selesai saat login() return.
      final uid = credential.user?.uid;
      if (uid != null) {
        await _loadUserModel(uid);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginAdmin({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.loginAdmin(email: email, password: password);
      _isLoading = false;
      notifyListeners();
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
    String addressVillage = '',
    String addressDistrict = '',
    String addressCity = '',
    String addressProvince = '',
    String education = '',
    String occupation = '',
    required DateTime dateOfBirth,
    required double weight,
    required double height,
    required DiseaseType diseaseType,
    String gender = 'laki-laki',
    double urinOutput = 300.0,
    ActivityLevel? activityLevel,
    double diabetesDurationYears = 0.0,
    double heartDiseaseDurationYears = 0.0,
    bool usesInsulinTherapy = false,
    double insulinDurationYears = 0.0,
    HemodialysisData? hemodialysisData,
    bool hasEdema = false,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        addressVillage: addressVillage,
        addressDistrict: addressDistrict,
        addressCity: addressCity,
        addressProvince: addressProvince,
        education: education,
        occupation: occupation,
        dateOfBirth: dateOfBirth,
        weight: weight,
        height: height,
        diseaseType: diseaseType,
        gender: gender,
        urinOutput: urinOutput,
        activityLevel: activityLevel,
        diabetesDurationYears: diabetesDurationYears,
        heartDiseaseDurationYears: heartDiseaseDurationYears,
        usesInsulinTherapy: usesInsulinTherapy,
        insulinDurationYears: insulinDurationYears,
        hemodialysisData: hemodialysisData,
        hasEdema: hasEdema,
      );
      // Fix race condition: authStateChanges listener fires BEFORE saveUser()
      // completes inside registerWithEmail(), sehingga _userModel = null.
      // Setelah registerWithEmail() return, saveUser() sudah selesai — reload.
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        await _loadUserModel(uid);
      }
      _isLoading = false;
      notifyListeners();
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
    } catch (e) {
      _setError(_mapGoogleSignInError(e));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> completeGoogleProfile({
    required DiseaseType diseaseType,
    required DateTime dateOfBirth,
    required double weight,
    required double height,
    String addressVillage = '',
    String addressDistrict = '',
    String addressCity = '',
    String addressProvince = '',
    String education = '',
    String occupation = '',
    String gender = 'laki-laki',
    ActivityLevel? activityLevel,
    double diabetesDurationYears = 0.0,
    double heartDiseaseDurationYears = 0.0,
    bool usesInsulinTherapy = false,
    double insulinDurationYears = 0.0,
    HemodialysisData? hemodialysisData,
    bool hasEdema = false,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final user = _firebaseUser!;
      final userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Pengguna',
        email: user.email ?? '',
        addressVillage: addressVillage,
        addressDistrict: addressDistrict,
        addressCity: addressCity,
        addressProvince: addressProvince,
        education: education,
        occupation: occupation,
        gender: gender,
        diseaseType: diseaseType,
        dateOfBirth: dateOfBirth,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
        diabetesDurationYears: diabetesDurationYears,
        heartDiseaseDurationYears: heartDiseaseDurationYears,
        usesInsulinTherapy: usesInsulinTherapy,
        insulinDurationYears: insulinDurationYears,
        hemodialysisData: hemodialysisData,
        hasEdema: hasEdema,
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
    await _userModelSubscription?.cancel();
    _userModelSubscription = null;
    _userModel = null;
    _linkedFamilyAccounts = [];
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> loadLinkedFamilyAccounts() async {
    final uid = _firebaseUser?.uid;
    if (uid == null) {
      _linkedFamilyAccounts = [];
      notifyListeners();
      return;
    }
    try {
      _linkedFamilyAccounts = await _authService.getLinkedFamilyAccounts(uid);
      notifyListeners();
    } catch (_) {
      _linkedFamilyAccounts = [];
      notifyListeners();
    }
  }

  Future<bool> createFamilyAccount({
    required String familyName,
    required String familyEmail,
    required String familyPassword,
  }) async {
    if (_userModel == null) {
      _setError('Akun utama belum siap. Coba lagi.');
      return false;
    }
    _setLoading(true);
    _clearError();
    try {
      await _authService.createFamilyLinkedAccount(
        primaryUser: _userModel!,
        familyName: familyName,
        familyEmail: familyEmail,
        familyPassword: familyPassword,
      );
      await loadLinkedFamilyAccounts();
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Gagal membuat akun keluarga. Coba lagi.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfile(UserModel updated) async {
    _setLoading(true);
    _clearError();
    try {
      await _userService.updateUser(updated);
      await _authService.syncLinkedFamilyAllData(updated);
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

  @override
  void dispose() {
    _userModelSubscription?.cancel();
    super.dispose();
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
      case 'popup-closed-by-user':
        return 'Login Google dibatalkan sebelum selesai.';
      case 'account-exists-with-different-credential':
        return 'Email ini sudah terdaftar dengan metode login lain.';
      default:
        return 'Terjadi kesalahan. Coba lagi.';
    }
  }

  String _mapGoogleSignInError(Object error) {
    final raw = error.toString();
    final message = raw.toLowerCase();

    if (message.contains('apiexception: 10') ||
        message.contains('developer_error')) {
      return 'Google Sign-In gagal karena konfigurasi OAuth Android belum sesuai (SHA-1/SHA-256).';
    }
    if (message.contains('12500') || message.contains('sign_in_failed')) {
      return 'Google Sign-In ditolak oleh konfigurasi OAuth. Cek client ID dan SHA aplikasi.';
    }
    if (message.contains('network_error') ||
        message.contains('network-request-failed')) {
      return 'Tidak ada koneksi internet saat login Google.';
    }
    if (message.contains('popup_closed') ||
        message.contains('popup-closed-by-user')) {
      return 'Login Google dibatalkan sebelum selesai.';
    }
    if (message.contains('10.0.2.2') ||
        message.contains('localhost') ||
        message.contains('unauthorized-domain')) {
      return 'Domain aplikasi belum diizinkan pada Firebase Authentication (Authorized domains).';
    }

    return 'Login dengan Google gagal: $raw';
  }
}
