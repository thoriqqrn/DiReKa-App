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

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  UserModel? get currentUser => _userModel; // alias untuk kemudahan akses
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
        // Update day streak saat user login
        await _updateDayStreak();
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
    final hasLoginToday = lastLogin != null &&
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
          email: email, password: password);
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

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required DateTime dateOfBirth,
    required double weight,
    required double height,
    required DiseaseType diseaseType,
    String gender = 'laki-laki',
    double urinOutput = 300.0,
    ActivityLevel? activityLevel,
    HemodialysisData? hemodialysisData,
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
        gender: gender,
        urinOutput: urinOutput,
        activityLevel: activityLevel,
        hemodialysisData: hemodialysisData,
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
    String gender = 'laki-laki',
    ActivityLevel? activityLevel,
    HemodialysisData? hemodialysisData,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final user = _firebaseUser!;
      final userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'Pengguna',
        email: user.email ?? '',
        gender: gender,
        diseaseType: diseaseType,
        dateOfBirth: dateOfBirth,
        weight: weight,
        height: height,
        activityLevel: activityLevel,
        hemodialysisData: hemodialysisData,
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
