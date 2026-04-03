import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/activity_level.dart';
import '../models/disease_type.dart';
import '../models/hemodialysis_data.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login dengan email & password
  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Register dengan email & password
  Future<UserCredential> registerWithEmail({
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
    bool hasEdema = false,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user?.updateDisplayName(name);

    final userModel = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email.trim(),
      gender: gender,
      diseaseType: diseaseType,
      dateOfBirth: dateOfBirth,
      weight: weight,
      height: height,
      urinOutput: urinOutput,
      activityLevel: activityLevel,
      hemodialysisData: hemodialysisData,
      hasEdema: hasEdema,
      createdAt: DateTime.now(),
    );
    await _userService.saveUser(userModel);

    return credential;
  }

  // Login dengan Google - hanya autentikasi, data profil diisi terpisah
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // Logout
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Reset password
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
