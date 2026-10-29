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
  String? _error;
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
    setState(() { _loading = true; _error = null; });
    try {
      final data = await RiderApi.instance.earnings(transportDriver: widget.transportDriver);
      final summary = data['summary'] is Map
          ? Map<String, dynamic>.from(data['summary'] as Map)
          : <String, dynamic>{};
      final rows = data['earnings'] is List
          ? (data['earnings'] as List).map((row) => Map<String, dynamic>.from(row as Map)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() { _summary = summary; _earnings = rows; });
    } on RiderApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load earnings. Pull to refresh.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(dynamic value) => '₱${(double.tryParse(value?.toString() ?? '') ?? 0).toStringAsFixed(2)}';

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
                    else ...[
                      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Accrued earnings', style: TextStyle(color: _muted)),
                        const SizedBox(height: 6),
                        Text(_money(_summary['accrued_total']), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _purple)),
                        const SizedBox(height: 6),
                        Text('${_summary['hub_credits'] ?? 0} completed credits · accrued from completed deliveries', style: const TextStyle(color: _muted)),
                        const SizedBox(height: 10),
                        const Text('Accrued amounts are not a cash or bank payout. Vendo does not process payouts yet.', style: TextStyle(color: _muted, height: 1.35)),
                      ])),
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
