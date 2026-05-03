import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/disease_provider.dart';
import 'providers/font_size_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/admin/admin_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/admin_food_catalog_screen.dart';
import 'screens/auth/disease_selection_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/password_reset_action_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/auth/google_complete_profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized: ${Firebase.app().options.projectId}');
  } catch (e, st) {
    debugPrint('Firebase init error: $e');
    debugPrint(st.toString());
  }
  runApp(const DiRekaApp());
}

class DiRekaApp extends StatelessWidget {
  const DiRekaApp({super.key});

  String _resolveInitialRoute() {
    final params = Uri.base.queryParameters;
    if (params['mode'] == 'resetPassword' && (params['oobCode'] ?? '').isNotEmpty) {
      return AppConstants.routePasswordResetAction;
    }
    return AppConstants.routeSplash;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DiseaseProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontSizeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Consumer<FontSizeProvider>(
            builder: (context, fontSizeProvider, _) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(fontSizeProvider.scale),
                ),
                child: MaterialApp(
                  title: 'Direka',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeProvider.themeMode,
                  // Lokalisasi Bahasa Indonesia
                  localizationsDelegates: const [
                    quill.FlutterQuillLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
                  locale: const Locale('id', 'ID'),
                  initialRoute: _resolveInitialRoute(),
                  routes: {
                    AppConstants.routeSplash: (_) => const SplashScreen(),
                    AppConstants.routeDiseaseSelection: (_) =>
                        const DiseaseSelectionScreen(),
                    AppConstants.routeLogin: (_) => const LoginScreen(),
                    AppConstants.routeForgotPassword: (_) =>
                        const ForgotPasswordScreen(),
                    AppConstants.routePasswordResetAction: (_) =>
                        const PasswordResetActionScreen(),
                    AppConstants.routeRegister: (_) => const RegisterScreen(),
                    AppConstants.routeMain: (_) => const MainScreen(),
                    AppConstants.routeNotifications: (_) =>
                        const NotificationsScreen(),
                    AppConstants.routeSettings: (_) => const SettingsScreen(),
                    AppConstants.routeEditProfile: (_) =>
                        const EditProfileScreen(),
                    AppConstants.routeGoogleCompleteProfile: (_) =>
                        const GoogleCompleteProfileScreen(),
                    AppConstants.routeAdmin: (_) => const AdminScreen(),
                    AppConstants.routeAdminSettings: (_) =>
                        const AdminSettingsScreen(),
                    AppConstants.routeAdminFoodCatalog: (_) =>
                        const AdminFoodCatalogScreen(),
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
