import 'package:flutter/material.dart';
import 'package:vendo_rider/driver/core/data/driver_store.dart';
import 'package:vendo_rider/driver/core/theme/vendo_theme.dart';
import 'package:vendo_rider/driver/dashboard/screens/driver_home_screen.dart';
import 'package:vendo_rider/driver/dashboard/screens/driver_trips_screen.dart';
import 'package:vendo_rider/driver/dashboard/widgets/driver_bottom_nav.dart';
import 'package:vendo_rider/driver/earnings/screens/driver_earnings_screen.dart';
import 'package:vendo_rider/driver/profile/screens/driver_profile_screen.dart';
import 'package:vendo_rider/driver/trips/screens/driver_manifest_screen.dart';
import 'package:vendo_rider/driver/trips/screens/driver_trip_details_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // The profile is already loaded by the start screen; the trips, earnings
    // ledger and notifications follow so the first renders carry live data.
    DriverStore.instance.refreshTrips();
    // Closed trips are loaded too, so the Manifest tab can show the parcels
    // that were on the truck even when no trip is open.
    DriverStore.instance.refreshTripHistory();
    DriverStore.instance.refreshEarnings();
    DriverStore.instance.refreshNotifications();
  }

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
