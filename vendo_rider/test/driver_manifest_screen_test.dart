import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendo_rider/driver/core/data/driver_store.dart';
import 'package:vendo_rider/driver/trips/screens/driver_manifest_screen.dart';

DriverTrip _trip({
  required String code,
  TripStatus status = TripStatus.scheduled,
  List<String> trackings = const ['VX-001', 'VX-002'],
}) {
  return DriverTrip(
    code: code,
    origin: 'Laguna Province Hub',
    originArea: 'Calamba, Laguna',
    destination: 'Batangas Station Hub',
    destinationArea: 'Batangas City',
    scheduledDeparture: DateTime(2026, 11, 16, 8),
    eta: DateTime(2026, 11, 16, 12),
    distanceKm: 54,
    vehicle: 'Isuzu Elf 6-Wheeler',
    plate: 'NBC 4821',
    trackingNumbers: trackings,
    originScanned: trackings.length,
    status: status,
  );
}

Widget _harness(Widget screen) {
  return MaterialApp(home: screen);
}

void main() {
  final store = DriverStore.instance;

  setUp(() {
    store.trips.clear();
    store.closedTrips = const [];
  });

  testWidgets('shows the empty state when the hub has assigned no trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const DriverManifestScreen(embedded: true)),
    );

    expect(find.text('No manifest to show'), findsOneWidget);
  });

  testWidgets('lists the manifest parcels and filters them by tracking', (
    tester,
  ) async {
    store.trips.add(_trip(code: 'TRIP-1'));

    await tester.pumpWidget(_harness(const DriverManifestScreen()));
    expect(find.text('VX-001'), findsOneWidget);
    expect(find.text('VX-002'), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'vx-002');
    await tester.pump();

    expect(find.text('VX-001'), findsNothing);
    expect(find.text('VX-002'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('keeps a trip readable after it closes while selected', (
    tester,
  ) async {
    final first = _trip(code: 'TRIP-1');
    final second = _trip(code: 'TRIP-2');
    store.trips.addAll([first, second]);

    await tester.pumpWidget(
      _harness(const DriverManifestScreen(embedded: true)),
    );

    // Pick the second trip in the selector.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRIP-2 · Batangas Station Hub').last);
    await tester.pumpAndSettle();
    expect(find.text('TRIP-2 · Batangas Station Hub'), findsOneWidget);

    // The hub closes that trip: it leaves the active board but its manifest
    // must stay on screen, and the closed trip must stay in the dropdown.
    store.trips.remove(second);
    second.status = TripStatus.completed;
    store.closedTrips = [second];

    await tester.pumpWidget(
      _harness(const DriverManifestScreen(embedded: true)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('TRIP-2 · Batangas Station Hub · completed'),
      findsOneWidget,
    );
    expect(find.text('VX-001'), findsOneWidget);
  });
}
