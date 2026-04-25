import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAmx83myfs7KMbguedq2C72dLbu_DD5aA8',
    appId: '1:742908514617:android:b365397a3bc772f22818e8',
    messagingSenderId: '742908514617',
    projectId: 'direka-app',
    storageBucket: 'direka-app.firebasestorage.app',
    authDomain: 'direka-app.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmx83myfs7KMbguedq2C72dLbu_DD5aA8',
    appId: '1:742908514617:android:b365397a3bc772f22818e8',
    messagingSenderId: '742908514617',
    projectId: 'direka-app',
    storageBucket: 'direka-app.firebasestorage.app',
  );
}
