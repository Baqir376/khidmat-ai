import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/provider_login_screen.dart';
import 'screens/provider_dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/secure_storage_service.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  
  // Speed Optimization: Auto-detect local high-speed routing
  await ApiService.optimizeConnectionSpeed();
  await Supabase.initialize(
    url: 'https://ztsyeeglnqhqwkbmrqqj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0c3llZWdsbnFocXdrYm1ycXFqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwNDE5NTMsImV4cCI6MjA5NDYxNzk1M30.7VBn3F1DX1nhJkjXYfWzH0W4IjbJzgTWXzCJof2xuwI',
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const KhidmatAIApp(),
    ),
  );
}

class KhidmatAIApp extends StatelessWidget {
  const KhidmatAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khidmat AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/booking': (context) => const BookingScreen(),
        '/provider_login': (context) => const ProviderLoginScreen(),
        '/provider_dashboard': (context) => const ProviderDashboardScreen(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 1)); // Show splash briefly
    final session = Supabase.instance.client.auth.currentSession;
    
    if (!mounted) return;
    
    if (session != null) {
      // 1. Request Notification Permissions
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // 2. Get the FCM Token
        String? token = await messaging.getToken();
        debugPrint("FCM Token: $token");
        
        // 3. Save the token to Supabase User Metadata so our backend can use it
        if (token != null) {
          try {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'fcm_token': token}),
            );
            debugPrint("Successfully saved FCM token to Supabase auth metadata.");
          } catch (e) {
            debugPrint("Failed to save FCM token: $e");
          }
        }
      }

      // Handle incoming messages while the app is in the foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${message.notification?.title}: ${message.notification?.body}'),
              duration: const Duration(seconds: 5),
              backgroundColor: AppTheme.primaryGreen,
            )
          );
        }
      });

      if (!mounted) return;

      // Check role from metadata
      final metadata = session.user.userMetadata;
      final role = metadata?['role'];

      if (role == 'provider') {
        Navigator.pushReplacementNamed(context, '/provider_dashboard', arguments: session.user.id);
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
