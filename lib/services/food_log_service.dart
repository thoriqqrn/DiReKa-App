import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/food_log_entry.dart';
import 'family_link_service.dart';

/// Service untuk menyimpan dan membaca log makanan harian ke Firestore.
///
/// Struktur Firestore:
/// food_logs/{uid_YYYY-MM-DD}
///   uid: string
///   date: string (YYYY-MM-DD)
///   entries: List<Map> — array of FoodLogEntry
class FoodLogService {
  static final _db = FirebaseFirestore.instance;

  static String _docId(String uid, DateTime date) {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${uid}_$d';
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _mirrorFoodLogToLinkedGroup(String uid, DateTime date) async {
    final groupUids = await FamilyLinkService.getLinkedGroupUids(uid);
    if (groupUids.length <= 1) return;

    final primaryDoc = await _db.collection('food_logs').doc(_docId(uid, date)).get();
    final dateStr = _dateKey(date);

    final batch = _db.batch();
    for (final targetUid in groupUids) {
      if (targetUid == uid) continue;
      final familyRef = _db.collection('food_logs').doc('${targetUid}_$dateStr');
      if (!primaryDoc.exists) {
        batch.delete(familyRef);
      } else {
        final data = Map<String, dynamic>.from(primaryDoc.data() ?? {});
        data['uid'] = targetUid;
        data['date'] = dateStr;
        batch.set(familyRef, data);
      }
    }
    await batch.commit();
  }

  /// Ambil semua entri makanan untuk [uid] pada [date].
  static Future<List<FoodLogEntry>> getEntries(
      String uid, DateTime date) async {
    try {
      final doc =
          await _db.collection('food_logs').doc(_docId(uid, date)).get();
      if (!doc.exists) return [];
      final entries = doc.data()!['entries'] as List<dynamic>? ?? [];
      return entries
          .map((e) => FoodLogEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('FoodLogService.getEntries error: ${e.code} ${e.message}');
      // Saat backend unavailable, kembalikan list kosong agar UI tidak crash.
      return [];
    }
  }

  /// Tambah satu entri makanan ke log hari [date].
  static Future<void> addEntry(
      String uid, DateTime date, FoodLogEntry entry) async {
    final docRef = _db.collection('food_logs').doc(_docId(uid, date));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {
          'uid': uid,
          'date': _docId(uid, date).split('_').last,
          'entries': [entry.toMap()],
        });
      } else {
        final entries =
            List<dynamic>.from(snap.data()!['entries'] as List? ?? []);
        entries.add(entry.toMap());
        tx.update(docRef, {'entries': entries});
      }
    });
    await _mirrorFoodLogToLinkedGroup(uid, date);
  }

  /// Hapus entri dengan [entryId] dari log hari [date].
  static Future<void> deleteEntry(
      String uid, DateTime date, String entryId) async {
    final docRef = _db.collection('food_logs').doc(_docId(uid, date));
    final snap = await docRef.get();
    if (!snap.exists) return;
    final entries =
        List<dynamic>.from(snap.data()!['entries'] as List? ?? []);
    entries.removeWhere(
        (e) => (e as Map<String, dynamic>)['id'] == entryId);
    await docRef.update({'entries': entries});
    await _mirrorFoodLogToLinkedGroup(uid, date);
  }

  /// Tambah banyak entri makanan sekaligus ke log hari [date] dalam satu transaksi.
  /// Digunakan oleh sistem keranjang (cart) untuk batch-submit.
  static Future<void> addEntries(
      String uid, DateTime date, List<FoodLogEntry> newEntries) async {
    if (newEntries.isEmpty) return;
    final docRef = _db.collection('food_logs').doc(_docId(uid, date));
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        tx.set(docRef, {
          'uid': uid,
          'date': _docId(uid, date).split('_').last,
          'entries': newEntries.map((e) => e.toMap()).toList(),
        });
      } else {
        final entries =
            List<dynamic>.from(snap.data()!['entries'] as List? ?? []);
        for (final entry in newEntries) {
          entries.add(entry.toMap());
        }
        tx.update(docRef, {'entries': entries});
      }
    });
    await _mirrorFoodLogToLinkedGroup(uid, date);
  }

  /// Update entri yang sudah ada (cari berdasarkan id, replace datanya).
  static Future<void> updateEntry(
      String uid, DateTime date, FoodLogEntry updated) async {
    final docRef = _db.collection('food_logs').doc(_docId(uid, date));
    final snap = await docRef.get();
    if (!snap.exists) return;
    final entries =
        List<dynamic>.from(snap.data()!['entries'] as List? ?? []);
    final idx = entries.indexWhere(
        (e) => (e as Map<String, dynamic>)['id'] == updated.id);
    if (idx == -1) return;
    entries[idx] = updated.toMap();
    await docRef.update({'entries': entries});
    await _mirrorFoodLogToLinkedGroup(uid, date);
  }
}
