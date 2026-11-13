import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

/// Full list of the COD cash this Rider collected, with date filters.
/// Amounts come from GET /api/v1/rider/cash (same source as "Cash on hand").
class CodCollectionsScreen extends StatefulWidget {
  const CodCollectionsScreen({super.key});

  @override
  State<CodCollectionsScreen> createState() => _CodCollectionsScreenState();
}

enum _DateFilter { today, week, month, all, custom }

class _CodCollectionsScreenState extends State<CodCollectionsScreen> {
  static const _purple = Color(0xFF412143);
  static const _background = Color(0xFFFAF7F5);
  static const _muted = Color(0xFF756B78);
  static const _border = Color(0xFFECE6EA);

  List<Map<String, dynamic>> _collections = [];
  bool _loading = true;
  String? _error;
  _DateFilter _filter = _DateFilter.today;
  DateTimeRange? _customRange;

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
      final data = await RiderApi.instance.riderCash();
      final rows = data['collections'] is List
          ? (data['collections'] as List)
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _collections = rows;
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
            'Could not load COD collections. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  String _money(dynamic value) =>
      '₱${(double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _shortDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}';
  }

  DateTime? _collectedAt(Map<String, dynamic> row) =>
      DateTime.tryParse(row['collected_at']?.toString() ?? '')?.toLocal();

  _CashStatus _cashStatus(Map<String, dynamic> row) {
    switch (row['money_status']?.toString()) {
      case 'collected_by_rider':
        return const _CashStatus(
          'Still with you',
          Color(0xFFBF5E40),
          Color(0xFFF8EAE5),
        );
      case 'discrepancy':
        return const _CashStatus(
          'Discrepancy',
          Color(0xFFC62828),
          Color(0xFFFFEBEE),
        );
      case 'remitted_to_station':
      case 'remitted_to_province':
      case 'received_by_company':
      case 'remitted_to_vendo':
      case 'credited_to_seller':
        return const _CashStatus(
          'Received by station',
          Color(0xFF2E7D32),
          Color(0xFFE8F5E9),
        );
      default:
        return _CashStatus(
          row['money_status_label']?.toString() ?? 'Recorded',
          _muted,
          const Color(0xFFF4F0F3),
        );
    }
  }

  /// Collections inside the selected date filter, newest first.
  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    DateTime? to;

    switch (_filter) {
      case _DateFilter.today:
        from = today;
        to = today;
      case _DateFilter.week:
        from = today.subtract(const Duration(days: 6));
        to = today;
      case _DateFilter.month:
        from = today.subtract(const Duration(days: 29));
        to = today;
      case _DateFilter.all:
        break;
      case _DateFilter.custom:
        final range = _customRange;
        if (range != null) {
          from = DateTime(range.start.year, range.start.month, range.start.day);
          to = DateTime(range.end.year, range.end.month, range.end.day);
        }
    }

    final rows =
        _collections.where((row) {
          final date = _collectedAt(row);
          if (date == null) return false;
          final day = DateTime(date.year, date.month, date.day);
          if (from != null && day.isBefore(from)) return false;
          if (to != null && day.isAfter(to)) return false;
          return true;
        }).toList()..sort((a, b) {
          final aDate = _collectedAt(a) ?? DateTime(0);
          final bDate = _collectedAt(b) ?? DateTime(0);
          return bDate.compareTo(aDate);
        });
    return rows;
  }

  double get _filteredTotal => _filtered.fold(
    0,
    (sum, row) => sum + (double.tryParse(row['amount']?.toString() ?? '') ?? 0),
  );

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _customRange,
      helpText: 'Filter COD collections',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _filter = _DateFilter.custom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('COD collections'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    if (_error != null)
                      _card(
                        Column(
                          children: [
                            const Icon(
                              Icons.cloud_off_outlined,
                              size: 32,
                              color: _purple,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _muted),
                            ),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _card(
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8EAE5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xFFBF5E40),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Collected in this period',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: _muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _money(_filteredTotal),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: _purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${filtered.length} parcel${filtered.length == 1 ? '' : 's'}',
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Filter by date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _filters(),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        _card(
                          Column(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 30,
                                color: _purple,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No COD collections for this period.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _muted),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filtered.map(_collectionCard),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _filters() {
    final customLabel = _customRange == null
        ? 'Custom'
        : '${_shortDate(_customRange!.start)} – ${_shortDate(_customRange!.end)}';

    Widget chip(
      String label,
      bool active,
      VoidCallback onTap, {
      IconData? icon,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? _purple : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: active ? _purple : _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: active ? Colors.white : _purple),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            'Today',
            _filter == _DateFilter.today,
            () => setState(() => _filter = _DateFilter.today),
          ),
          const SizedBox(width: 8),
          chip(
            'Last 7 days',
            _filter == _DateFilter.week,
            () => setState(() => _filter = _DateFilter.week),
          ),
          const SizedBox(width: 8),
          chip(
            'Last 30 days',
            _filter == _DateFilter.month,
            () => setState(() => _filter = _DateFilter.month),
          ),
          const SizedBox(width: 8),
          chip(
            'All time',
            _filter == _DateFilter.all,
            () => setState(() => _filter = _DateFilter.all),
          ),
          const SizedBox(width: 8),
          chip(
            customLabel,
            _filter == _DateFilter.custom,
            _pickCustomRange,
            icon: Icons.calendar_month_outlined,
          ),
        ],
      ),
    );
  }

  Widget _collectionCard(Map<String, dynamic> row) {
    final status = _cashStatus(row);
    return _card(
      Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: _purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['order_number']?.toString() ?? 'COD collection',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _purple,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _date(row['collected_at']),
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: status.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(row['amount']),
            style: const TextStyle(fontWeight: FontWeight.w800, color: _purple),
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _CashStatus {
  const _CashStatus(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;
}
