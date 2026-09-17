import 'package:flutter/material.dart';
import 'package:vendo_rider/features/auth/screens/login_screen.dart';

void main() {
  runApp(const VendoRiderApp());
}

class VendoRiderApp extends StatelessWidget {
  const VendoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendo Rider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B1F52)),
      ),
      home: const LoginScreen(),
    );
  }
}
