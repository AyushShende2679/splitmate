import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_page.dart';
import 'package:splitmate_expense_tracker/SplitMateHomeScreen.dart';
import 'screens/profile_page.dart';
import 'screens/notification_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:splitmate_expense_tracker/screens/services/firestore_sync_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'screens/parent_code_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:splitmate_expense_tracker/firebase_options.dart';
import 'models/models.dart';
import 'package:uni_links2/uni_links.dart';
import 'package:splitmate_expense_tracker/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();

  
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(PersonalExpenseAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(GroupExpenseAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserProfileAdapter());

  await Hive.openBox('personal_expenses');
  await Hive.openBox('group_expenses');
  await Hive.openBox('group_invitations');
  await Hive.openBox('user_profile');
  await Hive.openBox('settings');
  await Hive.openBox('notification_status'); 
  final statusBox = Hive.box('notification_status');
  await statusBox.put('hasUnseenNotifications', false);
  await statusBox.put('sessionStartedAt', DateTime.now().millisecondsSinceEpoch); 
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  initThemeNotifier();

  runApp(const SplitMateApp());
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
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb) return; // uni_links not supported on web
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) _handleLink(initialLink);

      _sub = linkStream.listen((String? link) {
        if (link != null) _handleLink(link);
      });
    } catch (e) {
      debugPrint("Deep link error: $e");
    }
  }

  void _handleLink(String link) {
    final uri = Uri.parse(link);
    if (uri.scheme == "splitmate" && uri.host == "monitor") {
      final code = uri.queryParameters['code'];
      if (code != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ParentCodeScreen(initialCode: code),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData && snapshot.data != null) {
          Future.microtask(() async {
            try {
              await restoreAppDataFromFirestore();
            } catch (e) {
              debugPrint('Error restoring data from Firestore: $e');
            }
          });
          return const SplitMateHomeScreen();
        } else {
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
