import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/offline/offline_sync_service.dart';
import 'package:vendo_buyer/features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Upload anything saved offline as soon as a connection returns.
  OfflineSyncService.instance.start();
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B1F52)),
      ),
      home: const SplashScreen(),
    );
  }
}
