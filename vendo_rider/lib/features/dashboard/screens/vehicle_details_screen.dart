import 'package:flutter/material.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/widgets/profile_ui.dart';

/// The vehicle and documents the Station Hub approved for this Rider.
class VehicleDetailsScreen extends StatefulWidget {
  const VehicleDetailsScreen({super.key});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  Map<String, dynamic>? _rider;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rider = await RiderApi.instance.riderProfile();
      if (!mounted) return;
      setState(() {
        _rider = rider;
        _loading = false;
      });
    } on RiderApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Cannot reach Vendo Xpress right now. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePageScaffold(
      title: 'Vehicle Details',
      subtitle: 'Your approved vehicle and documents on file',
      icon: Icons.two_wheeler_outlined,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const ProfileStateCard(
        icon: Icons.two_wheeler_outlined,
        title: 'Loading your vehicle…',
        message: 'This only takes a moment.',
        busy: true,
      );
    }

    final rider = _rider;
    if (_error != null || rider == null) {
      return ProfileStateCard(
        icon: Icons.cloud_off_rounded,
        title: 'Your vehicle details could not load',
        message: _error ?? 'Try again in a moment.',
        onRetry: _load,
      );
    }

    final vehicle = _map(rider['vehicle']);
    final documents = _map(rider['documents']);
    final hub = _text(_map(rider['station_hub'])['name']);
    final center = _text(_map(rider['logistics_center'])['name']);
    final areas = (rider['service_areas'] is List)
        ? (rider['service_areas'] as List)
              .map((area) => _text(area))
              .whereType<String>()
              .toList()
        : const <String>[];

    final licenseOnFile = documents['drivers_license'] == true;
    final orCrOnFile = documents['or_cr'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VehicleSummary(
          type: _text(vehicle['type']),
          plate: _text(vehicle['plate_number']),
          hub: hub,
        ),
        const SizedBox(height: 24),
        ProfileSection(
          title: 'Registered vehicle',
          children: [
            ProfileInfoRow(
              icon: Icons.two_wheeler_outlined,
              label: 'Vehicle type',
              value: _text(vehicle['type']),
            ),
            ProfileInfoRow(
              icon: Icons.pin_outlined,
              label: 'Plate number',
              value: _text(vehicle['plate_number']),
            ),
            ProfileInfoRow(
              icon: Icons.warehouse_outlined,
              label: 'Assigned station hub',
              value: hub,
            ),
            ProfileInfoRow(
              icon: Icons.business_outlined,
              label: 'Logistics center',
              value: center,
            ),
          ],
        ),
        const SizedBox(height: 22),
        ProfileSection(
          title: 'Documents on file',
          caption:
              'The copies your Station Hub reviewed when approving your account',
          children: [
            ProfileInfoRow(
              icon: Icons.credit_card_outlined,
              label: "Driver's license",
              value: licenseOnFile ? 'On file' : null,
              hint: 'Not on file',
              trailing: _DocumentBadge(onFile: licenseOnFile),
            ),
            ProfileInfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'OR / CR',
              value: orCrOnFile ? 'On file' : null,
              hint: 'Not on file',
              trailing: _DocumentBadge(onFile: orCrOnFile),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ProfileSection(
          title: 'Coverage',
          caption: 'Where your hub can assign parcels for this vehicle',
          children: [
            if (areas.isEmpty)
              const ProfileInfoRow(
                icon: Icons.place_outlined,
                label: 'Service areas',
                hint: 'Assigned by your Station Hub',
              )
            else
              ProfileTagList(labels: areas),
          ],
        ),
        const SizedBox(height: 20),
        const ProfileNote(
          text:
              'Vehicle, plate, and document changes are verified by your Station Hub. Visit your hub with the new OR / CR or licence so they can update your record.',
          icon: Icons.verified_outlined,
        ),
      ],
    );
  }
}

// ── Header summary: vehicle type on a plate-style card ──────────────────────
class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.type, required this.plate, required this.hub});

  final String? type;
  final String? plate;
  final String? hub;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ProfileColors.pruneLight, ProfileColors.prune],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: ProfileColors.lin,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == null ? 'Vehicle not on file' : '$type Rider',
                  style: const TextStyle(
                    color: ProfileColors.ink,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.pin_outlined,
                      size: 14,
                      color: ProfileColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        plate ?? 'No plate number on file',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ProfileColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hub != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.warehouse_outlined,
                        size: 14,
                        color: ProfileColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          hub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ProfileColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentBadge extends StatelessWidget {
  const _DocumentBadge({required this.onFile});

  final bool onFile;

  @override
  Widget build(BuildContext context) {
    final color = onFile ? ProfileColors.success : ProfileColors.brique;
    return Icon(
      onFile ? Icons.verified_rounded : Icons.error_outline_rounded,
      color: color,
      size: 20,
    );
  }
}

// ── Small JSON helpers (the API may omit fields) ────────────────────────────
Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}
