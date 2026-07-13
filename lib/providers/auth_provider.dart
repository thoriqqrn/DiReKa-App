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
          _status = AuthStatus.loading;
          notifyListeners();

          await _loadUserModel(
            user.uid,
          ).timeout(const Duration(seconds: 10), onTimeout: () {});
          _listenUserModel(user.uid);
          _status = AuthStatus.authenticated;
          notifyListeners();

          unawaited(_postLoginBootstrap());
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

  Future<void> _postLoginBootstrap() async {
    try {
      await loadLinkedFamilyAccounts().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      if (_userModel != null) {
        await _authService.syncLinkedFamilyAllData(_userModel!).timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
      }
    } catch (_) {
      // Sinkronisasi tambahan gagal tidak boleh memblokir login utama.
    }
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

  /// Update streak hanya saat ada aktivitas input (makanan/health).
  /// PERMINTAAN KLIEN: Streak tidak boleh di-reset, berfungsi sebagai "Total Hari Aktif".
  /// Selama belum pernah ada aktivitas di hari yang sama, count akan terus bertambah +1.
  Future<void> _updateDayStreak() async {
    if (_userModel == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Periksa apakah 'today' sudah ada di dalam loginDates (riwayat hari aktif)
    // loginDates menyimpan tanggal-tanggal unik saat pengguna melakukan input.
    final hasActivityToday = _userModel!.loginDates.any((d) => 
        d.year == today.year && d.month == today.month && d.day == today.day);

    if (hasActivityToday) {
      // Sudah ada aktivitas input hari ini, jangan tambah hitungan.
      return;
    }

    int newStreak = _userModel!.currentStreak + 1;
    // longestStreak bisa kita samakan saja dengan currentStreak
    // karena tidak ada reset, angka keduanya akan selalu sama dan terus naik.
    int newLongest = newStreak;
    
    List<DateTime> updatedLogins = [..._userModel!.loginDates, today];

    final updated = _userModel!.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastLoginDate: today,
      loginDates: updatedLogins,
    );

    await _userService.updateUser(updated);
    _userModel = updated;
    notifyListeners();
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
    double hypertensionDurationYears = 0.0,
    bool hypertensionFamilyHistory = false,
    bool hypertensionRoutineMeds = false,
    bool isPregnant = false,
    int pregnancyTrimester = 0,
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
        hypertensionDurationYears: hypertensionDurationYears,
        hypertensionFamilyHistory: hypertensionFamilyHistory,
        hypertensionRoutineMeds: hypertensionRoutineMeds,
        isPregnant: isPregnant,
        pregnancyTrimester: pregnancyTrimester,
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
    double hypertensionDurationYears = 0.0,
    bool hypertensionFamilyHistory = false,
    bool hypertensionRoutineMeds = false,
    bool isPregnant = false,
    int pregnancyTrimester = 0,
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
        hypertensionDurationYears: hypertensionDurationYears,
        hypertensionFamilyHistory: hypertensionFamilyHistory,
        hypertensionRoutineMeds: hypertensionRoutineMeds,
        isPregnant: isPregnant,
        pregnancyTrimester: pregnancyTrimester,
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

  /// Alias for _updateDayStreak to be used by trackers
  Future<void> updateActivityStreak() async {
    await _updateDayStreak();
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

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.changeCurrentUserPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapPasswordChangeError(e.code));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Gagal mengubah kata sandi. Coba lagi.');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.sendPasswordResetEmailWithTemplate(email.trim());
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapPasswordResetRequestError(e.code));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Gagal mengirim link reset password. Coba lagi.');
      _setLoading(false);
      return false;
    }
  }

  Future<String?> verifyResetPasswordCode(String code) async {
    _setLoading(true);
    _clearError();
    try {
      final email = await _authService.verifyPasswordResetCode(code);
      _setLoading(false);
      return email;
    } on FirebaseAuthException catch (e) {
      _setError(_mapPasswordResetActionError(e.code));
      _setLoading(false);
      return null;
    } catch (_) {
      _setError('Link reset password tidak valid atau sudah kedaluwarsa.');
      _setLoading(false);
      return null;
    }
  }

  Future<bool> confirmResetPassword({
    required String code,
    required String newPassword,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapPasswordResetActionError(e.code));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError('Gagal menyimpan password baru. Coba lagi.');
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

  String _mapPasswordChangeError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Kata sandi saat ini tidak sesuai.';
      case 'weak-password':
        return 'Kata sandi baru terlalu lemah (minimal 6 karakter).';
      case 'requires-recent-login':
        return 'Sesi login sudah lama. Silakan login ulang lalu coba lagi.';
      case 'operation-not-allowed':
        return 'Akun ini tidak mendukung ubah password email/password.';
      case 'user-not-found':
        return 'Akun tidak ditemukan. Silakan login ulang.';
      default:
        return 'Gagal mengubah kata sandi. Coba lagi.';
    }
  }

  String _mapPasswordResetRequestError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'too-many-requests':
        return 'Terlalu banyak permintaan. Coba lagi beberapa saat lagi.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      default:
        return 'Gagal mengirim link reset password. Coba lagi.';
    }
  }

  String _mapPasswordResetActionError(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'Link reset password sudah kedaluwarsa.';
      case 'invalid-action-code':
        return 'Link reset password tidak valid.';
      case 'weak-password':
        return 'Password baru terlalu lemah. Gunakan minimal 6 karakter.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan.';
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      default:
        return 'Proses reset password gagal. Coba lagi.';
    }
  }
}
