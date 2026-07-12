import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_modifier.dart';

class FoodModifierService {
  static final _db = FirebaseFirestore.instance;

  // ── Cache ──────────────────────────────────────────────────────────────
  static List<CookingMethod>? _cookingCache;
  static List<FoodAdditive>? _additiveCache;
  static DateTime? _cookingCacheTime;
  static DateTime? _additiveCacheTime;
  static const _ttl = Duration(minutes: 10);

  // ── Cooking Methods ────────────────────────────────────────────────────
  static Future<List<CookingMethod>> getCookingMethods({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cookingCache != null &&
        _cookingCacheTime != null &&
        DateTime.now().difference(_cookingCacheTime!) < _ttl) {
      return _cookingCache!;
    }
    try {
      final snap = await _db.collection('cooking_methods').get();
      final methods = snap.docs
          .map((d) => CookingMethod.fromMap(d.id, d.data()))
          .toList();
      
      // Sort in-memory to avoid Firestore composite index requirement
      methods.sort((a, b) {
        final catComp = a.category.compareTo(b.category);
        if (catComp != 0) return catComp;
        return a.name.compareTo(b.name);
      });
      
      _cookingCache = methods;
      _cookingCacheTime = DateTime.now();
      return _cookingCache!;
    } catch (e) {
      print('Error fetching cooking_methods: \$e');
      return _cookingCache ?? [];
    }
  }

  // ── Food Additives ─────────────────────────────────────────────────────
  static Future<List<FoodAdditive>> getFoodAdditives({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _additiveCache != null &&
        _additiveCacheTime != null &&
        DateTime.now().difference(_additiveCacheTime!) < _ttl) {
      return _additiveCache!;
    }
    try {
      final snap = await _db.collection('food_additives').get();
      final additives = snap.docs
          .map((d) => FoodAdditive.fromMap(d.id, d.data()))
          .toList();
          
      // Sort in-memory
      additives.sort((a, b) {
        final catComp = a.category.compareTo(b.category);
        if (catComp != 0) return catComp;
        return a.name.compareTo(b.name);
      });

      _additiveCache = additives;
      _additiveCacheTime = DateTime.now();
      return _additiveCache!;
    } catch (e) {
      print('Error fetching food_additives: \$e');
      return _additiveCache ?? [];
    }
  }

  static void clearCache() {
    _cookingCache = null;
    _additiveCache = null;
    _cookingCacheTime = null;
    _additiveCacheTime = null;
  }
}
