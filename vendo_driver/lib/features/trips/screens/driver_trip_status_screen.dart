import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';
import 'package:vendo_driver/features/trips/screens/driver_dispatch_screen.dart';
import 'package:vendo_driver/features/trips/screens/driver_handover_screen.dart';

class DriverTripStatusScreen extends StatelessWidget {
  const DriverTripStatusScreen({super.key, required this.tripCode});

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
                  eyebrow: 'Trip status',
                  title: 'Trip not found',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: vPageInsets,
                  child: const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'This trip is no longer on the device',
                    message: 'Return to the trip board and open it again.',
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
                eyebrow: trip.code,
                title: trip.status == TripStatus.completed
                    ? 'Trip completed'
                    : 'On the road',
                subtitle: '${trip.origin}  →  ${trip.destination}',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: TripStatusPill(status: trip.status),
                bottom: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x26FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: VColors.lin,
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Estimated arrival',
                          style: TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      Text(
                        timeLabel(trip.eta),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: vPageInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trip.status == TripStatus.scheduled) ...[
                      NoticeCard(
                        icon: Icons.info_outline_rounded,
                        title: 'This trip has not departed',
                        message:
                            'Confirm the dispatch checklist before the trip '
                            'can move to In Transit.',
                        action: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => DriverDispatchScreen(
                                  tripCode: trip.code,
                                ),
                              ),
                            );
                          },
                          child: const Text('Open dispatch confirmation'),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (trip.status == TripStatus.inTransit) ...[
                      const SectionTitle('Trip progress'),
                      const SizedBox(height: 10),
                      VCard(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        child: Column(
                          children: [
                            _TimelineStep(
                              icon: Icons.inventory_2_outlined,
                              title: 'Departed ${trip.origin}',
                              subtitle:
                                  '${timeLabel(trip.departedAt ?? trip.scheduledDeparture)} · '
                                  '${trip.parcelCount} parcels onboard',
                              state: _TimelineState.done,
                            ),
                            _TimelineConnector(done: true),
                            _TimelineStep(
                              icon: Icons.near_me_outlined,
                              title: 'In transit',
                              subtitle:
                                  '${trip.distanceKm.toStringAsFixed(0)} km route to '
                                  '${trip.destination}',
                              state: _TimelineState.active,
                            ),
                            _TimelineConnector(done: false),
                            _TimelineStep(
                              icon: Icons.flag_outlined,
                              title: 'Arrive ${trip.destination}',
                              subtitle:
                                  'ETA ${timeLabel(trip.eta)} · station scans every parcel',
                              state: _TimelineState.pending,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      VCard(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          children: [
                            _Metric(
                              value: '${trip.parcelCount}',
                              label: 'Parcels onboard',
                            ),
                            const _MetricDivider(),
                            _Metric(
                              value:
                                  '${trip.destinationScanned}/${trip.parcelCount}',
                              label: 'Received',
                            ),
                            const _MetricDivider(),
                            _Metric(
                              value:
                                  '${trip.distanceKm.toStringAsFixed(0)} km',
                              label: 'Route',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                    const SectionTitle('Vehicle'),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const NoticeCard(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Handover is scanned, not assumed',
                      message:
                          'Present the shipment to station staff. They scan '
                          'every parcel, and only then can the trip be closed.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: trip.status == TripStatus.completed
              ? null
              : DriverBottomAction(
                  child: FilledButton(
                    onPressed: () {
                      if (trip.status == TripStatus.scheduled) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DriverDispatchScreen(tripCode: trip.code),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DriverHandoverScreen(tripCode: trip.code),
                          ),
                        );
                      }
                    },
                    child: Text(
                      trip.status == TripStatus.scheduled
                          ? 'Confirm dispatch'
                          : 'Destination handover',
                    ),
                  ),
                ),
        );
      },
    );
  }
}

enum _TimelineState { done, active, pending }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _TimelineState state;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (state) {
      _TimelineState.done => (VColors.greenSoft, VColors.green),
      _TimelineState.active => (VColors.briqueSoft, VColors.brique),
      _TimelineState.pending => (const Color(0xFFF1EEF1), VColors.muted),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: foreground, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: state == _TimelineState.pending
                      ? VColors.muted
                      : VColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: VColors.muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 22,
      margin: const EdgeInsets.only(left: 17, top: 3, bottom: 3),
      color: done ? VColors.green : VColors.border,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

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
              fontSize: 17,
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

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: VColors.border);
  }
}
