import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// debugPrint is provided by Flutter material import; no separate foundation import needed
import 'screens/welcome_view.dart';
import 'screens/home_screen.dart';
import 'providers/trip_provider.dart';
import 'providers/achievement_provider.dart';
import 'core/supabase_config.dart';
import 'services/session_lifecycle_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/notification.dart';

Future<void> main() async {
  // load API key first
  await dotenv.load(fileName: ".env");
  
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Setup auth state listener to handle token refresh failures
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == AuthChangeEvent.tokenRefreshed) {
      debugPrint('--- [Auth] Token refreshed successfully');
    } else if (event == AuthChangeEvent.signedOut) {
      debugPrint('--- [Auth] User signed out');
    }
  }, onError: (error) {
    debugPrint('--- [Auth] Auth state error: $error');
    // Clear invalid session on auth errors
    if (error.toString().contains('refresh_token')) {
      Supabase.instance.client.auth.signOut(scope: SignOutScope.local).catchError((_) {});
    }
  });

  // Lấy kết quả xem có phải Cold Start không? (vẫn lấy để logging)
  final bool isColdStart = await SessionLifecycleService.checkIsColdStart();
  
  // Validate session after cold start check
  final bool hasValidSession = await SessionLifecycleService.validateSession();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()..loadFromStorage()),
      ],
      // Truyền cờ isColdStart và session validity vào MyApp
      child: MyApp(isColdStart: isColdStart, hasValidSession: hasValidSession),
    ),
  );
}

class MyApp extends StatelessWidget {
  // Nhận biến từ main
  final bool isColdStart;
  final bool hasValidSession;

  const MyApp({super.key, required this.isColdStart, required this.hasValidSession});

  @override
  Widget build(BuildContext context) {
    // 1. Lấy session hiện tại (Supabase client caches sessions)
    final session = Supabase.instance.client.auth.currentSession;

    // 2. LOGIC QUYẾT ĐỊNH MÀN HÌNH KHỞI ĐỘNG
    // If cold start or no valid session, always start at Welcome screen
    // Otherwise, check if session exists to decide between Home and Welcome
    final Widget startScreen;
    if (isColdStart || !hasValidSession || session == null) {
      debugPrint('--- [Main] Starting at WelcomeView (coldStart: $isColdStart, validSession: $hasValidSession, session: ${session != null})');
      startScreen = const WelcomeView();
    } else {
      debugPrint('--- [Main] Starting at HomePage (session valid)');
      startScreen = const HomePage();
    }

    return MaterialApp(
      scaffoldMessengerKey: NotificationService.messengerKey,
      navigatorKey: NotificationService.navigatorKey,
      title: 'Trek Guide',
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const HomePage(),
        '/welcome': (context) => const WelcomeView(),
      },
      // Sử dụng màn hình đã quyết định ở trên
      home: startScreen,
    );
  }
}