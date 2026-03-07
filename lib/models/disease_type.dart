enum DiseaseType {
  chronicKidneyDisease,
  type2DiabetesMellitus,
  heartFailure,
}

extension DiseaseTypeExtension on DiseaseType {
  String get label {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return 'Penyakit Ginjal Kronis';
      case DiseaseType.type2DiabetesMellitus:
        return 'Diabetes Mellitus Tipe 2';
      case DiseaseType.heartFailure:
        return 'Gagal Jantung';
    }
  }

  String get shortLabel {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return 'Ginjal Kronis';
      case DiseaseType.type2DiabetesMellitus:
        return 'Diabetes Mellitus';
      case DiseaseType.heartFailure:
        return 'Gagal Jantung';
    }
  }

  String get description {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return 'Kondisi di mana ginjal mengalami kerusakan secara bertahap dan kehilangan kemampuannya untuk menyaring darah dengan baik.';
      case DiseaseType.type2DiabetesMellitus:
        return 'Kondisi di mana tubuh tidak dapat menggunakan insulin secara efektif, menyebabkan kadar gula darah meningkat.';
      case DiseaseType.heartFailure:
        return 'Kondisi di mana jantung tidak mampu memompa darah secara optimal untuk memenuhi kebutuhan tubuh.';
    }
  }

  String get value {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return 'chronic_kidney_disease';
      case DiseaseType.type2DiabetesMellitus:
        return 'type2_diabetes_mellitus';
      case DiseaseType.heartFailure:
        return 'heart_failure';
    }
  }

  static DiseaseType fromValue(String value) {
    switch (value) {
      case 'chronic_kidney_disease':
        return DiseaseType.chronicKidneyDisease;
      case 'type2_diabetes_mellitus':
        return DiseaseType.type2DiabetesMellitus;
      case 'heart_failure':
        return DiseaseType.heartFailure;
      default:
        return DiseaseType.chronicKidneyDisease;
    }
  }

  String get iconEmoji {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return '🫘';
      case DiseaseType.type2DiabetesMellitus:
        return '🩸';
      case DiseaseType.heartFailure:
        return '🫀';
    }
  }
}
