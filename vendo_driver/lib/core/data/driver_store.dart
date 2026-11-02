import 'package:flutter/foundation.dart';
import 'package:vendo_driver/core/api/driver_api.dart';

/// The driver's stage in a trip. Mirrors the web status names.
enum TripStatus { scheduled, inTransit, completed }

/// What the driver sees for one parcel. Deliberately has no addresses, prices
/// or COD state: a driver only moves the parcel.
enum ParcelStage { awaitingOriginScan, departed, inTransit, received }

class DriverTrip {
  DriverTrip({
    this.id,
    this.tripType = '',
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

  /// The trip id on the web. Demo trips have none, which is how the app tells
  /// a trip the hub assigned from a sample one.
  final int? id;

  /// Hub to hub, station to station, or hub to station, as the web names it.
  final String tripType;

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

  /// True when this trip came from the web, so actions must go through the
  /// API instead of changing the copy on the device.
  bool get isLive => id != null;

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
    this.stationHub,
    this.stationHubArea,
    this.applyLabel,
  });

  final String name;
  final String email;
  final String phone;

  /// The Province Hub that owns the account.
  final String hub;
  final String hubArea;

  /// The Station Hub the driver is linked to, when the web has assigned one.
  final String? stationHub;
  final String? stationHubArea;

  /// Which hubs the application asked for, e.g. "Station Hub only".
  final String? applyLabel;

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

  /// Demo values shown before the first sign-in. A successful sign-in replaces
  /// them with the driver the web approved through [applySession].
  DriverProfile profile = DriverProfile(
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
    applyLabel: 'Province Hub only',
  );

  /// Replaces the placeholder profile with the signed-in driver from the Driver
  /// API (the same shape `POST /login` and `GET /me` return).
  void applySession(Map<String, dynamic> data) {
    final driver = Map<String, dynamic>.from(
      data['driver'] as Map? ?? const {},
    );
    final provinceHub = data['province_hub'] as Map?;
    final stationHub = data['station_hub'] as Map?;
    final company = data['company'] as Map?;

    String text(Object? value) => value == null ? '' : value.toString().trim();
    String area(Map? hub) => hub == null
        ? ''
        : [
            text(hub['municipality']),
            text(hub['province']),
          ].where((part) => part.isNotEmpty).join(', ');

    profile = DriverProfile(
      name: text(driver['name']).isEmpty ? profile.name : text(driver['name']),
      email: text(driver['email']),
      phone: text(driver['phone']),
      hub: text(provinceHub?['name']),
      hubArea: area(provinceHub),
      stationHub: text(stationHub?['name']).isEmpty
          ? null
          : text(stationHub?['name']),
      stationHubArea: stationHub == null ? null : area(stationHub),
      applyLabel: text(driver['apply_label']).isEmpty
          ? null
          : text(driver['apply_label']),
      company: text(company?['name']),
      licenseNumber: text(driver['license_number']),
      // A missing expiry is treated as expired: the server would refuse the
      // account anyway, so the app must not claim the licence is valid.
      licenseExpiry:
          DateTime.tryParse(text(driver['license_expires_at'])) ??
          DateTime(1970),
      vehicle: text(driver['vehicle_type']).isEmpty
          ? 'Not declared'
          : text(driver['vehicle_type']),
      plate: text(driver['plate_number']).isEmpty
          ? 'No plate'
          : text(driver['plate_number']),
    );
    notifyListeners();
  }

  /// Trips start as samples so an offline launch is not an empty board. The
  /// first successful [refreshTrips] clears and refills this same list, so the
  /// screens that hold on to it see the trips the hub assigned.
  late final List<DriverTrip> trips = _seedTrips();

  bool tripsLoading = false;

  /// False while the board still shows the sample trips.
  bool tripsAreLive = false;

  DateTime? tripsSyncedAt;

  /// The last refresh failure, shown on the home screen with a Retry action.
  String? tripsError;

  /// Set when the server rejects the stored token, so the app can offer a
  /// fresh sign-in instead of an endless retry.
  bool sessionExpired = false;

  /// Loads the trips the hub assigned to the signed-in driver. Safe to call on
  /// start-up and from pull-to-refresh; a second call while one is running is
  /// ignored so two refreshes cannot race each other.
  Future<void> refreshTrips() async {
    if (tripsLoading) return;
    tripsLoading = true;
    tripsError = null;
    notifyListeners();

    try {
      final raw = await DriverApi.instance.trips();
      trips
        ..clear()
        ..addAll(raw.map(_tripFromApi));
      tripsAreLive = true;
      tripsSyncedAt = DateTime.now();
      sessionExpired = false;
    } on DriverApiException catch (error) {
      tripsError = error.isUnauthenticated
          ? 'Your session expired. Sign in again to load your trips.'
          : error.message;
      sessionExpired = error.isUnauthenticated;
    } catch (_) {
      tripsError = 'Could not reach Vendo. Check the connection, then pull down to retry.';
    } finally {
      tripsLoading = false;
      notifyListeners();
    }
  }

  /// Maps one trip from `GET /trips`. The manifest is the only parcel detail a
  /// driver gets: tracking numbers and statuses, never addresses or prices.
  DriverTrip _tripFromApi(Map<String, dynamic> data) {
    String text(Object? value) => value == null ? '' : value.toString().trim();
    String area(Map? hub) => hub == null
        ? ''
        : [
            text(hub['municipality']),
            text(hub['province']),
          ].where((part) => part.isNotEmpty).join(', ');
    DateTime? instant(Object? value) =>
        DateTime.tryParse(text(value))?.toLocal();
    int number(Object? value) => value is num ? value.toInt() : 0;

    final origin = data['origin'] as Map?;
    final destination = data['destination'] as Map?;
    final vehicle = data['vehicle'] as Map?;
    final manifest = (data['manifest'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    final trackingNumbers = manifest
        .map((order) => text(order['tracking_number']))
        .where((tracking) => tracking.isNotEmpty)
        .toList(growable: false);

    // A trip without a schedule still needs a label, so the departure falls
    // back to when it actually left and then to now.
    final departure =
        instant(data['scheduled_departure_at']) ??
        instant(data['departed_at']) ??
        DateTime.now();

    return DriverTrip(
      id: (data['id'] as num?)?.toInt(),
      tripType: text(data['type']),
      code: text(data['code']),
      origin: text(origin?['name']),
      originArea: area(origin),
      destination: text(destination?['name']),
      destinationArea: area(destination),
      scheduledDeparture: departure,
      eta: instant(data['expected_arrival_at']) ?? departure,
      // The API carries no route length yet; the screens print it only when
      // it is known instead of showing "0 km".
      distanceKm: 0,
      vehicle: text(vehicle?['type']).isEmpty
          ? profile.vehicle
          : text(vehicle?['type']),
      plate: text(vehicle?['plate_number']).isEmpty
          ? profile.plate
          : text(vehicle?['plate_number']),
      trackingNumbers: trackingNumbers,
      originScanned: number(data['origin_scanned']),
      destinationScanned: number(data['destination_scanned']),
      status: switch (text(data['status'])) {
        'in_transit' => TripStatus.inTransit,
        'completed' => TripStatus.completed,
        _ => TripStatus.scheduled,
      },
      departedAt: instant(data['departed_at']),
      arrivedAt: instant(data['arrived_at']),
    );
  }

  /// Puts the trip the server just returned back on the board.
  void _replaceWithApiTrip(Map<String, dynamic> data) {
    final updated = _tripFromApi(data);
    final index = trips.indexWhere(
      (trip) => trip.id != null && trip.id == updated.id,
    );
    if (index >= 0) {
      trips[index] = updated;
    } else {
      trips.insert(0, updated);
    }
    notifyListeners();
  }

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
              trip.status == TripStatus.scheduled && trip.code != current?.code,
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
  /// reason. A live trip is departed on the server, which runs the same checks
  /// as [depart]; the local rules stay for the sample trips.
  Future<String> depart(DriverTrip trip) async {
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

    if (trip.isLive) {
      try {
        _replaceWithApiTrip(await DriverApi.instance.departTrip(trip.id!));
        return '';
      } on DriverApiException catch (error) {
        sessionExpired = error.isUnauthenticated;
        return error.message;
      } catch (_) {
        return 'Could not reach Vendo. The trip has not departed; try again '
            'when the connection is back.';
      }
    }

    trip.status = TripStatus.inTransit;
    trip.departedAt = DateTime.now();
    trip.originScanned = trip.parcelCount;
    notifyListeners();
    return '';
  }

  /// Returns an empty string when the trip can close, otherwise the reason.
  /// Live trips are completed on the server.
  Future<String> arrive(DriverTrip trip) async {
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

    if (trip.isLive) {
      try {
        _replaceWithApiTrip(await DriverApi.instance.arriveTrip(trip.id!));
        return '';
      } on DriverApiException catch (error) {
        sessionExpired = error.isUnauthenticated;
        return error.message;
      } catch (_) {
        return 'Could not reach Vendo. The trip is still open; try again when '
            'the connection is back.';
      }
    }

    trip.status = TripStatus.completed;
    trip.arrivedAt = DateTime.now();
    trip.destinationScanned = trip.parcelCount;
    notifyListeners();
    return '';
  }

  /// Demo-only helper for the sample trips: this build has no station scanner,
  /// so the receiving screen can simulate the station's scans for a
  /// walkthrough. A live trip ignores it, because its counts come from the
  /// station's real scans.
  void simulateDestinationScans(DriverTrip trip) {
    if (trip.isLive) return;
    trip.destinationScanned = trip.parcelCount;
    notifyListeners();
  }

  List<DriverTrip> _seedTrips() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute);

    DateTime at(int dayOffset, int hour, int minute) =>
        DateTime(now.year, now.month, now.day + dayOffset, hour, minute);

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
