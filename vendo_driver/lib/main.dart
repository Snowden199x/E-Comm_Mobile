import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const VendoDriverApp());
}

class VendoDriverApp extends StatelessWidget {
  const VendoDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendo Driver',
      debugShowCheckedModeBanner: false,
      theme: VendoTheme.light(),
      home: const DriverLoginScreen(),
    );
  }
}
