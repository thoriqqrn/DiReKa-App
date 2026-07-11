enum DiseaseType { chronicKidneyDisease, type2DiabetesMellitus, heartFailure, hypertension }

extension DiseaseTypeExtension on DiseaseType {
  String get label {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return 'Penyakit Ginjal Kronis';
      case DiseaseType.type2DiabetesMellitus:
        return 'Diabetes Mellitus Tipe 2';
      case DiseaseType.heartFailure:
        return 'Jantung Koroner';
      case DiseaseType.hypertension:
        return 'Hipertensi';
    }
  }

  String get shortLabel {
    switch (this) {
      case DiseaseType.chronicKidneyDisease:
        return 'Ginjal Kronis';
      case DiseaseType.type2DiabetesMellitus:
        return 'Diabetes Mellitus';
      case DiseaseType.heartFailure:
        return 'Jantung Koroner';
      case DiseaseType.hypertension:
        return 'Hipertensi';
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
      case DiseaseType.hypertension:
        return 'Kondisi di mana tekanan darah berada di atas batas normal secara persisten, meningkatkan risiko komplikasi jantung, ginjal, dan otak.';
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
      case DiseaseType.hypertension:
        return 'hypertension';
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
      case 'hypertension':
        return DiseaseType.hypertension;
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
      case DiseaseType.hypertension:
        return '💊';
    }
  }

  static String getLabel(DiseaseType type) {
    switch (type) {
      case DiseaseType.chronicKidneyDisease:
        return 'Penyakit Ginjal Kronis';
      case DiseaseType.type2DiabetesMellitus:
        return 'Diabetes Mellitus Tipe 2';
      case DiseaseType.heartFailure:
        return 'Jantung Koroner';
      case DiseaseType.hypertension:
        return 'Hipertensi';
    }
  }
}
