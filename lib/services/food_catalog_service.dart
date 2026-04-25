import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';

/// Service untuk mengelola katalog makanan kustom admin via Firestore.
/// Data disimpan di koleksi 'food_catalog' dengan ID dokumen = FoodItem.id.
class FoodCatalogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _catalog =>
      _db.collection('food_catalog');

  /// Buat ID unik untuk makanan baru berdasarkan timestamp.
  String createFoodId() {
    return 'custom_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Simpan atau perbarui [food] ke Firestore.
  /// Jika [markAsCustom] = true, tambahkan field 'isCustom: true' dan
  /// 'createdAt' ke dokumen.
  Future<void> upsertFood(FoodItem food, {bool markAsCustom = false}) async {
    final data = food.toJson();
    if (markAsCustom) {
      data['isCustom'] = true;
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _catalog.doc(food.id).set(data, SetOptions(merge: true));
  }

  /// Bulk upsert daftar [foods] ke Firestore menggunakan batched writes.
  /// [onProgress] dipanggil setiap batch selesai dengan jumlah item yang sudah diproses.
  Future<void> bulkUpsertFoods(
    List<FoodItem> foods, {
    bool markAsCustom = true,
    void Function(int processed, int total)? onProgress,
  }) async {
    const batchSize = 400;
    for (var i = 0; i < foods.length; i += batchSize) {
      final batch = _db.batch();
      final end = (i + batchSize).clamp(0, foods.length);
      for (var j = i; j < end; j++) {
        final data = foods[j].toJson();
        if (markAsCustom) {
          data['isCustom'] = true;
          data['createdAt'] = FieldValue.serverTimestamp();
        }
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(_catalog.doc(foods[j].id), data, SetOptions(merge: true));
      }
      await batch.commit();
      onProgress?.call(end, foods.length);
    }
  }

  /// Hapus makanan dengan [foodId] dari Firestore.
  Future<void> deleteFood(String foodId) async {
    await _catalog.doc(foodId).delete();
  }
}
