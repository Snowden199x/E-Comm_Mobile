import 'package:flutter/material.dart';
import 'package:vendo_driver/core/data/driver_store.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';

const double vPagePadding = 20;
const EdgeInsets vPageInsets = EdgeInsets.fromLTRB(
  vPagePadding,
  20,
  vPagePadding,
  28,
);

String formatPeso(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '₱$buffer.${parts.last}';
}

// ── Dark branded header used by every screen ─────────────────────────
class DriverHeader extends StatelessWidget {
  const DriverHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.bottom,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        vPagePadding,
        topInset + (onBack == null ? 18 : 8),
        vPagePadding,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VColors.pruneLight, VColors.prune],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onBack != null || trailing != null)
            Row(
              children: [
                if (onBack != null)
                  DriverCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Back',
                    onTap: onBack!,
                  ),
                const Spacer(),
                ?trailing,
              ],
            ),
          if (onBack != null || trailing != null) const SizedBox(height: 12),
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: const TextStyle(
                color: VColors.lin,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xB3FFFFFF),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          if (bottom != null) ...[const SizedBox(height: 18), bottom!],
        ],
      ),
    );
  }
}

class DriverCircleButton extends StatelessWidget {
  const DriverCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: const Color(0x1AFFFFFF),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Cards, titles, pills ─────────────────────────────────────────────
class VCard extends StatelessWidget {
  const VCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
    this.borderColor,
    this.radius = vRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? VColors.border),
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: VColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class TripStatusPill extends StatelessWidget {
  const TripStatusPill({super.key, required this.status});

  final TripStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      TripStatus.scheduled => const StatusPill(
        label: 'Scheduled',
        foreground: Color(0xFF8A6D1A),
        background: VColors.goldSoft,
        icon: Icons.schedule_rounded,
      ),
      TripStatus.inTransit => const StatusPill(
        label: 'In transit',
        foreground: VColors.brique,
        background: VColors.briqueSoft,
        icon: Icons.local_shipping_rounded,
      ),
      TripStatus.completed => const StatusPill(
        label: 'Completed',
        foreground: VColors.green,
        background: VColors.greenSoft,
        icon: Icons.check_circle_outline_rounded,
      ),
    };
  }
}

class ParcelStagePill extends StatelessWidget {
  const ParcelStagePill({super.key, required this.stage});

  final ParcelStage stage;

  @override
  Widget build(BuildContext context) {
    return switch (stage) {
      ParcelStage.awaitingOriginScan => const StatusPill(
        label: 'Awaiting scan',
        foreground: VColors.muted,
        background: Color(0xFFF1EEF1),
      ),
      ParcelStage.departed => const StatusPill(
        label: 'Departed',
        foreground: VColors.raisin,
        background: VColors.raisinSoft,
        icon: Icons.check_rounded,
      ),
      ParcelStage.inTransit => const StatusPill(
        label: 'In transit',
        foreground: VColors.brique,
        background: VColors.briqueSoft,
        icon: Icons.local_shipping_outlined,
      ),
      ParcelStage.received => const StatusPill(
        label: 'Received',
        foreground: VColors.green,
        background: VColors.greenSoft,
        icon: Icons.check_circle_outline_rounded,
      ),
    };
  }
}

class LaterPill extends StatelessWidget {
  const LaterPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VColors.raisinSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'LATER',
        style: TextStyle(
          color: VColors.raisin,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: VColors.raisinSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: VColors.raisin, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: VColors.muted, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),        ?trailing,
      ],
    );
  }
}

/// Origin → destination rail with dots and a connector.
class TripRoute extends StatelessWidget {
  const TripRoute({super.key, required this.trip, this.compact = false});

  final DriverTrip trip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: VColors.prune,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: compact ? 26 : 34,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: VColors.border,
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: VColors.brique, width: 2.5),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stop(
                label: 'Origin',
                name: trip.origin,
                area: trip.originArea,
                compact: compact,
              ),
              SizedBox(height: compact ? 16 : 20),
              _Stop(
                label: 'Destination',
                name: trip.destination,
                area: trip.destinationArea,
                compact: compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.label,
    required this.name,
    required this.area,
    required this.compact,
  });

  final String label;
  final String name;
  final String area;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: VColors.muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: TextStyle(
            color: VColors.ink,
            fontSize: compact ? 13.5 : 14.5,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        Text(
          area,
          style: const TextStyle(color: VColors.muted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return VCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: VColors.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: VColors.raisin, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VColors.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VColors.muted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// The pinned bottom action used by detail screens.
class DriverBottomAction extends StatelessWidget {
  const DriverBottomAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: VColors.shadow, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(width: double.infinity, height: 52, child: child),
        ),
      ),
    );
  }
}

/// Soft inline notice used for server-style blocks and explanations.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = NoticeTone.neutral,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final NoticeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color border, Color foreground) = switch (tone) {
      NoticeTone.error => (
        VColors.redSoft,
        const Color(0xFFF2C9C4),
        VColors.red,
      ),
      NoticeTone.warning => (
        VColors.goldSoft,
        const Color(0xFFE8D9A8),
        const Color(0xFF8A6D1A),
      ),
      NoticeTone.success => (
        VColors.greenSoft,
        const Color(0xFFC8E0CA),
        VColors.green,
      ),
      NoticeTone.neutral => (
        VColors.raisinSoft,
        const Color(0xFFE4D8E6),
        VColors.raisin,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF544956),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: action!),
          ],
        ],
      ),
    );
  }
}

enum NoticeTone { neutral, success, warning, error }

/// Full trip card used on the Trips board.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onTap});

  final DriverTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VCard(
      onTap: onTap,
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
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              TripStatusPill(status: trip.status),
            ],
          ),
          const SizedBox(height: 14),
          TripRoute(trip: trip, compact: true),
          const SizedBox(height: 13),
          const Divider(height: 1),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: VColors.raisin,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  dateTimeLabel(trip.scheduledDeparture),
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.inventory_2_outlined,
                size: 15,
                color: VColors.raisin,
              ),
              const SizedBox(width: 5),
              Text(
                '${trip.parcelCount} parcels',
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: VColors.raisin,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact row used for upcoming trips on Home.
class UpcomingTripTile extends StatelessWidget {
  const UpcomingTripTile({super.key, required this.trip, required this.onTap});

  final DriverTrip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: VColors.raisinSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.route_outlined,
              color: VColors.raisin,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.origin}  →  ${trip.destination}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${dateTimeLabel(trip.scheduledDeparture)} · '
                  '${trip.parcelCount} parcels',
                  style: const TextStyle(
                    color: VColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: VColors.muted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
