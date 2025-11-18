import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trek Guide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Using the forest green from the home screen as the primary seed color
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF425E3C),
          primary: const Color(0xFF425E3C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F6F2),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      // Start the app flow at the Login Screen
      home: const LoginScreen(),
    );
  }
}