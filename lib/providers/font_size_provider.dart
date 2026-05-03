import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Empat skala ukuran font yang tersedia.
enum FontSizeLevel {
  small,
  normal,
  large,
  extraLarge,
}

extension FontSizeLevelX on FontSizeLevel {
  String get label {
    switch (this) {
      case FontSizeLevel.small:
        return 'Kecil';
      case FontSizeLevel.normal:
        return 'Normal';
      case FontSizeLevel.large:
        return 'Besar';
      case FontSizeLevel.extraLarge:
        return 'Sangat Besar';
    }
  }

  /// Skala relatif terhadap ukuran font sistem (1.0 = default).
  double get scale {
    switch (this) {
      case FontSizeLevel.small:
        return 0.85;
      case FontSizeLevel.normal:
        return 1.0;
      case FontSizeLevel.large:
        return 1.2;
      case FontSizeLevel.extraLarge:
        return 1.4;
    }
  }
}

class FontSizeProvider with ChangeNotifier {
  static const String _key = 'font_size_level';

  FontSizeLevel _level = FontSizeLevel.normal;

  FontSizeProvider() {
    _load();
  }

  FontSizeLevel get level => _level;
  double get scale => _level.scale;

  /// Nilai slider (0–3).
  double get sliderValue => _level.index.toDouble();

  void setLevel(FontSizeLevel level) {
    if (_level == level) return;
    _level = level;
    _save();
    notifyListeners();
  }

  void setFromSlider(double value) {
    final idx = value.round().clamp(0, FontSizeLevel.values.length - 1);
    setLevel(FontSizeLevel.values[idx]);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_key);
    if (idx != null && idx >= 0 && idx < FontSizeLevel.values.length) {
      _level = FontSizeLevel.values[idx];
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _level.index);
  }
}
