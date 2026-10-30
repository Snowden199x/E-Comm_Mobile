import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';
import 'package:vendo_driver/features/trips/screens/driver_dispatch_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_manifest_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_trip_status_screen.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({
    super.key,
    required this.onOpenTrip,
    required this.onOpenTab,
  });

  final ValueChanged<String> onOpenTrip;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;
    final profile = store.profile;
    final current = store.currentTrip;
    final upcoming = store.upcomingTrips;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final firstName = profile.name.split(' ').first;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DriverHeader(
          eyebrow: 'Vendo Xpress · Transport',
          title: '$greeting,\n$firstName.',
          subtitle: '${profile.hub} · ${profile.company}',
          trailing: _Avatar(initials: profile.initials),
        ),
        Padding(
          padding: vPageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsRow(store: store),
              const SizedBox(height: 22),
              if (current != null) ...[
                SectionTitle(
                  'Current trip',
                  trailing: TextButton(
                    onPressed: () => onOpenTab(1),
                    child: const Text('All trips'),
                  ),
                ),
                const SizedBox(height: 8),
                _CurrentTripCard(
                  trip: current,
                  onOpenTrip: onOpenTrip,
                  onOpenManifest: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DriverManifestScreen(
                        tripCode: current.code,
                      ),
                    ),
                  ),
                ),
              ] else
                EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No active trip',
                  message:
                      'Every trip on this device is complete. Your hub will '
                      'assign the next run to your vehicle.',
                  action: OutlinedButton(
                    onPressed: () => onOpenTab(1),
                    child: const Text('View completed trips'),
                  ),
                ),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 24),
                const SectionTitle('Upcoming trips'),
                const SizedBox(height: 10),
                for (final trip in upcoming) ...[
                  UpcomingTripTile(
                    trip: trip,
                    onTap: () => onOpenTrip(trip.code),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 20),
              const _NoCashNote(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.store});

  final DriverStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.trips
        .where((trip) => trip.status != TripStatus.completed)
        .length;
    final onboard = store.inTransitTrips.fold<int>(
      0,
      (total, trip) => total + trip.parcelCount,
    );
    final next = store.scheduledTrips.isEmpty
        ? null
        : store.scheduledTrips.first.scheduledDeparture;

    return VCard(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          _Stat(value: '$active', label: 'Active trips'),
          const _StatDivider(),
          _Stat(value: '$onboard', label: 'Parcels onboard'),
          const _StatDivider(),
          _Stat(
            value: next == null ? '—' : timeLabel(next),
            label: 'Next departure',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: VColors.prune,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: VColors.muted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: VColors.border);
  }
}

class _CurrentTripCard extends StatelessWidget {
  const _CurrentTripCard({
    required this.trip,
    required this.onOpenTrip,
    required this.onOpenManifest,
  });

  final DriverTrip trip;
  final ValueChanged<String> onOpenTrip;
  final VoidCallback onOpenManifest;

  @override
  Widget build(BuildContext context) {
    final inTransit = trip.status == TripStatus.inTransit;

    return VCard(
      padding: const EdgeInsets.all(16),
      borderColor: inTransit ? const Color(0xFFEBD2C9) : VColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                trip.code,
                style: const TextStyle(
                  color: VColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TripStatusPill(status: trip.status),
            ],
          ),
          const SizedBox(height: 14),
          TripRoute(trip: trip, compact: true),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: inTransit ? VColors.briqueSoft : VColors.goldSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  inTransit
                      ? Icons.local_shipping_outlined
                      : Icons.schedule_rounded,
                  color: inTransit ? VColors.brique : const Color(0xFF8A6D1A),
                  size: 16,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    inTransit
                        ? 'Departed ${timeLabel(trip.departedAt ?? trip.scheduledDeparture)} · ETA ${timeLabel(trip.eta)}'
                        : 'Departs ${dateTimeLabel(trip.scheduledDeparture)}',
                    style: const TextStyle(
                      color: VColors.ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: VColors.raisin,
              ),
              const SizedBox(width: 6),
              Text(
                '${trip.parcelCount} parcels',
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!inTransit)
                Text(
                  trip.readyToDepart
                      ? 'All scanned at origin'
                      : '${trip.missingOriginScans} still unscanned',
                  style: TextStyle(
                    color: trip.readyToDepart
                        ? VColors.green
                        : const Color(0xFF8A6D1A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => inTransit
                              ? DriverTripStatusScreen(tripCode: trip.code)
                              : DriverDispatchScreen(tripCode: trip.code),
                        ),
                      );
                    },
                    child: Text(inTransit ? 'Trip status' : 'Confirm dispatch'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: onOpenManifest,
                    child: const Text('Manifest'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onOpenTrip(trip.code),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Trip details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCashNote extends StatelessWidget {
  const _NoCashNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.shield_outlined,
          color: VColors.muted,
          size: 17,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Drivers never collect COD cash. Cash stays with the Rider and '
            'travels through the hubs, not through this app.',
            style: TextStyle(
              color: VColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
