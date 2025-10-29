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
import 'package:uni_links2/uni_links.dart';
import 'dart:async';
import 'screens/parent_code_screen.dart';
import 'models/models.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();

  
  if (!Hive.isAdapterRegistered(0))
    Hive.registerAdapter(PersonalExpenseAdapter());
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

  runApp(const SplitMateApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SplitMateApp extends StatelessWidget {
  const SplitMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitMate',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black26,
            backgroundColor: const Color(0xFF4A90E2),
            foregroundColor: Colors.white,
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          shadowColor: Colors.black12,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const SplitMateHomeScreen(),
        '/profile': (context) => const ProfilePage(),
        '/notifications': (context) => const NotificationPage(),
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
    try {
      final initialLink = await getInitialLink();
      if (initialLink != null) _handleLink(initialLink);

      _sub = linkStream.listen((String? link) {
        if (link != null) _handleLink(link);
      });
    } catch (e) {
      print("Deep link error: $e");
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
            await restoreAppDataFromFirestore();
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
    return const Scaffold(
        body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Loading..."),
        ],
      ),
    ));
  }
}
