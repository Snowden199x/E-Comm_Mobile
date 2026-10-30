import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';
import 'package:vendo_driver/features/trips/screens/driver_trip_status_screen.dart';

class DriverDispatchScreen extends StatefulWidget {
  const DriverDispatchScreen({super.key, required this.tripCode});

  final String tripCode;

  @override
  State<DriverDispatchScreen> createState() => _DriverDispatchScreenState();
}

class _DriverDispatchScreenState extends State<DriverDispatchScreen> {
  bool _busy = false;

  Future<void> _showBlocked(String reason) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: VColors.redSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_circle_outline_rounded,
                    color: VColors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Departure blocked',
                    style: TextStyle(
                      color: VColors.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              style: const TextStyle(
                color: Color(0xFF544956),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ask the hub staff to scan the missing parcels. The trip cannot '
              'leave while a parcel is unscanned.',
              style: TextStyle(
                color: VColors.muted,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _depart(DriverTrip trip) async {
    if (_busy) return;
    final store = DriverStore.instance;

    if (!trip.readyToDepart) {
      await _showBlocked(store.depart(trip));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Depart this trip?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          '${trip.parcelCount} parcels will move to In Transit. '
          '${trip.destination} must scan every parcel on arrival.',
          style: const TextStyle(
            color: VColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Depart'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final reason = store.depart(trip);
    if (!mounted) return;
    setState(() => _busy = false);
    if (reason.isNotEmpty) {
      await _showBlocked(reason);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Trip departed. ${trip.parcelCount} parcels are now In Transit.',
        ),
      ),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DriverTripStatusScreen(tripCode: trip.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;
    final trip = store.tripByCode(widget.tripCode);

    if (trip == null) {
      return Scaffold(
        backgroundColor: VColors.background,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            DriverHeader(
              eyebrow: 'Dispatch',
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

    final ready = trip.readyToDepart;
    final missing = trip.missingOriginScans;

    return Scaffold(
      backgroundColor: VColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          DriverHeader(
            eyebrow: trip.code,
            title: 'Confirm dispatch',
            subtitle: 'Check the load, then release the trip to the road.',
            onBack: () => Navigator.of(context).maybePop(),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: VColors.raisinSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_shipping_outlined,
                              color: VColors.raisin,
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${trip.vehicle} · ${trip.plate}',
                                style: const TextStyle(
                                  color: VColors.ink,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              dateTimeLabel(trip.scheduledDeparture),
                              style: const TextStyle(
                                color: VColors.muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle('Departure checklist'),
                const SizedBox(height: 10),
                VCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _CheckRow(
                        ok: true,
                        title: 'Vehicle assigned',
                        detail: '${trip.vehicle} · ${trip.plate}',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _CheckRow(
                        ok: store.profile.licenseValid,
                        title: 'Driver license valid',
                        detail:
                            'Expires ${shortDateLabel(store.profile.licenseExpiry)}',
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _CheckRow(
                        ok: ready,
                        title: 'Origin departure scans',
                        detail:
                            '${trip.originScanned} of ${trip.parcelCount} parcels '
                            'scanned at ${trip.origin}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (ready)
                  const NoticeCard(
                    tone: NoticeTone.success,
                    icon: Icons.verified_outlined,
                    title: 'Load verified',
                    message:
                        'Every parcel is scanned as departed. Departing moves '
                        'the parcels to In Transit for the destination.',
                  )
                else
                  NoticeCard(
                    tone: NoticeTone.error,
                    icon: Icons.error_outline_rounded,
                    title: 'Departure blocked',
                    message:
                        '$missing ${missing == 1 ? 'parcel has' : 'parcels have'} '
                        'not been scanned as departed at ${trip.origin}. '
                        'The server will not let this trip leave until every '
                        'parcel is scanned.',
                  ),
                const SizedBox(height: 14),
                const NoticeCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Station scans are the proof',
                  message:
                      'Departing does not prove physical custody. The station '
                      'scans at both ends are the record, and the app never '
                      'invents them.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: DriverBottomAction(
        child: FilledButton(
          onPressed: _busy
              ? null
              : trip.status == TripStatus.scheduled
              ? () => _depart(trip)
              : () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DriverTripStatusScreen(tripCode: trip.code),
                    ),
                  );
                },
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: VColors.lin,
                  ),
                )
              : Text(
                  trip.status == TripStatus.scheduled
                      ? 'Depart trip'
                      : trip.status == TripStatus.inTransit
                      ? 'Open trip status'
                      : 'Trip completed',
                ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.title,
    required this.detail,
  });

  final bool ok;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: ok ? VColors.greenSoft : VColors.goldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.priority_high_rounded,
              color: ok ? VColors.green : const Color(0xFF8A6D1A),
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
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
      ),
    );
  }
}
