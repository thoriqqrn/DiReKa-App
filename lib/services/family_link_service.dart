import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_constants.dart';

class FamilyLinkService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> resolvePrimaryUid(String uid) async {
    final userDoc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};
    final linkedPrimaryUid = (data['linkedPrimaryUid'] ?? '').toString();
    if (linkedPrimaryUid.isNotEmpty) return linkedPrimaryUid;
    return uid;
  }

  static Future<List<String>> getLinkedFamilyUids(String primaryUid) async {
    final snap = await _db
        .collection(AppConstants.colUsers)
        .doc(primaryUid)
        .collection('family_accounts')
        .where('status', isEqualTo: 'active')
        .get();

    return snap.docs
        .map((d) => (d.data()['familyUid'] ?? d.id).toString())
        .where((uid) => uid.isNotEmpty)
        .toList();
  }

  static Future<List<String>> getLinkedGroupUids(String anyUid) async {
    final primaryUid = await resolvePrimaryUid(anyUid);
    final family = await getLinkedFamilyUids(primaryUid);
    final all = <String>{primaryUid, ...family};
    return all.toList();
  }

  static Future<void> mirrorUserSubcollectionWrite({
    required String sourceUid,
    required String subcollection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final groupUids = await getLinkedGroupUids(sourceUid);
    if (groupUids.length <= 1) return;

    final batch = _db.batch();
    for (final targetUid in groupUids) {
      if (targetUid == sourceUid) continue;
      final ref = _db
          .collection(AppConstants.colUsers)
          .doc(targetUid)
          .collection(subcollection)
          .doc(docId);
      batch.set(ref, data, SetOptions(merge: true));
    }
    await batch.commit();
  }

  static Future<void> mirrorUserSubcollectionDelete({
    required String sourceUid,
    required String subcollection,
    required String docId,
  }) async {
    final groupUids = await getLinkedGroupUids(sourceUid);
    if (groupUids.length <= 1) return;

    final batch = _db.batch();
    for (final targetUid in groupUids) {
      if (targetUid == sourceUid) continue;
      final ref = _db
          .collection(AppConstants.colUsers)
          .doc(targetUid)
          .collection(subcollection)
          .doc(docId);
      batch.delete(ref);
    }
    await batch.commit();
  }
}
