import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_constants.dart';
import '../models/disease_type.dart';

class DiseaseProvider extends ChangeNotifier {
  DiseaseType? _selectedDisease;

  DiseaseType? get selectedDisease => _selectedDisease;

  DiseaseProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(AppConstants.prefDiseaseType);
    if (val != null) {
      _selectedDisease = DiseaseTypeExtension.fromValue(val);
      notifyListeners();
    }
  }

  Future<void> setDisease(DiseaseType type) async {
    _selectedDisease = type;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefDiseaseType, type.value);
  }

  Future<void> clearDisease() async {
    _selectedDisease = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefDiseaseType);
  }
}
