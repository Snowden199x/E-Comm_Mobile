import 'package:flutter/material.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/auth/screens/driver_login_screen.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

/// The trips this driver already closed. The board only carries scheduled and
/// in-transit runs, so finished runs live here, newest first.
class DriverTripHistoryScreen extends StatefulWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  State<DriverTripHistoryScreen> createState() =>
      _DriverTripHistoryScreenState();
}

class _DriverTripHistoryScreenState extends State<DriverTripHistoryScreen> {
  @override
  void initState() {
    super.initState();
    DriverStore.instance.refreshTripHistory();
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;

    return Scaffold(
      backgroundColor: VColors.background,
      body: RefreshIndicator(
        color: VColors.brique,
        onRefresh: store.refreshTripHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            DriverHeader(
              eyebrow: 'Completed runs',
              title: 'Trip history',
              subtitle: 'Closed trips, newest first. Each one was completed at '
                  'its destination station.',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: vPageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (store.tripHistoryError != null)
                    NoticeCard(
                      tone: NoticeTone.error,
                      icon: Icons.cloud_off_rounded,
                      title: store.tripHistorySessionExpired
                          ? 'Session expired'
                          : 'History not loaded',
                      message: store.tripHistoryError!,
                      action: TextButton(
                        onPressed: store.tripHistorySessionExpired
                            ? () => _signInAgain(context)
                            : store.refreshTripHistory,
                        child: Text(
                          store.tripHistorySessionExpired ? 'Sign in' : 'Retry',
                        ),
                      ),
                    )
                  else if (store.tripHistory.isEmpty &&
                      store.tripHistoryLoading)
                    const VCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 26,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VColors.brique,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Loading your completed trips…',
                              style: TextStyle(
                                color: VColors.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (store.tripHistory.isEmpty)
                    const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No completed trips yet',
                      message:
                          'A trip appears here after the destination station '
                          'scans every parcel and you close the trip.',
                    )
                  else
                    for (final trip in store.tripHistory) ...[
                      _HistoryCard(trip: trip),
                      const SizedBox(height: 10),
                    ],
                  SizedBox(height: 8 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInAgain(BuildContext context) async {
    await DriverApi.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const DriverLoginScreen()),
      (route) => false,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.trip});

  final DriverTripHistoryEntry trip;

  @override
  Widget build(BuildContext context) {
    final completed = trip.completedAt;
    return VCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                trip.code.isEmpty ? 'Trip' : trip.code,
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: VColors.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: VColors.green,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.route_outlined,
                size: 17,
                color: VColors.raisin,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${trip.origin}  →  ${trip.destination}',
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 16,
                color: VColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  completed == null
                      ? 'Completion time not recorded'
                      : 'Closed ${shortDateLabel(completed)} · '
                          '${timeLabel(completed)}',
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: VColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    '${trip.parcelCount} '
                        '${trip.parcelCount == 1 ? 'parcel' : 'parcels'}',
                    if (trip.vehicle.isNotEmpty) trip.vehicle,
                  ].join(' · '),
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
