import 'package:flutter/foundation.dart';

/// The driver's stage in a trip. Mirrors the web status names.
enum TripStatus { scheduled, inTransit, completed }

/// What the driver sees for one parcel. Deliberately has no addresses, prices
/// or COD state: a driver only moves the parcel.
enum ParcelStage { awaitingOriginScan, departed, inTransit, received }

class DriverTrip {
  DriverTrip({
    required this.code,
    required this.origin,
    required this.originArea,
    required this.destination,
    required this.destinationArea,
    required this.scheduledDeparture,
    required this.eta,
    required this.distanceKm,
    required this.vehicle,
    required this.plate,
    required this.trackingNumbers,
    required this.originScanned,
    this.destinationScanned = 0,
    this.status = TripStatus.scheduled,
    this.departedAt,
    this.arrivedAt,
  });

  final String code;
  final String origin;
  final String originArea;
  final String destination;
  final String destinationArea;
  final DateTime scheduledDeparture;
  final DateTime eta;
  final double distanceKm;
  final String vehicle;
  final String plate;
  final List<String> trackingNumbers;

  /// Parcels the hub has scanned as departed at the origin.
  int originScanned;

  /// Parcels the destination station has scanned as received.
  int destinationScanned;

  TripStatus status;
  DateTime? departedAt;
  DateTime? arrivedAt;

  int get parcelCount => trackingNumbers.length;
  bool get readyToDepart => originScanned >= parcelCount;
  bool get readyToClose => destinationScanned >= parcelCount;
  int get missingOriginScans => parcelCount - originScanned;
  int get missingDestinationScans => parcelCount - destinationScanned;

  ParcelStage stageFor(int index) {
    if (status == TripStatus.completed || index < destinationScanned) {
      return ParcelStage.received;
    }
    if (status == TripStatus.inTransit) return ParcelStage.inTransit;
    if (index < originScanned) return ParcelStage.departed;
    return ParcelStage.awaitingOriginScan;
  }

  String get statusLabel => switch (status) {
    TripStatus.scheduled => 'Scheduled',
    TripStatus.inTransit => 'In transit',
    TripStatus.completed => 'Completed',
  };
}

class DriverProfile {
  DriverProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.hub,
    required this.hubArea,
    required this.company,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.vehicle,
    required this.plate,
  });

  final String name;
  final String email;
  final String phone;
  final String hub;
  final String hubArea;
  final String company;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final String vehicle;
  final String plate;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool get licenseValid => licenseExpiry.isAfter(DateTime.now());
}

/// A per-stop credit from the older earnings rule. New orders no longer create
/// driver credits, so this screen only lists legacy rows.
class LegacyCredit {
  const LegacyCredit({
    required this.trip,
    required this.date,
    required this.stops,
  });

  final String trip;
  final DateTime date;
  final int stops;

  double get amount => stops * 10;
}

class DriverStore extends ChangeNotifier {
  DriverStore._();

  static final DriverStore instance = DriverStore._();

  final DriverProfile profile = DriverProfile(
    name: 'Miguel Santos',
    email: 'miguel.santos@vendoxpress.ph',
    phone: '0917 555 0142',
    hub: 'Laguna Province Hub',
    hubArea: 'Calamba, Laguna',
    company: 'Vendo Xpress Logistics',
    licenseNumber: 'N02-24-118942',
    licenseExpiry: DateTime(2027, 8, 12),
    vehicle: 'Isuzu Elf 6-Wheeler',
    plate: 'NBC 4821',
  );

  late final List<DriverTrip> trips = _seedTrips();

  final List<LegacyCredit> legacyCredits = [
    LegacyCredit(trip: 'TRP-2141', date: DateTime(2026, 9, 18), stops: 14),
    LegacyCredit(trip: 'TRP-2137', date: DateTime(2026, 9, 11), stops: 9),
    LegacyCredit(trip: 'TRP-2129', date: DateTime(2026, 9, 4), stops: 18),
    LegacyCredit(trip: 'TRP-2116', date: DateTime(2026, 8, 27), stops: 11),
    LegacyCredit(trip: 'TRP-2108', date: DateTime(2026, 8, 20), stops: 7),
    LegacyCredit(trip: 'TRP-2099', date: DateTime(2026, 8, 13), stops: 12),
  ];

  double get legacyTotal =>
      legacyCredits.fold(0, (total, credit) => total + credit.amount);

  int get legacyStops => legacyCredits.fold(0, (total, c) => total + c.stops);

  DriverTrip? tripByCode(String code) {
    for (final trip in trips) {
      if (trip.code == code) return trip;
    }
    return null;
  }

  /// The trip the driver is working now: the first one that is not complete.
  DriverTrip? get currentTrip {
    for (final trip in trips) {
      if (trip.status != TripStatus.completed) return trip;
    }
    return null;
  }

  List<DriverTrip> get scheduledTrips => trips
      .where((trip) => trip.status == TripStatus.scheduled)
      .toList(growable: false);

  List<DriverTrip> get upcomingTrips {
    final current = currentTrip;
    return trips
        .where(
          (trip) =>
              trip.status == TripStatus.scheduled &&
              trip.code != current?.code,
        )
        .toList(growable: false);
  }

  List<DriverTrip> get inTransitTrips => trips
      .where((trip) => trip.status == TripStatus.inTransit)
      .toList(growable: false);

  List<DriverTrip> get completedTrips => trips
      .where((trip) => trip.status == TripStatus.completed)
      .toList(growable: false);

  /// Returns an empty string when the departure is accepted, otherwise the
  /// reason the way the server would report it.
  String depart(DriverTrip trip) {
    if (trip.status == TripStatus.completed) {
      return 'This trip is already completed.';
    }
    if (trip.status == TripStatus.inTransit) {
      return 'This trip has already departed.';
    }
    if (!trip.readyToDepart) {
      final missing = trip.missingOriginScans;
      return 'Departure blocked: $missing '
          '${missing == 1 ? 'parcel has' : 'parcels have'} not been scanned '
          'as departed at ${trip.origin}. Hub staff must scan every parcel '
          'before the vehicle leaves.';
    }
    trip.status = TripStatus.inTransit;
    trip.departedAt = DateTime.now();
    trip.originScanned = trip.parcelCount;
    notifyListeners();
    return '';
  }

  /// Returns an empty string when the trip can close, otherwise the reason.
  String arrive(DriverTrip trip) {
    if (trip.status != TripStatus.inTransit) {
      return 'Only a trip that is in transit can be received at the destination.';
    }
    if (!trip.readyToClose) {
      final missing = trip.missingDestinationScans;
      return 'Receiving is not complete: $missing '
          '${missing == 1 ? 'parcel is' : 'parcels are'} still waiting for a '
          'destination scan at ${trip.destination}. The station must scan '
          'every parcel before the trip can close.';
    }
    trip.status = TripStatus.completed;
    trip.arrivedAt = DateTime.now();
    trip.destinationScanned = trip.parcelCount;
    notifyListeners();
    return '';
  }

  /// Demo-only helper: this build has no station scanner, so the receiving
  /// screen can simulate the station's scans for a walkthrough.
  void simulateDestinationScans(DriverTrip trip) {
    trip.destinationScanned = trip.parcelCount;
    notifyListeners();
  }

  List<DriverTrip> _seedTrips() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    DateTime at(int dayOffset, int hour, int minute) => DateTime(
      now.year,
      now.month,
      now.day + dayOffset,
      hour,
      minute,
    );

    final firstDeparture = start.add(const Duration(minutes: 45));
    final secondDeparture = start.add(const Duration(hours: 3, minutes: 30));

    return [
      DriverTrip(
        code: 'TRP-2406',
        origin: 'Laguna Province Hub',
        originArea: 'Calamba, Laguna',
        destination: 'Santa Cruz Station',
        destinationArea: 'Santa Cruz, Laguna',
        scheduledDeparture: firstDeparture,
        eta: firstDeparture.add(const Duration(hours: 1, minutes: 40)),
        distanceKm: 34,
        vehicle: 'Isuzu Elf 6-Wheeler',
        plate: 'NBC 4821',
        trackingNumbers: _trackingBatch(101, 12),
        originScanned: 12,
      ),
      DriverTrip(
        code: 'TRP-2407',
        origin: 'Santa Cruz Station',
        originArea: 'Santa Cruz, Laguna',
        destination: 'Pagsanjan Station',
        destinationArea: 'Pagsanjan, Laguna',
        scheduledDeparture: secondDeparture,
        eta: secondDeparture.add(const Duration(minutes: 50)),
        distanceKm: 14,
        vehicle: 'Isuzu Elf 6-Wheeler',
        plate: 'NBC 4821',
        trackingNumbers: _trackingBatch(207, 8),
        originScanned: 6,
      ),
      DriverTrip(
        code: 'TRP-2408',
        origin: 'Laguna Province Hub',
        originArea: 'Calamba, Laguna',
        destination: 'Lucena Station',
        destinationArea: 'Lucena, Quezon',
        scheduledDeparture: at(1, 7, 30),
        eta: at(1, 11, 0),
        distanceKm: 96,
        vehicle: 'Isuzu Elf 6-Wheeler',
        plate: 'NBC 4821',
        trackingNumbers: _trackingBatch(311, 20),
        originScanned: 20,
      ),
    ];
  }
}

List<String> _trackingBatch(int seed, int count) => List<String>.generate(
  count,
  (index) => _tracking(seed + index * 17),
  growable: false,
);

/// Deterministic, ULID-looking tracking numbers so the demo lists stay stable.
String _tracking(int seed) {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  var state = (seed * 2654435761) & 0x7fffffff;
  final out = StringBuffer('VND-01M');
  for (var i = 0; i < 23; i++) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    out.write(alphabet[(state >> 7) % alphabet.length]);
  }
  return out.toString();
}
