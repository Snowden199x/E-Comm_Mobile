import 'package:flutter/material.dart';
import 'package:vendo_buyer/features/auth/screens/login_screen.dart';

void main() {
  runApp(const VendoBuyerApp());
}

class VendoBuyerApp extends StatelessWidget {
  const VendoBuyerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B1F52),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
