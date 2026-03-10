import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/food_item.dart';

/// Service untuk membaca dan mencari data TKPI dari local JSON asset.
class FoodDatabaseService {
  static List<FoodItem>? _cache;

  /// Load semua bahan makanan dari assets/data/tkpi.json.
  /// Di-cache setelah load pertama.
  static Future<List<FoodItem>> getAll() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString('assets/data/tkpi.json');
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    _cache = jsonList
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// Cari bahan makanan berdasarkan nama (case-insensitive, partial match).
  static Future<List<FoodItem>> search(String query) async {
    final all = await getAll();
    if (query.trim().isEmpty) return all;
    final q = query.toLowerCase().trim();
    return all.where((item) => item.nama.toLowerCase().contains(q)).toList();
  }

  /// Bersihkan cache (untuk keperluan testing).
  static void clearCache() => _cache = null;
}
