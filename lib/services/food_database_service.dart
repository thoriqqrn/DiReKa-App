import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food_item.dart';

/// Service untuk membaca dan mencari data TKPI dari local JSON asset.
class FoodDatabaseService {
  static List<FoodItem>? _cache;
  
  /// Special water item - only contains fluid (cairan)
  static final FoodItem waterItem = FoodItem(
    id: 'water-special',
    nama: 'Air Putih',
    kategori: 'Minuman',
    energi: 0,      // no calories
    protein: 0,     // no protein
    lemak: 0,       // no fat
    karbohidrat: 0, // no carbs
    natrium: 0,     // no sodium
    kalium: 0,      // no potassium
    fosfor: 0,      // no phosphorus
    air: 100,       // 100ml per 100ml (1:1)
    serat: 0,       // no fiber
    takaranSaji: [
      const TakaranSaji(ukuran: 'kecil', label: 'Gelas Kecil', gram: 200),
      const TakaranSaji(ukuran: 'sedang', label: 'Gelas Sedang', gram: 250),
      const TakaranSaji(ukuran: 'besar', label: 'Botol', gram: 500),
    ],
    emoji: '💧',
    satuanNama: 'ml',
  );

  /// Load semua bahan makanan dari assets/data/tkpi.json.
  /// Di-cache setelah load pertama.
  static Future<List<FoodItem>> getAll() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString('assets/data/tkpi.json');
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    _cache = jsonList
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();
    // Add water item to the list
    _cache!.insert(0, waterItem);
    return _cache!;
  }

  /// Cari bahan makanan berdasarkan nama (case-insensitive, partial match).
  /// Water item always shown first if search is empty or matches "air"
  static Future<List<FoodItem>> search(String query) async {
    final all = await getAll();
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase().trim();
    final results = all.where((item) => item.nama.toLowerCase().contains(q)).toList();
    // Prioritize water if searching for "air" or empty
    if (q == 'air' || q.isEmpty) {
      if (results.contains(waterItem)) {
        results.remove(waterItem);
        results.insert(0, waterItem);
      }
    }
    return results;
  }

  /// Bersihkan cache (untuk keperluan testing).
  static void clearCache() => _cache = null;
}
