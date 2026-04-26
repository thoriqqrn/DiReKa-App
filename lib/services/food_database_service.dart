import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/food_item.dart';

/// Service untuk membaca dan mencari data makanan dari Firebase atau Asset lokal.
/// Data kustom dikelola admin di koleksi 'food_catalog'.
class FoodDatabaseService {
  static List<FoodItem>? _cache;
  static DateTime? _cacheTime;

  // Cache berlaku 5 menit agar data Firebase tidak basi terlalu lama
  static const _cacheTtl = Duration(minutes: 5);

  /// Special water item - only contains fluid (cairan)
  static final FoodItem waterItem = FoodItem(
    id: 'water-special',
    nama: 'Air Putih',
    kategori: 'Minuman',
    energi: 0,
    protein: 0,
    lemak: 0,
    karbohidrat: 0,
    natrium: 0,
    kalium: 0,
    fosfor: 0,
    air: 100,
    serat: 0,
    takaranSaji: const [
      TakaranSaji(ukuran: 'kecil', label: 'Kecil', gram: 200),
      TakaranSaji(ukuran: 'sedang', label: 'Sedang', gram: 250),
      TakaranSaji(ukuran: 'besar', label: 'Besar (Botol)', gram: 500),
    ],
    emoji: '💧',
    satuanNama: 'Gelas',
  );

  /// Load semua makanan khusus dari Firebase food_catalog.
  /// Berfungsi untuk User Login maupun Guest (Unauthenticated).
  static Future<List<FoodItem>> getAll() async {
    final now = DateTime.now();
    if (_cache != null &&
        _cacheTime != null &&
        now.difference(_cacheTime!) < _cacheTtl) {
      return _cache!;
    }

    final items = <FoodItem>[];

    try {
      // Ambil data langsung dari Firestore tanpa pengecekan auth di sisi kode
      final snapshot = await FirebaseFirestore.instance
          .collection('food_catalog')
          .get();
      
      for (final doc in snapshot.docs) {
        items.add(FoodItem.fromJson(doc.data()));
      }
    } catch (e) {
      // Jika gagal koneksi/permission, log error untuk debugging
      debugPrint('Firestore Food Load Error: $e');
    }

    // Selalu pastikan Air Putih ada dan di posisi pertama sebagai fallback utama
    items.removeWhere((f) => f.id == waterItem.id || f.nama.toLowerCase() == 'air putih');
    items.insert(0, waterItem);

    _cache = items;
    _cacheTime = now;
    return _cache!;
  }

  /// Cari makanan berdasarkan nama (case-insensitive, partial match).
  static Future<List<FoodItem>> search(String query) async {
    final all = await getAll();
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase().trim();
    return all.where((item) => item.nama.toLowerCase().contains(q)).toList();
  }

  /// Bersihkan cache (dipakai setelah admin update katalog).
  static void clearCache() {
    _cache = null;
    _cacheTime = null;
  }
}
