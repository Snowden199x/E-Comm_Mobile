import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

class DriverHandoverScreen extends StatefulWidget {
  const DriverHandoverScreen({super.key, required this.tripCode});

  final String tripCode;

  @override
  State<DriverHandoverScreen> createState() => _DriverHandoverScreenState();
}

class _DriverHandoverScreenState extends State<DriverHandoverScreen> {
  bool _busy = false;

  Future<void> _showBlocked(DriverTrip trip) {
    final missing = trip.missingDestinationScans;
    final reason =
        '$missing ${missing == 1 ? 'parcel is' : 'parcels are'} still waiting '
        'for a destination scan at ${trip.destination}.';

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
                    color: VColors.goldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: Color(0xFF8A6D1A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Receiving not complete',
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
              'Station staff scan every parcel. The trip closes only when the '
              'last one is received — this build has no station scanner yet.',
              style: TextStyle(
                color: VColors.muted,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  DriverStore.instance.simulateDestinationScans(trip);
                  Navigator.of(sheetContext).pop();
                },
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Demo: simulate station scans'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Wait for the station'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _arrive(DriverTrip trip) async {
    if (_busy) return;
    if (!trip.readyToClose) {
      await _showBlocked(trip);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Close this trip?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          '${trip.destination} has scanned all ${trip.parcelCount} parcels. '
          'Closing the trip releases ${trip.vehicle} (${trip.plate}).',
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
            child: const Text('Close trip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final reason = DriverStore.instance.arrive(trip);
    if (!mounted) return;
    setState(() => _busy = false);
    if (reason.isNotEmpty) {
      await _showBlocked(trip);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip completed. The vehicle is released.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final trip = store.tripByCode(widget.tripCode);
        if (trip == null) {
          return Scaffold(
            backgroundColor: VColors.background,
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                DriverHeader(
                  eyebrow: 'Handover',
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

        if (trip.status == TripStatus.completed) {
          return _CompletedView(trip: trip);
        }

        final pending = trip.trackingNumbers
            .skip(trip.destinationScanned)
            .toList(growable: false);
        final progress = trip.parcelCount == 0
            ? 0.0
            : trip.destinationScanned / trip.parcelCount;
        final ready = trip.readyToClose;

        return Scaffold(
          backgroundColor: VColors.background,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              DriverHeader(
                eyebrow: trip.code,
                title: 'Destination handover',
                subtitle: 'Present the shipment at ${trip.destination}.',
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
                        children: [
                          InfoRow(
                            icon: Icons.warehouse_outlined,
                            label: 'Receiving station',
                            value: trip.destination,
                          ),
                          const SizedBox(height: 14),
                          InfoRow(
                            icon: Icons.place_outlined,
                            label: 'Area',
                            value: trip.destinationArea,
                          ),
                          const SizedBox(height: 14),
                          InfoRow(
                            icon: Icons.inventory_2_outlined,
                            label: 'Parcels expected',
                            value: '${trip.parcelCount} parcels from ${trip.origin}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('Receiving progress'),
                    const SizedBox(height: 10),
                    VCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${trip.destinationScanned} of ${trip.parcelCount} scanned',
                                style: const TextStyle(
                                  color: VColors.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              StatusPill(
                                label: ready ? 'Ready' : 'Waiting',
                                foreground: ready
                                    ? VColors.green
                                    : const Color(0xFF8A6D1A),
                                background: ready
                                    ? VColors.greenSoft
                                    : VColors.goldSoft,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              color: ready ? VColors.green : VColors.brique,
                              backgroundColor: VColors.border,
                            ),
                          ),
                          if (pending.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Awaiting station scan (${pending.length})',
                              style: const TextStyle(
                                color: VColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final tracking in pending.take(5))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: VColors.muted,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tracking,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: VColors.ink,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      'Awaiting scan',
                                      style: TextStyle(
                                        color: VColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (pending.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 13,
                                  top: 4,
                                ),
                                child: Text(
                                  '+${pending.length - 5} more parcels',
                                  style: const TextStyle(
                                    color: VColors.muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (ready)
                      const NoticeCard(
                        tone: NoticeTone.success,
                        icon: Icons.verified_outlined,
                        title: 'Ready to close',
                        message:
                            'Every parcel is scanned at the destination. '
                            'Closing the trip releases the vehicle and driver.',
                      )
                    else
                      NoticeCard(
                        tone: NoticeTone.warning,
                        icon: Icons.hourglass_bottom_rounded,
                        title: 'Receiving not complete',
                        message:
                            '${trip.missingDestinationScans} '
                            '${trip.missingDestinationScans == 1 ? 'parcel is' : 'parcels are'} '
                            'still waiting for a destination scan at '
                            '${trip.destination}. The trip cannot close yet.',
                        action: TextButton.icon(
                          onPressed: () => store.simulateDestinationScans(trip),
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 16,
                          ),
                          label: const Text('Demo: simulate station scans'),
                        ),
                      ),
                    const SizedBox(height: 14),
                    const NoticeCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Receipt is proven by scans',
                      message:
                          'Nothing here claims a parcel is received. Only the '
                          'station scans move the count.',
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: DriverBottomAction(
            child: FilledButton(
              onPressed: _busy ? null : () => _arrive(trip),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: VColors.lin,
                      ),
                    )
                  : const Text('Arrive and close trip'),
            ),
          ),
        );
      },
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({required this.trip});

  final DriverTrip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          DriverHeader(
            eyebrow: trip.code,
            title: 'Trip completed',
            subtitle: '${trip.destination} received every parcel.',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Padding(
            padding: vPageInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VCard(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: VColors.greenSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: VColors.green,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Every parcel is received',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: VColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${trip.destination} scanned all ${trip.parcelCount} '
                        'parcels. The trip is closed and '
                        '${trip.vehicle} (${trip.plate}) is released.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VColors.muted,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _CompletedTime(
                              label: 'Departed',
                              value: timeLabel(
                                trip.departedAt ?? trip.scheduledDeparture,
                              ),
                              alignEnd: false,
                            ),
                          ),
                          Expanded(
                            child: _CompletedTime(
                              label: 'Arrived',
                              value: timeLabel(
                                trip.arrivedAt ?? DateTime.now(),
                              ),
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          child: const Text('Back to home'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const NoticeCard(
                  tone: NoticeTone.success,
                  icon: Icons.task_alt_rounded,
                  title: 'Vehicle released',
                  message:
                      'The hub can assign the next trip. If a parcel was '
                      'missing or damaged during this run, tell hub staff '
                      'directly — incident reports are not in this version.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTime extends StatelessWidget {
  const _CompletedTime({
    required this.label,
    required this.value,
    required this.alignEnd,
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
          style: const TextStyle(color: VColors.muted, fontSize: 10.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: VColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
