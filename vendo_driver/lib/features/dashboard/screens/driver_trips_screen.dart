import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

enum _TripFilter { all, scheduled, inTransit, completed }

class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key, required this.onOpenTrip});

  final ValueChanged<String> onOpenTrip;

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  _TripFilter _filter = _TripFilter.all;

  List<DriverTrip> _visible(DriverStore store) {
    return switch (_filter) {
      _TripFilter.all => store.trips,
      _TripFilter.scheduled => store.scheduledTrips,
      _TripFilter.inTransit => store.inTransitTrips,
      _TripFilter.completed => store.completedTrips,
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;
    final visible = _visible(store);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const DriverHeader(
          eyebrow: 'Trip board',
          title: 'My trips',
          subtitle: 'Current and upcoming runs assigned to your vehicle.',
        ),
        Padding(
          padding: vPageInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'All',
                    count: store.trips.length,
                    selected: _filter == _TripFilter.all,
                    onTap: () => setState(() => _filter = _TripFilter.all),
                  ),
                  _FilterChip(
                    label: 'Scheduled',
                    count: store.scheduledTrips.length,
                    selected: _filter == _TripFilter.scheduled,
                    onTap: () => setState(() => _filter = _TripFilter.scheduled),
                  ),
                  _FilterChip(
                    label: 'In transit',
                    count: store.inTransitTrips.length,
                    selected: _filter == _TripFilter.inTransit,
                    onTap: () => setState(() => _filter = _TripFilter.inTransit),
                  ),
                  _FilterChip(
                    label: 'Completed',
                    count: store.completedTrips.length,
                    selected: _filter == _TripFilter.completed,
                    onTap: () => setState(() => _filter = _TripFilter.completed),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                EmptyState(
                  icon: Icons.route_outlined,
                  title: 'No trips here',
                  message: switch (_filter) {
                    _TripFilter.completed =>
                      'Trips appear here after the destination station scans '
                          'every parcel and you close the trip.',
                    _TripFilter.inTransit =>
                      'No vehicle is on the road right now.',
                    _TripFilter.scheduled =>
                      'No scheduled trips are waiting for dispatch.',
                    _TripFilter.all =>
                      'The hub has not assigned a trip to this device yet.',
                  },
                )
              else
                for (final trip in visible) ...[
                  TripCard(
                    trip: trip,
                    onTap: () => widget.onOpenTrip(trip.code),
                  ),
                  const SizedBox(height: 11),
                ],
              const SizedBox(height: 14),
              const NoticeCard(
                icon: Icons.hourglass_bottom_rounded,
                title: 'More trip tools are coming later',
                message:
                    'Cancellations, container scanning, per-parcel scan '
                    'status, incident reports and trip history are planned '
                    'for a later version.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? VColors.prune : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? VColors.prune : VColors.border,
            ),
          ),
          child: Text(
            '$label · $count',
            style: TextStyle(
              color: selected ? Colors.white : VColors.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
