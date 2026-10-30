import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

class EarningsScreen extends StatefulWidget {
  final bool transportDriver;

  const EarningsScreen({super.key, this.transportDriver = false});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _earnings = [];
  Map<String, dynamic> _cashSummary = {};
  List<Map<String, dynamic>> _collections = [];
  String? _error;
  String? _cashError;
  bool _loading = true;

  static const _purple = Color(0xFF412143);
  static const _background = Color(0xFFFAF7F5);
  static const _muted = Color(0xFF756B78);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _cashError = null;
    });
    // Cash on hand is a Rider-only view; Transport Drivers do not collect COD.
    final cashCall = widget.transportDriver
        ? null
        : RiderApi.instance.riderCash();
    try {
      final data = await RiderApi.instance.earnings(
        transportDriver: widget.transportDriver,
      );
      final summary = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      final rows = data['earnings'] is List
          ? (data['earnings'] as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _summary = summary;
          _earnings = rows;
        });
      }
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load earnings. Pull to refresh.');
      }
    }

    if (cashCall != null) {
      try {
        final cash = await cashCall;
        final summary = cash['summary'] is Map
            ? Map<String, dynamic>.from(cash['summary'] as Map)
            : <String, dynamic>{};
        final rows = cash['collections'] is List
            ? (cash['collections'] as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList()
            : <Map<String, dynamic>>[];
        if (mounted) {
          setState(() {
            _cashSummary = summary;
            _collections = rows;
          });
        }
      } on RiderApiException catch (error) {
        if (mounted) setState(() => _cashError = error.message);
      } catch (_) {
        if (mounted) {
          setState(
            () => _cashError =
                'Cash on hand is unavailable right now. Pull to refresh.',
          );
        }
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  String _money(dynamic value) =>
      '₱${(double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('My Earnings'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null)
                      _card(Column(children: [
                        const Icon(Icons.cloud_off_outlined, size: 32, color: _purple),
                        const SizedBox(height: 10),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ]))
                    else
                      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Accrued earnings', style: TextStyle(color: _muted)),
                        const SizedBox(height: 6),
                        Text(_money(_summary['accrued_total']), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _purple)),
                        const SizedBox(height: 6),
                        Text('${_summary['hub_credits'] ?? 0} completed credits · accrued from completed deliveries', style: const TextStyle(color: _muted)),
                        const SizedBox(height: 10),
                        const Text('Accrued amounts are not a cash or bank payout. Vendo does not process payouts yet.', style: TextStyle(color: _muted, height: 1.35)),
                      ])),
                    ..._cashWidgets(),
                    if (_error == null) ...[
                      const SizedBox(height: 18),
                      const Text('Recent hub earnings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _purple)),
                      const SizedBox(height: 8),
                      if (_earnings.isEmpty)
                        _card(const Text('No completed hub credits yet.', textAlign: TextAlign.center, style: TextStyle(color: _muted)))
                      else
                        ..._earnings.map((row) => _card(Row(children: [
                          const Icon(Icons.hub_outlined, color: _purple),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(row['hub']?.toString() ?? 'Route hub', style: const TextStyle(fontWeight: FontWeight.w700, color: _purple)),
                            Text('${row['order_number'] ?? 'Order'} · Hub ${row['route_position'] ?? ''}', style: const TextStyle(fontSize: 12, color: _muted)),
                          ])),
                          Text(_money(row['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
                        ]))),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  /// "Cash on hand" is COD cash the Rider physically holds, not accrued pay.
  /// It comes from GET /api/v1/rider/cash and is hidden for Transport Drivers.
  List<Widget> _cashWidgets() {
    if (widget.transportDriver) return const [];
    if (_cashError != null) {
      return [
        const SizedBox(height: 18),
        const Text('Cash on hand', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _purple)),
        const SizedBox(height: 8),
        _card(Column(children: [
          const Icon(Icons.payments_outlined, size: 30, color: _purple),
          const SizedBox(height: 8),
          Text(_cashError!, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ])),
      ];
    }

    final parcels =
        int.tryParse(_cashSummary['parcels_on_hand']?.toString() ?? '') ?? 0;
    final subtitle = parcels == 0
        ? 'No COD cash waiting to be handed over.'
        : 'From $parcels parcel${parcels == 1 ? '' : 's'} waiting for your Station Hub to receive it.';

    return [
      const SizedBox(height: 18),
      const Text('Cash on hand', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _purple)),
      const SizedBox(height: 8),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8EAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.payments_outlined, color: Color(0xFFBF5E40)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COD cash you are holding', style: TextStyle(fontSize: 12.5, color: _muted)),
            const SizedBox(height: 2),
            Text(_money(_cashSummary['cash_on_hand']), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _purple)),
          ])),
        ]),
        const SizedBox(height: 10),
        Text(subtitle, style: const TextStyle(color: _muted, height: 1.35)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFECE6EA)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _muted),
            SizedBox(width: 8),
            Expanded(child: Text(
              'This is not your pay. It is COD cash you collected from buyers, and it leaves this total when your Station Hub records that it received the cash.',
              style: TextStyle(fontSize: 12, color: _muted, height: 1.4),
            )),
          ]),
        ),
      ])),
      if (_collections.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Recent COD collections', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _purple)),
        const SizedBox(height: 8),
        ..._collections.map((row) {
          final status = _cashStatus(row);
          return _card(Row(children: [
            const Icon(Icons.receipt_long_outlined, color: _purple),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row['order_number']?.toString() ?? 'COD collection', style: const TextStyle(fontWeight: FontWeight.w700, color: _purple)),
              const SizedBox(height: 4),
              Row(children: [
                Text(_date(row['collected_at']), style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: status.color)),
                ),
              ]),
            ])),
            const SizedBox(width: 8),
            Text(_money(row['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
          ]));
        }),
      ],
    ];
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFECE6EA)),
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
