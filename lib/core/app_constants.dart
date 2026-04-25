class AppConstants {
  // Route names
  static const String routeSplash = '/';
  static const String routeDiseaseSelection = '/disease-selection';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeMain = '/main';
  static const String routeNotifications = '/notifications';
  static const String routeSettings = '/settings';
  static const String routeEditProfile = '/edit-profile';
  static const String routeGoogleCompleteProfile = '/google-complete-profile';
  static const String routeAdmin = '/admin';
  static const String routeAdminSettings = '/admin-settings';
  static const String routeAdminFoodCatalog = '/admin-food-catalog';

  // Firestore collection
  static const String colUsers = 'users';

  // SharedPrefs keys
  static const String prefDiseaseType = 'disease_type';
  static const String prefIsGuest = 'is_guest';

  // Admin credentials (hardcoded)
  static const String adminEmail = 'admin@direka.app';
  static const String adminPassword = 'admin123';
}
