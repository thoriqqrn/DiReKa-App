import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_log_entry.dart';

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

  /// Ambil semua entri makanan untuk [uid] pada [date].
  static Future<List<FoodLogEntry>> getEntries(
      String uid, DateTime date) async {
    final doc =
        await _db.collection('food_logs').doc(_docId(uid, date)).get();
    if (!doc.exists) return [];
    final entries = doc.data()!['entries'] as List<dynamic>? ?? [];
    return entries
        .map((e) => FoodLogEntry.fromMap(e as Map<String, dynamic>))
        .toList();
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
  }
}
