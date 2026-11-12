import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:vendo_rider/core/offline/offline_tiles.dart';
import 'package:vendo_rider/core/push/rider_push_service.dart';
import 'package:vendo_rider/features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push is optional: without Firebase the app keeps polling notifications.
  FirebaseMessaging.onBackgroundMessage(riderPushBackgroundHandler);
  // Prepare the on-device map tile cache; the app runs without it.
  await OfflineTileProviders.initialise();
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
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B1F52)),
      ),
      home: const SplashScreen(),
    );
  }
}
