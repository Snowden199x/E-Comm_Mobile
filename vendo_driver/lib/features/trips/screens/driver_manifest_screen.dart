import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

class DriverManifestScreen extends StatefulWidget {
  const DriverManifestScreen({
    super.key,
    this.tripCode,
    this.embedded = false,
  });

  /// A specific trip, used when the manifest is opened from a trip.
  final String? tripCode;

  /// True inside the bottom-navigation tab, where the app bar is not shown.
  final bool embedded;

  @override
  State<DriverManifestScreen> createState() => _DriverManifestScreenState();
}

class _DriverManifestScreenState extends State<DriverManifestScreen> {
  final TextEditingController _search = TextEditingController();
  String? _selectedCode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCode = widget.tripCode;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DriverTrip? _trip(DriverStore store) {
    final code = widget.tripCode ?? _selectedCode;
    if (code != null) {
      final found = store.tripByCode(code);
      if (found != null) return found;
    }
    return store.currentTrip;
  }

  List<DriverTrip> _selectableTrips(DriverStore store) {
    final trips = store.trips
        .where((trip) => trip.status != TripStatus.completed)
        .toList(growable: false);
    if (trips.isEmpty) return trips;
    final current = _trip(store);
    if (current != null && !trips.any((trip) => trip.code == current.code)) {
      return [current, ...trips];
    }
    return trips;
  }

  @override
  Widget build(BuildContext context) {
    final store = DriverStore.instance;
    final trip = _trip(store);
    final selectable = _selectableTrips(store);

    return Scaffold(
      backgroundColor: VColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          DriverHeader(
            eyebrow: widget.embedded ? 'Manifest' : 'Trip manifest',
            title: trip == null ? 'No trip yet' : 'Parcels on board',
            subtitle: trip == null
                ? 'A manifest appears when the hub assigns a trip.'
                : '${trip.origin}  →  ${trip.destination}',
            onBack: widget.embedded
                ? null
                : () => Navigator.of(context).maybePop(),
            trailing: trip == null
                ? null
                : TripStatusPill(status: trip.status),
            bottom: trip == null
                ? null
                : Row(
                    children: [
                      Expanded(
                        child: _HeaderMetric(
                          value: '${trip.parcelCount}',
                          label: 'Parcels',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 26,
                        color: const Color(0x33FFFFFF),
                      ),
                      Expanded(
                        child: _HeaderMetric(
                          value: '${trip.originScanned}',
                          label: 'Origin scans',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 26,
                        color: const Color(0x33FFFFFF),
                      ),
                      Expanded(
                        child: _HeaderMetric(
                          value: '${trip.destinationScanned}',
                          label: 'Received',
                        ),
                      ),
                    ],
                  ),
          ),
          if (trip != null)
            Padding(
              padding: vPageInsets,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.embedded && selectable.length > 1) ...[
                    _TripSelector(
                      trips: selectable,
                      selectedCode: trip.code,
                      onChanged: (code) =>
                          setState(() => _selectedCode = code),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!widget.embedded) ...[
                    VCard(
                      padding: const EdgeInsets.all(15),
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
                              Text(
                                '${trip.parcelCount} parcels',
                                style: const TextStyle(
                                  color: VColors.ink,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TripRoute(trip: trip, compact: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  TextField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    cursorColor: VColors.prune,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search a tracking number',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ParcelList(trip: trip, query: _query),
                  const SizedBox(height: 18),
                  const NoticeCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Manifest rules',
                    message:
                        'Only the tracking number and parcel status travel '
                        'with the driver. Buyer details, addresses and COD '
                        'amounts never appear here.',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner_outlined,
                        color: VColors.muted,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Container scanning, per-parcel scan status and '
                          'discrepancy reports are planned for a later version.',
                          style: TextStyle(
                            color: VColors.muted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const LaterPill(),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: vPageInsets,
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No manifest to show',
                message:
                    'Ask the Province Hub to create a trip for your vehicle. '
                    'The manifest arrives with the trip.',
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 10),
        ),
      ],
    );
  }
}

class _TripSelector extends StatelessWidget {
  const _TripSelector({
    required this.trips,
    required this.selectedCode,
    required this.onChanged,
  });

  final List<DriverTrip> trips;
  final String selectedCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return VCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, color: VColors.raisin, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCode,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: VColors.muted,
                ),
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                items: trips
                    .map(
                      (trip) => DropdownMenuItem(
                        value: trip.code,
                        child: Text(
                          '${trip.code} · ${trip.destination}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParcelList extends StatelessWidget {
  const _ParcelList({required this.trip, required this.query});

  final DriverTrip trip;
  final String query;

  @override
  Widget build(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final matches = <MapEntry<int, String>>[];
    for (var i = 0; i < trip.trackingNumbers.length; i++) {
      final tracking = trip.trackingNumbers[i];
      if (needle.isEmpty || tracking.toLowerCase().contains(needle)) {
        matches.add(MapEntry(i, tracking));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Parcels',
          trailing: Text(
            '${matches.length} of ${trip.parcelCount}',
            style: const TextStyle(
              color: VColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (matches.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No matching parcel',
            message: 'Check the tracking number and try again.',
          )
        else
          VCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < matches.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _ParcelRow(
                    index: matches[i].key,
                    total: trip.parcelCount,
                    tracking: matches[i].value,
                    stage: trip.stageFor(matches[i].key),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ParcelRow extends StatelessWidget {
  const _ParcelRow({
    required this.index,
    required this.total,
    required this.tracking,
    required this.stage,
  });

  final int index;
  final int total;
  final String tracking;
  final ParcelStage stage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: VColors.raisinSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: VColors.raisin,
              size: 17,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Parcel ${index + 1} of $total',
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ParcelStagePill(stage: stage),
        ],
      ),
    );
  }
}
