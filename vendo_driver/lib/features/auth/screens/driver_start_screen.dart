import 'package:flutter/material.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';
import 'package:vendo_driver/features/dashboard/screens/driver_shell.dart';

/// Decides where the app opens.
///
/// A saved token is checked against the web before the shell is shown, so a
/// revoked token, a suspension or an expired licence sends the driver back to
/// sign-in instead of into a stale session. When the web cannot be reached the
/// last profile it returned is used, so a driver on a weak connection is not
/// forced to type a password again.
class DriverStartScreen extends StatefulWidget {
  const DriverStartScreen({super.key});

  @override
  State<DriverStartScreen> createState() => _DriverStartScreenState();
}

class _DriverStartScreenState extends State<DriverStartScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final api = DriverApi.instance;
    if (!await api.hasToken()) {
      _goToLogin();
      return;
    }

    try {
      final session = await api.me();
      DriverStore.instance.applySession(session);
      _goToShell();
    } on DriverApiException catch (error) {
      if (error.isUnauthenticated) {
        await api.clearSession();
        _goToLogin();
        return;
      }
      await _useSavedProfileOrSignIn();
    } catch (_) {
      await _useSavedProfileOrSignIn();
    }
  }

  Future<void> _useSavedProfileOrSignIn() async {
    final saved = await DriverApi.instance.savedProfile();
    if (saved == null) {
      _goToLogin();
      return;
    }
    DriverStore.instance.applySession(saved);
    _goToShell();
  }

  void _goToShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DriverShell()),
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DriverLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VColors.prune,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_rounded, color: VColors.lin, size: 46),
            SizedBox(height: 18),
            Text(
              'Vendo Xpress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Checking your driver account…',
              style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5),
            ),
            SizedBox(height: 22),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: VColors.lin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
