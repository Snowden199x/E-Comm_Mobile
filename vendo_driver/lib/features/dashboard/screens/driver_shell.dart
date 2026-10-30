import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/dashboard/screens/driver_home_screen.dart';
import 'package:vendo_driver/features/dashboard/screens/driver_trips_screen.dart';
import 'package:vendo_driver/features/dashboard/widgets/driver_bottom_nav.dart';
import 'package:vendo_driver/features/earnings/screens/driver_earnings_screen.dart';
import 'package:vendo_driver/features/profile/screens/driver_profile_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_manifest_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_trip_details_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _tab = 0;

  void _selectTab(int index) {
    if (index == _tab) return;
    setState(() => _tab = index);
  }

  void _openTrip(String code) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DriverTripDetailsScreen(tripCode: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: VColors.background,
          body: IndexedStack(
            index: _tab,
            children: [
              DriverHomeScreen(onOpenTrip: _openTrip, onOpenTab: _selectTab),
              DriverTripsScreen(onOpenTrip: _openTrip),
              const DriverManifestScreen(embedded: true),
              const DriverEarningsScreen(),
              const DriverProfileScreen(),
            ],
          ),
          bottomNavigationBar: DriverBottomNav(
            index: _tab,
            onSelected: _selectTab,
          ),
        );
      },
    );
  }
}
