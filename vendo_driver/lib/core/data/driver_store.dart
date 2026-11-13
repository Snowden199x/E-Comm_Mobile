import 'dart:async';
import 'dart:math';

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
    Set<String>? originScans,
    Set<String>? destinationScans,
    this.destinationScanned = 0,
    this.status = TripStatus.scheduled,
    this.departedAt,
    this.arrivedAt,
  }) {
    // The fields start empty, so a trip built from a count alone never exposes
    // a null set to the screens that read them.
    if (originScans != null) originScannedTrackings = originScans;
    if (destinationScans != null) destinationScannedTrackings = destinationScans;
  }

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

  /// The tracking numbers behind [originScanned] and [destinationScanned], so a
  /// scan screen can tick the exact parcel instead of guessing from an index.
  Set<String> originScannedTrackings = <String>{};
  Set<String> destinationScannedTrackings = <String>{};

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

  /// True when the origin hub has a departure scan for this parcel. Sample
  /// trips only carry a count, so the first [originScanned] parcels stand in
  /// for it until the driver scans them.
  bool originScanRecorded(String tracking) {
    if (originScannedTrackings.isNotEmpty) {
      return originScannedTrackings.contains(tracking);
    }
    final index = trackingNumbers.indexOf(tracking);
    return index >= 0 && index < originScanned;
  }

  /// True when the destination hub has an arrival scan for this parcel.
  bool destinationScanRecorded(String tracking) {
    if (destinationScannedTrackings.isNotEmpty) {
      return destinationScannedTrackings.contains(tracking);
    }
    final index = trackingNumbers.indexOf(tracking);
    return index >= 0 && index < destinationScanned;
  }

  ParcelStage stageFor(String tracking) {
    if (status == TripStatus.completed || destinationScanRecorded(tracking)) {
      return ParcelStage.received;
    }
    if (status == TripStatus.inTransit) return ParcelStage.inTransit;
    if (originScanRecorded(tracking)) return ParcelStage.departed;
    return ParcelStage.awaitingOriginScan;
  }

  String get statusLabel => switch (status) {
    TripStatus.scheduled => 'Scheduled',
    TripStatus.inTransit => 'In transit',
    TripStatus.completed => 'Completed',
  };
}

/// What one load scan did, so the scan screen can say it plainly.
class LoadScanResult {
  const LoadScanResult({
    required this.ok,
    this.duplicate = false,
    this.scanned = 0,
    this.message = '',
  });

  final bool ok;

  /// The parcel already carried the scan, so nothing changed on the server.
  final bool duplicate;

  /// How many parcels this scan actually loaded.
  final int scanned;
  final String message;
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

/// One accrued per-stop shipping share from `GET /earnings`.
class DriverEarning {
  const DriverEarning({
    required this.orderNumber,
    required this.hub,
    required this.routePosition,
    required this.amount,
    required this.earnedAt,
  });

  final String orderNumber;
  final String hub;
  final int routePosition;
  final double amount;
  final DateTime? earnedAt;
}

/// The server's earnings summary plus the recent credits behind it.
class DriverEarnings {
  const DriverEarnings({
    required this.accruedTotal,
    required this.hubCredits,
    required this.rows,
  });

  /// Sum of the accrued lines the web has not settled yet. Not a payout.
  final double accruedTotal;
  final int hubCredits;
  final List<DriverEarning> rows;
}

/// One notification the web addressed to this driver's account. The app never
/// writes a notification; it only reads and marks them.
class DriverNotification {
  const DriverNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
}

/// One finished trip on the driver's history list. Kept apart from [DriverTrip]
/// because a closed trip carries no live scan state to act on.
class DriverTripHistoryEntry {
  const DriverTripHistoryEntry({
    required this.code,
    required this.origin,
    required this.destination,
    required this.vehicle,
    required this.parcelCount,
    required this.scheduledDeparture,
    required this.departedAt,
    required this.completedAt,
  });

  final String code;
  final String origin;
  final String destination;
  final String vehicle;
  final int parcelCount;
  final DateTime? scheduledDeparture;
  final DateTime? departedAt;
  final DateTime? completedAt;
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
    // The API marks each parcel, so a partially scanned load shows the parcels
    // that are really on the truck rather than the first N of them.
    final originScannedTrackings = <String>{};
    final destinationScannedTrackings = <String>{};
    for (final order in manifest) {
      final tracking = text(order['tracking_number']);
      if (tracking.isEmpty) continue;
      if (order['origin_scanned'] == true) originScannedTrackings.add(tracking);
      if (order['destination_scanned'] == true) {
        destinationScannedTrackings.add(tracking);
      }
    }

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
      originScans: originScannedTrackings,
      destinationScans: destinationScannedTrackings,
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

  /// The last earnings answer from Vendo, or null before the first load.
  DriverEarnings? earnings;

  bool earningsLoading = false;

  /// The last earnings failure, shown on the Earnings tab with a retry.
  String? earningsError;

  /// Set when the stored token was rejected while loading earnings.
  bool earningsSessionExpired = false;

  DateTime? earningsSyncedAt;

  /// Loads the accrued per-stop credits from `GET /earnings`. Runs on sign-in
  /// and on pull-to-refresh; a second call while one is running is ignored.
  Future<void> refreshEarnings() async {
    if (earningsLoading) return;
    earningsLoading = true;
    earningsError = null;
    notifyListeners();

    try {
      final data = await DriverApi.instance.earnings();
      final summary = data['summary'] as Map?;
      final rows = (data['earnings'] as List? ?? const [])
          .whereType<Map>()
          .toList(growable: false);

      double amount(Object? value) =>
          double.tryParse(value?.toString() ?? '') ?? 0;
      int number(Object? value) => value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '') ?? 0;
      String text(Object? value) => value == null ? '' : value.toString().trim();

      earnings = DriverEarnings(
        accruedTotal: amount(summary?['accrued_total']),
        hubCredits: number(summary?['hub_credits']),
        rows: rows.map((row) {
          return DriverEarning(
            orderNumber: text(row['order_number']),
            hub: text(row['hub']),
            routePosition: number(row['route_position']),
            amount: amount(row['amount']),
            earnedAt: DateTime.tryParse(text(row['earned_at']))?.toLocal(),
          );
        }).toList(growable: false),
      );
      earningsSyncedAt = DateTime.now();
      earningsSessionExpired = false;
    } on DriverApiException catch (error) {
      earningsError = error.isUnauthenticated
          ? 'Your session expired. Sign in again to load your earnings.'
          : error.message;
      earningsSessionExpired = error.isUnauthenticated;
    } catch (_) {
      earningsError =
          'Could not reach Vendo. Check the connection, then pull down to retry.';
    } finally {
      earningsLoading = false;
      notifyListeners();
    }
  }

  /// Notifications the web sent this account, newest first.
  List<DriverNotification> notifications = const [];

  bool notificationsLoading = false;

  String? notificationsError;

  bool notificationsSessionExpired = false;

  int unreadNotifications = 0;

  /// Loads `GET /notifications` and keeps the unread count the server reports,
  /// so the bell badge never guesses.
  Future<void> refreshNotifications() async {
    if (notificationsLoading) return;
    notificationsLoading = true;
    notificationsError = null;
    notifyListeners();

    try {
      final data = await DriverApi.instance.notifications();
      DateTime? instant(Object? value) =>
          DateTime.tryParse(value?.toString() ?? '')?.toLocal();
      String text(Object? value) => value == null ? '' : value.toString().trim();

      notifications = (data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((row) {
            return DriverNotification(
              id: (row['id'] as num?)?.toInt() ?? 0,
              type: text(row['type']),
              title: text(row['title']),
              message: text(row['message']),
              createdAt: instant(row['created_at']),
              readAt: instant(row['read_at']),
            );
          })
          .toList(growable: false);
      unreadNotifications = (data['unread_count'] as num?)?.toInt() ??
          notifications.where((item) => item.isUnread).length;
      notificationsSessionExpired = false;
    } on DriverApiException catch (error) {
      notificationsError = error.isUnauthenticated
          ? 'Your session expired. Sign in again to load your notifications.'
          : error.message;
      notificationsSessionExpired = error.isUnauthenticated;
    } catch (_) {
      notificationsError =
          'Could not reach Vendo. Check the connection, then try again.';
    } finally {
      notificationsLoading = false;
      notifyListeners();
    }
  }

  /// Marks one notification read locally, then tells the server. A failed call
  /// puts the row back so the badge cannot drift from what the web holds.
  Future<void> markNotificationRead(int notificationId) async {
    final index = notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0 || !notifications[index].isUnread) return;

    final previous = notifications[index];
    notifications = [...notifications]
      ..[index] = DriverNotification(
        id: previous.id,
        type: previous.type,
        title: previous.title,
        message: previous.message,
        createdAt: previous.createdAt,
        readAt: DateTime.now(),
      );
    unreadNotifications = unreadNotifications > 0 ? unreadNotifications - 1 : 0;
    notifyListeners();

    try {
      await DriverApi.instance.markNotificationRead(notificationId);
    } catch (_) {
      notifications = [...notifications]..[index] = previous;
      unreadNotifications += 1;
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (unreadNotifications == 0) return;
    final now = DateTime.now();
    notifications = notifications
        .map(
          (item) => item.isUnread
              ? DriverNotification(
                  id: item.id,
                  type: item.type,
                  title: item.title,
                  message: item.message,
                  createdAt: item.createdAt,
                  readAt: now,
                )
              : item,
        )
        .toList(growable: false);
    unreadNotifications = 0;
    notifyListeners();

    try {
      await DriverApi.instance.markAllNotificationsRead();
    } catch (_) {
      // Resync instead of leaving the app claiming reads the web never got.
      await refreshNotifications();
    }
  }

  /// The trips this driver already closed, newest first.
  List<DriverTripHistoryEntry> tripHistory = const [];

  bool tripHistoryLoading = false;

  String? tripHistoryError;

  bool tripHistorySessionExpired = false;

  Future<void> refreshTripHistory() async {
    if (tripHistoryLoading) return;
    tripHistoryLoading = true;
    tripHistoryError = null;
    notifyListeners();

    try {
      final raw = await DriverApi.instance.tripHistory();
      DateTime? instant(Object? value) =>
          DateTime.tryParse(value?.toString() ?? '')?.toLocal();
      String text(Object? value) => value == null ? '' : value.toString().trim();

      tripHistory = raw.map((trip) {
        final origin = trip['origin'] as Map?;
        final destination = trip['destination'] as Map?;
        final vehicle = trip['vehicle'] as Map?;
        return DriverTripHistoryEntry(
          code: text(trip['code']),
          origin: text(origin?['name']),
          destination: text(destination?['name']),
          vehicle: [
            text(vehicle?['type']),
            text(vehicle?['plate_number']),
          ].where((part) => part.isNotEmpty).join(' · '),
          parcelCount: (trip['parcel_count'] as num?)?.toInt() ?? 0,
          scheduledDeparture: instant(trip['scheduled_departure_at']),
          departedAt: instant(trip['departed_at']),
          completedAt: instant(trip['arrived_at']),
        );
      }).toList(growable: false);
      tripHistorySessionExpired = false;
    } on DriverApiException catch (error) {
      tripHistoryError = error.isUnauthenticated
          ? 'Your session expired. Sign in again to load your trip history.'
          : error.message;
      tripHistorySessionExpired = error.isUnauthenticated;
    } catch (_) {
      tripHistoryError =
          'Could not reach Vendo. Check the connection, then pull down to retry.';
    } finally {
      tripHistoryLoading = false;
      notifyListeners();
    }
  }

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

  /// Scans one manifest parcel onto the truck.
  Future<LoadScanResult> scanLoadParcel(
    DriverTrip trip,
    String trackingNumber,
  ) => scanLoadParcels(trip, <String>[trackingNumber]);

  /// Scans everything one label names — a parcel label holds one tracking
  /// number, a container label holds several — in a single request. A live trip
  /// records the scans on the server and takes back the trip it returns, so the
  /// origin count is the server's own count; a sample trip keeps them on the
  /// device.
  Future<LoadScanResult> scanLoadParcels(
    DriverTrip trip,
    List<String> trackingNumbers,
  ) async {
    final codes = <String>[];
    for (final raw in trackingNumbers) {
      final code = raw.trim();
      if (code.isNotEmpty && !codes.contains(code)) codes.add(code);
    }
    if (codes.isEmpty) {
      return const LoadScanResult(
        ok: false,
        message: 'Scan or type a tracking number.',
      );
    }
    if (trip.status != TripStatus.scheduled) {
      return const LoadScanResult(
        ok: false,
        message: 'This trip has already left the origin hub.',
      );
    }

    final onManifest = codes
        .where(trip.trackingNumbers.contains)
        .toList(growable: false);
    final unknown = codes.length - onManifest.length;
    if (onManifest.isEmpty) {
      return LoadScanResult(
        ok: false,
        message: codes.length == 1
            ? '${codes.first} is not on this trip manifest.'
            : 'None of those ${codes.length} tracking numbers is on this trip '
                  'manifest.',
      );
    }

    final pending = onManifest
        .where((code) => !trip.originScanRecorded(code))
        .toList(growable: false);
    final already = onManifest.length - pending.length;

    if (!trip.isLive) {
      // A sample trip was seeded with a count, so turn that count into tracking
      // numbers before adding the new ones, or the earlier ticks disappear.
      if (trip.originScannedTrackings.isEmpty) {
        trip.originScannedTrackings.addAll(
          trip.trackingNumbers.take(trip.originScanned),
        );
      }
      trip.originScannedTrackings.addAll(pending);
      trip.originScanned = trip.originScannedTrackings.length;
      notifyListeners();
      return LoadScanResult(
        ok: true,
        duplicate: pending.isEmpty,
        scanned: pending.length,
        message: _scanMessage(trip, pending.length, already, unknown),
      );
    }

    if (pending.isEmpty) {
      return LoadScanResult(
        ok: true,
        duplicate: true,
        message: _scanMessage(trip, 0, already, unknown),
      );
    }

    try {
      final data = await DriverApi.instance.scanParcels(
        trip.id!,
        pending,
        _scanKey(),
      );
      _replaceWithApiTrip(Map<String, dynamic>.from(data['trip'] as Map));
      final serverMessage = data['message']?.toString() ?? '';
      final scanned = (data['scanned'] as num?)?.toInt() ?? pending.length;
      final unknownNote = unknown == 0
          ? ''
          : ' $unknown '
                '${unknown == 1 ? 'tracking number is' : 'tracking numbers are'}';
      return LoadScanResult(
        ok: true,
        duplicate: data['duplicate'] == true,
        scanned: scanned,
        message: serverMessage.isEmpty
            ? _scanMessage(trip, scanned, already, unknown)
            : '$serverMessage$unknownNote',
      );
    } on DriverApiException catch (error) {
      sessionExpired = error.isUnauthenticated;
      return LoadScanResult(ok: false, message: error.message);
    } catch (_) {
      return const LoadScanResult(
        ok: false,
        message: 'Could not reach Vendo. The scan was not saved; try again.',
      );
    }
  }

  /// One sentence a driver can act on after a label is scanned.
  String _scanMessage(DriverTrip trip, int scanned, int already, int unknown) {
    final parts = <String>[];
    if (scanned > 0) {
      parts.add(
        '$scanned ${scanned == 1 ? 'parcel' : 'parcels'} scanned. '
        '${trip.originScanned} of ${trip.parcelCount} on board.',
      );
    }
    if (scanned == 0 && already > 0) {
      parts.add(
        already == 1
            ? 'That parcel was already scanned.'
            : 'Those parcels were already scanned.',
      );
    }
    if (unknown > 0) {
      parts.add(
        '$unknown not on this manifest.',
      );
    }
    return parts.isEmpty ? 'Nothing was scanned.' : parts.join(' ');
  }

  /// A v4 UUID, so a repeated tap or a retried request is not recorded twice.
  String _scanKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
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
        // Closing the trip can accrue the driver's per-stop credits, so reload
        // the ledger in the background instead of waiting for a manual pull.
        unawaited(refreshEarnings());
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
