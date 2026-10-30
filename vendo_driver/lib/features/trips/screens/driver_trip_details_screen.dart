import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';
import 'package:vendo_driver/features/trips/screens/driver_dispatch_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_manifest_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_trip_status_screen.dart';

class DriverTripDetailsScreen extends StatelessWidget {
  const DriverTripDetailsScreen({super.key, required this.tripCode});

  final String tripCode;

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.tripByCode(tripCode);
        if (trip == null) {
          return Scaffold(
            backgroundColor: VColors.background,
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                DriverHeader(
                  eyebrow: 'Trip',
                  title: 'Trip not found',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: vPageInsets,
                  child: const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'This trip is no longer on the device',
                    message: 'Open the trip board again to refresh your work.',
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: VColors.background,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              DriverHeader(
                eyebrow: 'Trip',
                title: trip.code,
                subtitle: '${trip.origin}  →  ${trip.destination}',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: TripStatusPill(status: trip.status),
              ),
              Padding(
                padding: vPageInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TripRoute(trip: trip),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _ScheduleBlock(
                                  label: 'Scheduled departure',
                                  value: dateTimeLabel(
                                    trip.scheduledDeparture,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _ScheduleBlock(
                                  label: 'Estimated arrival',
                                  value: dateTimeLabel(trip.eta),
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Trip information'),
                    const SizedBox(height: 10),
                    VCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          InfoRow(
                            icon: Icons.local_shipping_outlined,
                            label: 'Vehicle',
                            value: trip.vehicle,
                            trailing: StatusPill(
                              label: trip.plate,
                              foreground: VColors.raisin,
                              background: VColors.raisinSoft,
                            ),
                          ),
                          const SizedBox(height: 14),
                          InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Driver',
                            value: store.profile.name,
                          ),
                          const SizedBox(height: 14),
                          InfoRow(
                            icon: Icons.straighten_rounded,
                            label: 'Route distance',
                            value: '${trip.distanceKm.toStringAsFixed(0)} km',
                          ),
                          const SizedBox(height: 14),
                          InfoRow(
                            icon: Icons.inventory_2_outlined,
                            label: 'Manifest',
                            value:
                                '${trip.parcelCount} parcels · '
                                '${trip.originScanned} origin scans',
                            trailing: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DriverManifestScreen(
                                    tripCode: trip.code,
                                  ),
                                ),
                              ),
                              child: const Text('Open'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ScanProgress(trip: trip),
                    if (trip.status == TripStatus.completed) ...[
                      const SizedBox(height: 16),
                      NoticeCard(
                        icon: Icons.check_circle_outline_rounded,
                        tone: NoticeTone.success,
                        title: 'Trip completed',
                        message:
                            '${trip.destination} received every parcel. '
                            'The vehicle and driver are released.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    const NoticeCard(
                      icon: Icons.shield_outlined,
                      title: 'Receipt is proven by station scans',
                      message:
                          'This screen shows the plan and the scans on record. '
                          'It never replaces a station scan.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: DriverBottomAction(
            child: FilledButton(
              onPressed: () {
                final route = switch (trip.status) {
                  TripStatus.scheduled => MaterialPageRoute<void>(
                    builder: (_) => DriverDispatchScreen(tripCode: trip.code),
                  ),
                  TripStatus.inTransit => MaterialPageRoute<void>(
                    builder: (_) =>
                        DriverTripStatusScreen(tripCode: trip.code),
                  ),
                  TripStatus.completed => null,
                };
                if (route == null) {
                  Navigator.of(context).maybePop();
                } else {
                  Navigator.of(context).push(route);
                }
              },
              child: Text(
                switch (trip.status) {
                  TripStatus.scheduled => 'Confirm dispatch',
                  TripStatus.inTransit => 'Open trip status',
                  TripStatus.completed => 'Back to trips',
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleBlock extends StatelessWidget {
  const _ScheduleBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: VColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: VColors.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    final originValue = trip.parcelCount == 0
        ? 0.0
        : trip.originScanned / trip.parcelCount;
    final destinationValue = trip.parcelCount == 0
        ? 0.0
        : trip.destinationScanned / trip.parcelCount;

    return VCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Scan progress'),
          const SizedBox(height: 14),
          _ProgressLine(
            label: 'Scanned at origin',
            value: '${trip.originScanned} of ${trip.parcelCount}',
            progress: originValue,
            color: VColors.raisin,
          ),
          const SizedBox(height: 14),
          _ProgressLine(
            label: 'Scanned at destination',
            value: '${trip.destinationScanned} of ${trip.parcelCount}',
            progress: destinationValue,
            color: VColors.green,
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: VColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: VColors.border,
          ),
        ),
      ],
    );
  }
}
