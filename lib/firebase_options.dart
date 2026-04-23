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
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBzNMo45Ocks_hFzsvSEJFX7PyfD0StZ0c',
    appId: '1:143482753748:web:a7d96685c92aa2468ca141',
    messagingSenderId: '143482753748',
    projectId: 'splitmate-1cd5c',
    authDomain: 'splitmate-1cd5c.firebaseapp.com',
    storageBucket: 'splitmate-1cd5c.firebasestorage.app',
    measurementId: 'G-ZPR27TWB1J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDtgsmqa1eJlt-kIZGk8-OHqiMCWbSDuAQ',
    appId: '1:143482753748:android:84d2e668aef7715e8ca141',
    messagingSenderId: '143482753748',
    projectId: 'splitmate-1cd5c',
    storageBucket: 'splitmate-1cd5c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBa_4uGI7bIPyRl4SANYk2A5pdVSeZiATw',
    appId: '1:143482753748:ios:96374e30fc74c3828ca141',
    messagingSenderId: '143482753748',
    projectId: 'splitmate-1cd5c',
    storageBucket: 'splitmate-1cd5c.firebasestorage.app',
    iosBundleId: 'Splitmate',
    iosClientId: '143482753748-mkj8ubngkmifdjif2qu4vnr398eu4iaq.apps.googleusercontent.com',
  );
}
