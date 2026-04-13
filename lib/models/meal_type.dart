enum MealType {
  sarapan, // Breakfast
  selinganPagi, // Morning Snack
  makanSiang, // Lunch
  selinganSiang, // Afternoon Snack
  makanMalam, // Dinner
  selinganMalam, // Evening Snack
}

extension MealTypeExtension on MealType {
  String get label {
    switch (this) {
      case MealType.sarapan:
        return 'Sarapan';
      case MealType.selinganPagi:
        return 'Selingan Pagi';
      case MealType.makanSiang:
        return 'Makan Siang';
      case MealType.selinganSiang:
        return 'Selingan Siang';
      case MealType.makanMalam:
        return 'Makan Malam';
      case MealType.selinganMalam:
        return 'Selingan Malam';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.sarapan:
        return '🌅';
      case MealType.selinganPagi:
        return '☕';
      case MealType.makanSiang:
        return '🍽️';
      case MealType.selinganSiang:
        return '🥤';
      case MealType.makanMalam:
        return '🌙';
      case MealType.selinganMalam:
        return '🌜';
    }
  }

  String get value {
    switch (this) {
      case MealType.sarapan:
        return 'sarapan';
      case MealType.selinganPagi:
        return 'selingan_pagi';
      case MealType.makanSiang:
        return 'makan_siang';
      case MealType.selinganSiang:
        return 'selingan_siang';
      case MealType.makanMalam:
        return 'makan_malam';
      case MealType.selinganMalam:
        return 'selingan_malam';
    }
  }

  static MealType fromValue(String value) {
    switch (value) {
      case 'sarapan':
        return MealType.sarapan;
      case 'selingan_pagi':
        return MealType.selinganPagi;
      case 'makan_siang':
        return MealType.makanSiang;
      case 'selingan_siang':
        return MealType.selinganSiang;
      case 'makan_malam':
        return MealType.makanMalam;
      case 'selingan_malam':
        return MealType.selinganMalam;
      default:
        return MealType.makanSiang;
    }
  }

  /// Get time range for display (approximate)
  String get timeRange {
    switch (this) {
      case MealType.sarapan:
        return '06:00 - 08:00';
      case MealType.selinganPagi:
        return '09:00 - 10:00';
      case MealType.makanSiang:
        return '11:30 - 13:00';
      case MealType.selinganSiang:
        return '14:00 - 16:00';
      case MealType.makanMalam:
        return '18:00 - 20:00';
      case MealType.selinganMalam:
        return '21:00 - 22:00';
    }
  }

  /// Get DM calorie distribution percentage (untuk Diabetes Mellitus)
  /// Total: 100% dengan breakdown per meal type
  double get dmCaloriePercentage {
    switch (this) {
      case MealType.sarapan:
        return 0.20; // 20%
      case MealType.selinganPagi:
        return 0.15; // 15%
      case MealType.makanSiang:
        return 0.30; // 30%
      case MealType.selinganSiang:
        return 0.10; // 10%
      case MealType.makanMalam:
        return 0.25; // 25%
      case MealType.selinganMalam:
        return 0.0; // Not included for DM
    }
  }
}
