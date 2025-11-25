import 'package:flutter/material.dart';
import 'screens/welcome_view.dart';
import 'package:provider/provider.dart';
import 'providers/trip_provider.dart'; // Đảm bảo đường dẫn này trỏ tới file TripProvider ở trên

void main() {
  runApp(
    MultiProvider(
      providers: [
        // SỬ DỤNG Constructor không tham số (phù hợp với file TripProvider đã sửa)
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trek Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF425E3C),
          primary: const Color(0xFF425E3C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F6F2),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const WelcomeView(),
    );
  }
}