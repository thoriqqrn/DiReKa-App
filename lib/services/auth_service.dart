import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/app_constants.dart';
import '../models/activity_level.dart';
import '../models/disease_type.dart';
import '../models/hemodialysis_data.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class LinkedFamilyAccount {
  final String uid;
  final String name;
  final String email;
  final DateTime? lastLoginDate;
  final bool isActive;

  const LinkedFamilyAccount({
    required this.uid,
    required this.name,
    required this.email,
    this.lastLoginDate,
    required this.isActive,
  });
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '742908514617-ra79b46g0r4onfuvhdkj19nv9bpriv9i.apps.googleusercontent.com'
        : null,
  );
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

  // Login admin dengan email & password
  Future<UserCredential> loginAdmin({
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
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user?.updateDisplayName(name);

    final userModel = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email.trim(),
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
      urinOutput: urinOutput,
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

  Future<void> createFamilyLinkedAccount({
    required UserModel primaryUser,
    required String familyName,
    required String familyEmail,
    required String familyPassword,
  }) async {
    final defaultApp = Firebase.app();
    final appName =
        'direka-family-${DateTime.now().microsecondsSinceEpoch.toString()}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: defaultApp.options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: familyEmail.trim(),
        password: familyPassword,
      );

      await credential.user?.updateDisplayName(familyName);

      final familyUid = credential.user!.uid;
      final familyUser = UserModel(
        uid: familyUid,
        name: familyName,
        email: familyEmail.trim(),
        addressVillage: primaryUser.addressVillage,
        addressDistrict: primaryUser.addressDistrict,
        addressCity: primaryUser.addressCity,
        addressProvince: primaryUser.addressProvince,
        education: primaryUser.education,
        occupation: primaryUser.occupation,
        gender: primaryUser.gender,
        diseaseType: primaryUser.diseaseType,
        dateOfBirth: primaryUser.dateOfBirth,
        weight: primaryUser.weight,
        height: primaryUser.height,
        urinOutput: primaryUser.urinOutput,
        activityLevel: primaryUser.activityLevel,
        diabetesDurationYears: primaryUser.diabetesDurationYears,
        heartDiseaseDurationYears: primaryUser.heartDiseaseDurationYears,
        usesInsulinTherapy: primaryUser.usesInsulinTherapy,
        hemodialysisData: primaryUser.hemodialysisData,
        hasEdema: primaryUser.hasEdema,
        createdAt: DateTime.now(),
      );
      await _userService.saveUser(familyUser);

      final db = FirebaseFirestore.instance;
      await db
          .collection(AppConstants.colUsers)
          .doc(primaryUser.uid)
          .collection('family_accounts')
          .doc(familyUid)
          .set({
            'familyUid': familyUid,
            'name': familyName,
            'email': familyEmail.trim(),
            'status': 'active',
            'createdAt': Timestamp.now(),
          }, SetOptions(merge: true));

      await db.collection(AppConstants.colUsers).doc(familyUid).set({
        'linkedPrimaryUid': primaryUser.uid,
        'isFamilyAccount': true,
      }, SetOptions(merge: true));

      await _copyInitialHealthData(
        primaryUid: primaryUser.uid,
        familyUid: familyUid,
      );
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  Future<List<LinkedFamilyAccount>> getLinkedFamilyAccounts(
    String primaryUid,
  ) async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection(AppConstants.colUsers)
        .doc(primaryUid)
        .collection('family_accounts')
        .orderBy('createdAt', descending: true)
        .get();

    final result = <LinkedFamilyAccount>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      final uid = (data['familyUid'] ?? doc.id).toString();

      final familyUserSnap = await db
          .collection(AppConstants.colUsers)
          .doc(uid)
          .get();
      final userData = familyUserSnap.data() ?? <String, dynamic>{};

      final name = (userData['name'] ?? data['name'] ?? 'Akun keluarga')
          .toString();
      final email = (userData['email'] ?? data['email'] ?? '-').toString();
      final lastLogin = userData['lastLoginDate'] is Timestamp
          ? (userData['lastLoginDate'] as Timestamp).toDate()
          : null;

      result.add(
        LinkedFamilyAccount(
          uid: uid,
          name: name,
          email: email,
          lastLoginDate: lastLogin,
          isActive: familyUserSnap.exists,
        ),
      );
    }

    return result;
  }

  Future<void> syncLinkedFamilyProfiles(UserModel primaryUser) async {
    final db = FirebaseFirestore.instance;
    final familySnap = await db
        .collection(AppConstants.colUsers)
        .doc(primaryUser.uid)
        .collection('family_accounts')
        .get();

    if (familySnap.docs.isEmpty) return;

    final mirroredProfileData = {
      'addressVillage': primaryUser.addressVillage,
      'addressDistrict': primaryUser.addressDistrict,
      'addressCity': primaryUser.addressCity,
      'addressProvince': primaryUser.addressProvince,
      'education': primaryUser.education,
      'occupation': primaryUser.occupation,
      'gender': primaryUser.gender,
      'diseaseType': primaryUser.diseaseType.value,
      'dateOfBirth': Timestamp.fromDate(primaryUser.dateOfBirth),
      'weight': primaryUser.weight,
      'height': primaryUser.height,
      'urinOutput': primaryUser.urinOutput,
      'activityLevel': primaryUser.activityLevel?.value,
      'diabetesDurationYears': primaryUser.diabetesDurationYears,
      'heartDiseaseDurationYears': primaryUser.heartDiseaseDurationYears,
      'usesInsulinTherapy': primaryUser.usesInsulinTherapy,
      'hemodialysisData': primaryUser.hemodialysisData?.toMap(),
      'hasEdema': primaryUser.hasEdema,
      'bmi': double.parse(primaryUser.bmi.toStringAsFixed(2)),
      'bbi': double.parse(primaryUser.bbi.toStringAsFixed(2)),
      'linkedPrimaryUid': primaryUser.uid,
      'isFamilyAccount': true,
      'mirroredAt': Timestamp.now(),
    };

    final batch = db.batch();
    for (final doc in familySnap.docs) {
      final familyUid = (doc.data()['familyUid'] ?? doc.id).toString();
      final ref = db.collection(AppConstants.colUsers).doc(familyUid);
      batch.set(ref, mirroredProfileData, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> syncLinkedFamilyAllData(UserModel primaryUser) async {
    final db = FirebaseFirestore.instance;
    final familySnap = await db
        .collection(AppConstants.colUsers)
        .doc(primaryUser.uid)
        .collection('family_accounts')
        .where('status', isEqualTo: 'active')
        .get();

    if (familySnap.docs.isEmpty) return;

    await syncLinkedFamilyProfiles(primaryUser);

    for (final doc in familySnap.docs) {
      final familyUid = (doc.data()['familyUid'] ?? doc.id).toString();
      if (familyUid.isEmpty) continue;
      await _copyInitialHealthData(
        primaryUid: primaryUser.uid,
        familyUid: familyUid,
      );
    }
  }

  Future<void> _copyInitialHealthData({
    required String primaryUid,
    required String familyUid,
  }) async {
    final db = FirebaseFirestore.instance;

    Future<void> copyUserSubcollection(String subcollection) async {
      final snap = await db
          .collection(AppConstants.colUsers)
          .doc(primaryUid)
          .collection(subcollection)
          .get();
      if (snap.docs.isEmpty) return;

      final batch = db.batch();
      for (final doc in snap.docs) {
        final ref = db
            .collection(AppConstants.colUsers)
            .doc(familyUid)
            .collection(subcollection)
            .doc(doc.id);
        batch.set(ref, doc.data());
      }
      await batch.commit();
    }

    await copyUserSubcollection('kidney_health_records');
    await copyUserSubcollection('heart_health_records');
    await copyUserSubcollection('diabetes_health_records');

    final foodSnap = await db
        .collection('food_logs')
        .where('uid', isEqualTo: primaryUid)
        .get();

    if (foodSnap.docs.isNotEmpty) {
      final batch = db.batch();
      for (final doc in foodSnap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final dateStr = (data['date'] ?? '').toString();
        if (dateStr.isEmpty) continue;
        data['uid'] = familyUid;

        final familyDocId = '${familyUid}_$dateStr';
        batch.set(db.collection('food_logs').doc(familyDocId), data);
      }
      await batch.commit();
    }
  }
}
