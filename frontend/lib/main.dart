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
  );

  // Lấy kết quả xem có phải Cold Start không? (vẫn lấy để logging)
  final bool isColdStart = await SessionLifecycleService.checkIsColdStart();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()..loadFromStorage()),
      ],
      // Truyền cờ isColdStart vào MyApp
      child: MyApp(isColdStart: isColdStart),
    ),
  );
}

class MyApp extends StatelessWidget {
  // Nhận biến từ main
  final bool isColdStart;

  const MyApp({super.key, required this.isColdStart});

  @override
  Widget build(BuildContext context) {
    // 1. Lấy session hiện tại (Supabase client caches sessions)
    final session = Supabase.instance.client.auth.currentSession;

    // 2. LOGIC QUYẾT ĐỊNH MÀN HÌNH KHỞI ĐỘNG
    // Ưu tiên giữ nguyên session nếu còn hợp lệ để tránh quay lại màn Welcome không cần thiết
    final startScreen = session != null
        ? const HomePage()
        : const WelcomeView();

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