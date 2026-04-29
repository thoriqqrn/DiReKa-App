import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection(AppConstants.colUsers);

  Future<void> saveUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _users
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 10));
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    } on TimeoutException {
      // Fallback ke cache agar bootstrap auth tidak menggantung.
      final cachedDoc = await _users
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (!cachedDoc.exists) return null;
      return UserModel.fromMap(cachedDoc.data() as Map<String, dynamic>);
    } on FirebaseException catch (e) {
      debugPrint('UserService.getUser FirebaseException: ${e.code} ${e.message}');
      rethrow;
    }
  }

  Future<void> updateUser(UserModel user) async {
    final data = user.toMap();
    // Selalu update field yang bisa berubah
    data['bmi'] = double.parse(user.bmi.toStringAsFixed(2));
    await _users.doc(user.uid).update(data);
  }

  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }
}
