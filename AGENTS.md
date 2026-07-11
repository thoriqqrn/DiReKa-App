# AGENTS.md

## Repo Shape
- Flutter app at repo root; real app entrypoint is `lib/main.dart` (`DiRekaApp`), not leftover template `MyHomePage` in same file.
- Firebase Functions are separate TypeScript package in `functions/`; compile source from `functions/src/` to ignored/generated `functions/lib/`.
- Firebase project alias is `direka-app` in `.firebaserc`; hosting serves Flutter web build from `build/web`.

## Commands
- Install Flutter deps: `flutter pub get`.
- Analyze Dart: `flutter analyze`.
- Format Dart: `dart format lib test`.
- Run all Flutter tests: `flutter test`.
- Run one Flutter test file: `flutter test test/widget_test.dart`.
- Build web for Firebase Hosting: `flutter build web`.
- Install Functions deps: `npm --prefix functions install`.
- Build Functions: `npm --prefix functions run build`.
- Run Functions emulator: `npm --prefix functions run serve`.
- Deploy Functions: `npm --prefix functions run deploy`; Firebase predeploy also runs `npm --prefix "$RESOURCE_DIR" run build`.

## Firebase And Auth Gotchas
- `lib/firebase_options.dart` only supports web and Android; iOS/macOS/windows/linux throw `UnsupportedError`.
- Android Firebase config exists at `android/app/google-services.json`; do not rename package IDs without checking Firebase config and password reset settings.
- Password reset handler URLs are hardcoded in `lib/core/app_constants.dart` to `https://direka-app.web.app`.
- Admin identity is hardcoded in multiple places as `admin@direka.app`; README also documents dev password `admin123`.
- Callable Function `adminResetUserPassword` runs in region `asia-southeast2`; Flutter calls same region in `lib/services/admin_service.dart`.
- Extra reset admins come from Functions env var `RESET_ADMIN_EMAILS` comma list; fallback admin email remains `admin@direka.app`.

## Data And Rules
- Main Firestore user collection constant is `AppConstants.colUsers == 'users'`.
- Firestore rules allow public read for `food_catalog` and `education_posts`, admin-only writes, and deny all unmatched documents.
- Health records live under `users/{uid}/diabetes_health_records`, `kidney_health_records`, and `heart_health_records`.
- Food logs live in top-level `food_logs` with `uid` field; family account access depends on `users/{uid}.linkedPrimaryUid`.

## App Wiring
- State uses Provider: `AuthProvider`, `DiseaseProvider`, `ThemeProvider`, and `FontSizeProvider` are registered in `lib/main.dart`.
- Routes are centralized in `lib/core/app_constants.dart` and wired manually in `MaterialApp.routes`.
- App locale is forced to Indonesian (`Locale('id', 'ID')`); user-facing strings are mostly Indonesian.
- Bottom tabs are built in `lib/screens/home/main_screen.dart`: Home, Food Tracker, Health Tracker, Education.

## Tests And Verification
- Current test suite is minimal smoke test and pumps `DiRekaApp`; Firebase initialization is not performed by that test.
- No CI workflow found; run `flutter analyze`, `flutter test`, and `npm --prefix functions run build` when touching Dart plus Functions code.
- Functions TypeScript is strict with `noUnusedLocals` and `noImplicitReturns`; unused imports fail `npm --prefix functions run build`.
