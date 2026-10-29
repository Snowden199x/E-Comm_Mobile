import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/orders/screens/orders_screen.dart';

/// COD checkout for the selected cart lines.
///
/// Loads the server's checkout preview (revision, per-shop totals, vouchers), asks for the
/// delivery province and city, fetches the live shipping quote, then places the order. The server
/// revalidates prices, stock, the quote and the cart revision before the order is created.
class CheckoutScreen extends StatefulWidget {
  final List<int> itemIds;

  const CheckoutScreen({super.key, required this.itemIds});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _purple = Color(0xFF3B1F52);
  static const _purpleMid = Color(0xFF7B2FBE);
  static const _bg = Color(0xFFF4F1F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF888888);
  static const _border = Color(0xFFECE6EA);
  static const _green = Color(0xFF1A9B5A);

  final _addressCtrl = TextEditingController();

  ApiCheckoutPreview? _preview;
  List<ApiProvince> _provinces = const [];
  ApiProvince? _province;
  ApiCity? _city;
  ApiShippingQuote? _quote;

  bool _loading = true;
  bool _quoting = false;
  bool _placing = false;
  String? _error;
  int _provinceIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        BuyerApi.instance.checkoutPreview(widget.itemIds),
        BuyerApi.instance.locations(),
      ]);
      if (!mounted) return;

      final preview = results[0] as ApiCheckoutPreview;
      final provinces = results[1] as List<ApiProvince>;
      final address = preview.defaultAddress;

      _addressCtrl.text = address['shipping_address']?.toString() ?? '';

      ApiProvince? province;
      for (final entry in provinces) {
        if (entry.code == address['province_code']) province = entry;
      }
      ApiCity? city;
      if (province != null) {
        for (final entry in province.cities) {
          if (entry.code == address['city_code']) city = entry;
        }
      }

      setState(() {
        _preview = preview;
        _provinces = provinces;
        _province = province;
        _provinceIndex = province == null ? 0 : provinces.indexOf(province);
        _city = city;
        _loading = false;
      });

      if (province != null && city != null) _refreshQuote();
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach Vendo. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  Future<void> _refreshQuote() async {
    final province = _province;
    final city = _city;
    if (province == null || city == null) return;
    setState(() => _quoting = true);
    try {
      final quote = await BuyerApi.instance.shippingQuote(
        widget.itemIds,
        province.code,
        city.code,
      );
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoting = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _quoting = false;
      });
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _quoting = false;
      });
      _toast('Could not get a shipping quote. Check your connection.');
    }
  }

  Future<void> _placeOrder() async {
    final preview = _preview;
    final province = _province;
    final city = _city;
    if (preview == null || province == null || city == null) {
      _toast('Choose the delivery province and city first.');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      _toast('Enter the delivery address.');
      return;
    }
    if (_quote == null) {
      _toast('Wait for the shipping quote before placing the order.');
      return;
    }

    setState(() => _placing = true);
    try {
      final orders = await BuyerApi.instance.placeOrder(
        itemIds: widget.itemIds,
        shippingAddress: _addressCtrl.text.trim(),
        provinceCode: province.code,
        cityCode: city.code,
        checkoutRevision: preview.revision,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OrdersScreen()),
        (route) => route.isFirst,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            orders.isEmpty
                ? 'Order placed.'
                : 'Order placed: ${orders.map((order) => order.number).join(', ')}. Pay ${orders.first.codAmount} in cash on delivery.',
          ),
        ),
      );
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
      if (e.statusCode == 422) {
        // Prices, stock or the cart changed; reload the preview so the buyer reviews it again.
        _load();
      }
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double get _itemsTotal =>
      _preview?.shops.fold<double>(0, (sum, shop) => sum + shop.itemsValue) ?? 0;

  double get _shippingTotal => _quote?.total ?? 0;

  String get _grandTotalLabel {
    final total = _itemsTotal + _shippingTotal;
    return '₱${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Checkout',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _content(),
      bottomNavigationBar: (_loading || _error != null) ? null : _bottomBar(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _muted),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purpleMid),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final preview = _preview!;
    return ListView(
      children: [
        _card(
          title: 'Delivery address',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'House / street / barangay',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                key: ValueKey('province-$_provinceIndex'),
                initialValue: _province == null
                    ? _provinceIndex
                    : _provinces.indexOf(_province!),
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(
                  _provinces.length,
                  (index) => DropdownMenuItem(
                    value: index,
                    child: Text(
                      _provinces[index].name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                onChanged: (index) {
                  if (index == null) return;
                  setState(() {
                    _provinceIndex = index;
                    _province = _provinces[index];
                    _city = null;
                    _quote = null;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('city-${_province?.code}-${_city?.code}'),
                initialValue: _city?.code,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'City / municipality',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: (_province?.cities ?? const <ApiCity>[])
                    .map(
                      (city) => DropdownMenuItem(
                        value: city.code,
                        child: Text(city.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (code) {
                  if (code == null || _province == null) return;
                  setState(() {
                    for (final city in _province!.cities) {
                      if (city.code == code) _city = city;
                    }
                    _quote = null;
                  });
                  _refreshQuote();
                },
              ),
            ],
          ),
        ),
        _card(
          title: 'Order summary',
          child: Column(
            children: [
              ...preview.shops.map(
                (shop) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.shop,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _voucherText(shop),
                              style: const TextStyle(fontSize: 11.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(shop.items, style: const TextStyle(fontSize: 13)),
                          Text(
                            _shippingLine(shop.sellerId),
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              _amountRow('Items', '₱${_itemsTotal.toStringAsFixed(_itemsTotal % 1 == 0 ? 0 : 2)}'),
              _amountRow(
                'Shipping',
                _quoting
                    ? 'Calculating…'
                    : (_quote?.totalLabel ?? 'Choose a city'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text(
                    'Cash on delivery',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    _grandTotalLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: _green),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pay the rider in cash when your order arrives.',
                      style: TextStyle(fontSize: 11.5, color: _green),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _voucherText(ApiCheckoutShop shop) {
    final usable = shop.vouchers.where((voucher) => voucher.eligible).toList();
    if (usable.isEmpty) return 'No voucher applied';
    return '${usable.length} voucher(s) available — tap to use on the web checkout';
  }

  String _shippingLine(int sellerId) {
    final label = _quote?.perSellerLabel[sellerId];
    if (_quoting) return 'shipping…';
    if (label == null) return 'shipping not quoted';
    return 'shipping $label';
  }

  Widget _amountRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: _muted)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 12.5, color: _ink)),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Total', style: TextStyle(fontSize: 11, color: _muted)),
                Text(
                  _grandTotalLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _purple,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _purpleMid),
                  onPressed: (_placing || _quoting || _quote == null) ? null : _placeOrder,
                  child: Text(
                    _placing
                        ? 'Placing order…'
                        : _quote == null
                            ? 'Choose a delivery city'
                            : 'Place order (COD)',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
