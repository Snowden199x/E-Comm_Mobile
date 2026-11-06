import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

/// Completed parcels for one day, opened from the history icon on the Parcels
/// tab. The day starts at today and can be stepped back one day at a time.
class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  // Vendo "Warm Courier Kinetic" palette (same as the other rider screens)
  static const _prune = Color(0xFF3C2143);
  static const _pruneDeep = Color(0xFF25102A);
  static const _pruneMid = Color(0xFF33173A);
  static const _pruneLight = Color(0xFF3F1E47);
  static const _brique = Color(0xFFC85A32);
  static const _background = Color(0xFFFAF7F2);
  static const _ink = Color(0xFF1C1C19);
  static const _muted = Color(0xFF7D747D);
  static const _border = Color(0xFFEDE6DD);
  static const _done = Color(0xFF2F7A5B);
  static const _doneSoft = Color(0xFFE6F2EC);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  DateTime _day = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateParam =>
      '${_day.year.toString().padLeft(4, '0')}-'
      '${_day.month.toString().padLeft(2, '0')}-'
      '${_day.day.toString().padLeft(2, '0')}';

  bool get _isToday => _isSameDay(_day, DateTime.now());

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _labelFor(DateTime day) {
    if (_isSameDay(day, DateTime.now())) return 'Today';
    return '${_weekdays[day.weekday - 1]}, ${day.day} '
        '${_months[day.month - 1]} ${day.year}';
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await RiderApi.instance.deliveryHistory(date: _dateParam);
      if (!mounted) return;
      setState(() => _data = data);
    } on RiderApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'Could not load your delivery history. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _step(int days) async {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (next.isAfter(DateTime.now())) return;
    HapticFeedback.selectionClick();
    setState(() {
      _day = next;
      _data = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = (_data?['deliveries'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(deliveries.length),
            const SizedBox(height: 16),
            _buildDayBar(),
            const SizedBox(height: 14),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: _brique,
                child: _buildBody(deliveries),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dark header: back + title + completed count ──────────────────────────
  Widget _buildHeader(int count) {
    final topInset = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pruneDeep, _pruneMid, _pruneLight],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 20),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: Material(
                  color: const Color(0x1AFFFFFF),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x26FFFFFF)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery history',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Parcels you completed',
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x40FFFFFF)),
                  ),
                  child: Text(
                    '$count done',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Day stepper: yesterday ← selected day → disabled at today ────────────
  Widget _buildDayBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3C2143),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _dayButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous day',
            onTap: () => _step(-1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _labelFor(_day),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _isToday ? 'Completed so far today' : 'Completed that day',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _dayButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next day',
            onTap: _isToday ? null : () => _step(1),
          ),
        ],
      ),
    );
  }

  Widget _dayButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null
            ? const Color(0xFFF4F0EB)
            : const Color(0xFFF2EAF5),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 22,
              color: onTap == null ? const Color(0xFFC9C0C9) : _prune,
            ),
          ),
        ),
      ),
    );
  }

  // ── Body: loading / error / empty / list ─────────────────────────────────
  Widget _buildBody(List<Map<String, dynamic>> deliveries) {
    if (_loading && _data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: _brique)),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [_messageCard(_error!, retry: true)],
      );
    }
    if (deliveries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
        children: [
          _messageCard(
            _isToday
                ? 'No parcels completed yet today. Finished deliveries show up here.'
                : 'No parcels were completed on this day.',
          ),
        ],
      );
    }

    final summary = _data?['summary'] as Map?;
    final cash = summary?['cash_collected']?.toString() ?? '0.00';
    final hasCash = double.tryParse(cash) != null && double.parse(cash) > 0;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      itemCount: deliveries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  '${deliveries.length} completed',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hasCash) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _doneSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '₱$cash collected',
                      style: const TextStyle(
                        color: _done,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return _deliveryCard(deliveries[index - 1]);
      },
    );
  }

  Widget _messageCard(String message, {bool retry = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            retry ? Icons.cloud_off_rounded : Icons.inventory_2_outlined,
            color: _muted,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          if (retry) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: TextButton.styleFrom(foregroundColor: _brique),
            ),
          ],
        ],
      ),
    );
  }

  // ── One completed parcel ─────────────────────────────────────────────────
  Widget _deliveryCard(Map<String, dynamic> item) {
    final tracking = item['tracking_number']?.toString() ?? 'Parcel';
    final buyer = item['buyer_name']?.toString() ?? '';
    final address = item['address']?.toString() ?? '';
    final time = item['delivered_at_label']?.toString() ?? '';
    final recipient = item['recipient_name']?.toString() ?? '';
    final cash = item['cash_collected']?.toString();
    final hasCash = cash != null && (double.tryParse(cash) ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D3C2143),
            blurRadius: 14,
            spreadRadius: -2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: _doneSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: _done, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracking,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (buyer.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        buyer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  time,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.place_outlined, size: 13, color: _muted),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasCash || recipient.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (hasCash)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F1DC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₱$cash collected',
                      style: const TextStyle(
                        color: Color(0xFF8A6A1F),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (hasCash && recipient.isNotEmpty) const SizedBox(width: 8),
                if (recipient.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Received by $recipient',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
