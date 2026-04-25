# Project Overview: DiReKa-App

**DiReKa (Diet & Rekam Kesehatan)** is a multi-platform application (primarily mobile) built with **Flutter** designed for personalized health and nutrition management. It specializes in supporting patients with chronic conditions: **Chronic Kidney Disease (CKD)**, **Type 2 Diabetes Mellitus (T2DM)**, and **Heart Failure (Coronary Heart Disease)**.

## Core Technologies
- **Frontend:** Flutter (Dart)
- **Backend/Database:** Firebase (Cloud Firestore, Authentication)
- **State Management:** Provider
- **Key Libraries:**
  - `fl_chart`: For health and nutrition tracking visualizations.
  - `flutter_local_notifications`: For system-level alerts and reminders.
  - `syncfusion_flutter_xlsio` & `share_plus`: For Excel data export and sharing.
  - `firebase_messaging`: For future push notification support.

## Architecture
The project follows a standard Flutter architectural pattern:
- **`lib/models/`**: Data structures (e.g., `UserModel`, `FoodLogEntry`, `NutritionNeeds`).
- **`lib/services/`**: Business logic and database interactions (e.g., `AuthService`, `FoodLogService`, `AdminService`).
- **`lib/providers/`**: State management using Provider.
- **`lib/screens/`**: UI screens, organized by feature (auth, home, tracker, admin, etc.).
- **`lib/widgets/`**: Reusable UI components.

## Building and Running
- **Install Dependencies:** `flutter pub get`
- **Run Application:** `flutter run`
- **Build APK:** `flutter build apk`
- **Build Web:** `flutter build web`

## Development Conventions
### Medical Logic & Formulas
- **Nutrition:** Uses Indonesian standards (TKPI Kemenkes 2020) and specialized formulas for each disease type (e.g., Harris-Benedict for Heart Failure, PERKENI for Diabetes).
- **IMT/BMI:** Uses Asia-Pacific standards for status categorization.
- **Glycemic Load (GL):** Calculated as `(GI * Carbs) / 100`.

### Code Style & UI
- **Modularity:** Large features (like the Admin panel) should be split into smaller tab-specific files located in feature-specific subdirectories.
- **Styling:** Follows a consistent theme defined in `lib/core/app_theme.dart` and `lib/core/app_colors.dart`.
- **Safety:** Always use robust null-safety patterns, especially when reading data from Firestore (e.g., helper methods for double/int conversions).

### Admin Features
- Admin credentials are hardcoded for the prototype (`admin@direka.app`).
- Supports comprehensive user management, food log auditing, and health tracker monitoring with XLSX export capabilities.

## Instructions for Gemini CLI
- **Contextual Precedence:** These instructions are foundational. Follow the established medical formulas and modular file structure strictly.
- **Surgical Edits:** When modifying screens, ensure constraints are properly handled to avoid `infinite width` or `overflow` errors.
- **Consistency:** Always synchronize changes across models, services, and UI screens (e.g., when adding a new user property).
