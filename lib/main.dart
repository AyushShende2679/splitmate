import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'screens/login_page.dart';
import 'package:splitmate_expense_tracker/SplitMateHomeScreen.dart';
import 'screens/profile_page.dart';
import 'screens/notification_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate_expense_tracker/screens/services/firestore_sync_service.dart';
import 'package:splitmate_expense_tracker/firebase_options.dart';
import 'models/models.dart';
import 'data/models/budget.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // SaaS-grade: AppCheck free tier - web uses ReCaptcha debug, mobile uses PlayIntegrity/DeviceCheck
  try {
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI'), // Google test key, free, works on localhost/web
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
    }
  } catch (e) {
    debugPrint('AppCheck activate skipped (web/ios debug): $e'); // free tier, non-blocking for web/ios
  }
  await Hive.initFlutter();

  
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(PersonalExpenseAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GroupExpenseAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(BudgetAdapter());

  await Hive.openBox('personal_expenses');
  await Hive.openBox('group_expenses');
  await Hive.openBox('group_invitations');
  await Hive.openBox('user_profile');
  await Hive.openBox('settings');
  await Hive.openBox('notification_status');
  await Hive.openBox('budgets'); 
  final statusBox = Hive.box('notification_status');
  await statusBox.put('hasUnseenNotifications', false);
  await statusBox.put('sessionStartedAt', DateTime.now().millisecondsSinceEpoch);
  // Firestore persistence: mobile requires explicit Settings, web enables by default (avoid web exception)
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  initThemeNotifier();

  runApp(const ProviderScope(child: SplitMateApp()));
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SplitMateApp extends StatelessWidget {
  const SplitMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'SplitMate',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeMode,
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => const SplitMateHomeScreen(),
            '/profile': (context) => const ProfilePage(),
            '/notifications': (context) => const NotificationPage(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasRestored = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          if (!_hasRestored) {
            _hasRestored = true;
            Future.microtask(() async {
              try {
                await restoreAppDataFromFirestore();
              } catch (e) {
                debugPrint('Error restoring data from Firestore: $e');
              }
            });
          }
          return const SplitMateHomeScreen();
        } else {
          _hasRestored = false;
          return const LoginPage();
        }
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFE2E8F0);
    final iconColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.account_balance_wallet_outlined, size: 34, color: iconColor),
            ),
            const SizedBox(height: 24),
            Text('SplitMate', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 16),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}
