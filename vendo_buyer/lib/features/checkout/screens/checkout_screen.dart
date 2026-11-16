import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/core/location/device_location.dart';
import 'package:vendo_buyer/features/checkout/screens/address_pin_screen.dart';
import 'package:vendo_buyer/features/orders/screens/orders_screen.dart';
import 'package:vendo_buyer/features/profile/screens/delivery_address_screen.dart';

/// COD checkout for the selected cart lines, laid out like the web checkout:
/// delivery address (saved + registered), items grouped per shop with the
/// Logistics provider, seller note and shop vouchers, the payment card and the
/// order summary. Every number comes from the same API the web page uses.
class CheckoutScreen extends StatefulWidget {
  final List<int> itemIds;

  const CheckoutScreen({super.key, required this.itemIds});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

/// One selectable delivery address: a saved row from the address book, the
/// address saved with the account, or one added for this checkout only.
class _AddressChoice {
  final String id;
  final int? savedId;
  final String label;
  final bool registered;
  final bool isDefault;
  final bool usable;
  final String line;
  final String province;
  final String city;
  final String provinceCode;
  final String cityCode;
  final double? latitude;
  final double? longitude;

  const _AddressChoice({
    required this.id,
    required this.label,
    required this.line,
    required this.province,
    required this.city,
    required this.provinceCode,
    required this.cityCode,
    required this.usable,
    this.savedId,
    this.registered = false,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  String get fullLine =>
      [line, city, province].where((part) => part.isNotEmpty).join(', ');
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _plum = Color(0xFF402143);
  static const _plumMid = Color(0xFF52245B);
  static const _accent = Color(0xFF805487);
  static const _bg = Color(0xFFF7F5F9);
  static const _band = Color(0xFFF6F2F7);
  static const _ink = Color(0xFF2B1730);
  static const _body = Color(0xFF5B4A60);
  static const _muted = Color(0xFF7A6A7E);
  static const _lite = Color(0xFF8A7A8E);
  static const _border = Color(0xFFEEE6EF);
  static const _fieldBorder = Color(0xFFE5DCE7);
  static const _gold = Color(0xFFE8C874);
  static const _green = Color(0xFF2E6B46);
  static const _red = Color(0xFFA32B43);
  static const _selectedBg = Color(0xFFFAF5FA);

  ApiCheckoutPreview? _preview;
  List<ApiProvince> _provinces = const [];
  List<_AddressChoice> _addresses = [];
  String? _selectedId;
  ApiShippingQuote? _quote;

  bool _loading = true;
  bool _quoting = false;
  bool _placing = false;
  String? _error;
  String? _quoteError;

  final Map<int, TextEditingController> _noteCtrls = {};
  final Map<int, TextEditingController> _codeCtrls = {};
  final Map<int, TextEditingController> _extraCtrls = {};
  final Map<int, TextEditingController> _voucherChoice = {};
  final Map<int, int> _logistics = {};
  final Map<int, double> _voucherDiscounts = {};
  final Map<int, String> _appliedVoucherKey = {};
  final Map<int, String> _voucherErrors = {};
  final Set<int> _applyingVoucher = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      ..._noteCtrls.values,
      ..._codeCtrls.values,
      ..._extraCtrls.values,
      ..._voucherChoice.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _noteCtrl(int sellerId) =>
      _noteCtrls.putIfAbsent(sellerId, TextEditingController.new);
  TextEditingController _codeCtrl(int sellerId) =>
      _codeCtrls.putIfAbsent(sellerId, TextEditingController.new);
  TextEditingController _extraCtrl(int sellerId) =>
      _extraCtrls.putIfAbsent(sellerId, TextEditingController.new);
  TextEditingController _choiceCtrl(int sellerId) =>
      _voucherChoice.putIfAbsent(sellerId, TextEditingController.new);

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

      final choices = <_AddressChoice>[
        ...preview.savedAddresses.map(
          (saved) => _AddressChoice(
            id: 'saved-${saved.id}',
            savedId: saved.id,
            label: saved.label,
            isDefault: saved.isDefault,
            usable: saved.usable,
            line: saved.line,
            province: saved.province,
            city: saved.city,
            provinceCode: saved.provinceCode,
            cityCode: saved.cityCode,
            latitude: saved.latitude,
            longitude: saved.longitude,
          ),
        ),
      ];

      final registeredLine = address['shipping_address']?.toString() ?? '';
      final registeredProvince = address['province']?.toString() ?? '';
      final registeredCity = address['city']?.toString() ?? '';
      final registeredProvinceCode = address['province_code']?.toString() ?? '';
      final registeredCityCode = address['city_code']?.toString() ?? '';
      choices.add(
        _AddressChoice(
          id: 'registered',
          label: 'Registered address',
          registered: true,
          isDefault: !preview.savedAddresses.any((saved) => saved.isDefault),
          usable:
              registeredLine.isNotEmpty &&
              registeredProvinceCode.isNotEmpty &&
              registeredCityCode.isNotEmpty,
          line: registeredLine,
          province: registeredProvince,
          city: registeredCity,
          provinceCode: registeredProvinceCode,
          cityCode: registeredCityCode,
          latitude: double.tryParse('${address['latitude']}'),
          longitude: double.tryParse('${address['longitude']}'),
        ),
      );

      String? selected;
      for (final choice in choices) {
        if (choice.usable && choice.isDefault) {
          selected = choice.id;
          break;
        }
      }
      selected ??= choices.where((choice) => choice.usable).firstOrNull?.id;

      setState(() {
        _preview = preview;
        _provinces = provinces;
        _addresses = choices;
        _selectedId = selected;
        _loading = false;
      });

      if (selected == null) {
        // Same as the web: open the address form when nothing can be used yet.
        WidgetsBinding.instance.addPostFrameCallback((_) => _openAddAddress());
      } else {
        _refreshQuote();
      }
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

  _AddressChoice? get _selected {
    for (final choice in _addresses) {
      if (choice.id == _selectedId) return choice;
    }
    return null;
  }

  Future<void> _refreshQuote() async {
    final address = _selected;
    if (address == null || !address.usable) {
      setState(() {
        _quote = null;
        _quoteError = null;
        _logistics.clear();
      });
      return;
    }
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final quote = await BuyerApi.instance.shippingQuote(
        widget.itemIds,
        address.provinceCode,
        address.cityCode,
      );
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _quoting = false;
        _logistics.clear();
        for (final entry in quote.selected.entries) {
          _logistics[entry.key] = entry.value.companyId;
        }
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _quoting = false;
        _quoteError = e.message;
        _logistics.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _quote = null;
        _quoting = false;
        _quoteError = 'Could not get a shipping quote. Check your connection.';
        _logistics.clear();
      });
    }
  }

  String _voucherKey(int sellerId) =>
      [_codeCtrl(sellerId).text, _extraCtrl(sellerId).text]
          .map((code) => code.trim().toUpperCase())
          .where((code) => code.isNotEmpty)
          .join('|');

  Future<void> _applyVoucher(int sellerId) async {
    final codes = [_codeCtrl(sellerId).text, _extraCtrl(sellerId).text]
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList();
    final key = codes.join('|');
    if (codes.isEmpty) {
      setState(() {
        _voucherDiscounts[sellerId] = 0;
        _appliedVoucherKey[sellerId] = '';
        _voucherErrors.remove(sellerId);
      });
      return;
    }
    setState(() => _applyingVoucher.add(sellerId));
    try {
      final quote = await BuyerApi.instance.voucherQuote(
        widget.itemIds,
        sellerId,
        codes,
      );
      if (!mounted) return;
      if (_voucherKey(sellerId) != key) return;
      setState(() {
        _voucherDiscounts[sellerId] = quote.discount;
        _appliedVoucherKey[sellerId] = key;
        _voucherErrors.remove(sellerId);
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() => _voucherErrors[sellerId] = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _voucherErrors[sellerId] =
            'Could not apply this voucher. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _applyingVoucher.remove(sellerId));
    }
  }

  Future<void> _placeOrder() async {
    final preview = _preview;
    final address = _selected;
    if (preview == null || address == null || !address.usable) {
      _toast('Add a delivery address to place your order.');
      return;
    }
    if (_quoting || _quote == null) {
      _toast('Wait for a valid Logistics quote before placing the order.');
      return;
    }
    if (preview.shops.any((shop) => !_logistics.containsKey(shop.sellerId))) {
      _toast('Choose a Logistics provider for every shop.');
      return;
    }
    for (final shop in preview.shops) {
      final key = _voucherKey(shop.sellerId);
      if (key.isNotEmpty && key != _appliedVoucherKey[shop.sellerId]) {
        setState(
          () => _voucherErrors[shop.sellerId] =
              'Apply this voucher to check the total before placing the order.',
        );
        _toast('Apply the shop voucher first, then place the order.');
        return;
      }
    }

    setState(() => _placing = true);
    try {
      final orders = await BuyerApi.instance.placeOrder(
        itemIds: widget.itemIds,
        shippingAddress: address.line,
        provinceCode: address.provinceCode,
        cityCode: address.cityCode,
        checkoutRevision: preview.revision,
        shippingAddressId: address.savedId,
        shippingLatitude: address.latitude,
        shippingLongitude: address.longitude,
        shippingQuotes: {
          for (final shop in preview.shops)
            shop.sellerId: _shippingFeeFor(shop.sellerId).toStringAsFixed(2),
        },
        logisticsCompanyIds: {
          for (final shop in preview.shops)
            if (_logistics[shop.sellerId] != null)
              shop.sellerId: _logistics[shop.sellerId]!,
        },
        sellerNotes: {
          for (final shop in preview.shops)
            if (_noteCtrl(shop.sellerId).text.trim().isNotEmpty)
              '${shop.sellerId}': _noteCtrl(shop.sellerId).text.trim(),
        },
        voucherCodes: {
          for (final shop in preview.shops)
            if (_voucherKey(shop.sellerId).isNotEmpty)
              shop.sellerId: _voucherKey(shop.sellerId).split('|'),
        },
      );
      if (!mounted) return;
      // The ordered lines left the cart; refresh the shared count so badges
      // (like the home header) drop the items that were just paid for.
      BuyerApi.instance.cart().ignore();
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
        // Prices, stock, quotes or the cart changed; reload so the buyer reviews it again.
        _load();
      }
    } catch (_) {
      if (mounted)
        _toast('Could not reach Vendo. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  ApiShippingOption? _logisticsOption(int sellerId) {
    final quote = _quote;
    if (quote == null) return null;
    final wanted = _logistics[sellerId];
    for (final option
        in quote.options[sellerId] ?? const <ApiShippingOption>[]) {
      if (option.companyId == wanted) return option;
    }
    return quote.selected[sellerId];
  }

  double _shippingFeeFor(int sellerId) => _logisticsOption(sellerId)?.fee ?? 0;

  double get _itemsTotal =>
      _preview?.shops.fold<double>(0, (sum, shop) => sum + shop.itemsValue) ??
      0;

  int get _itemCount =>
      _preview?.cart.items.fold<int>(0, (sum, line) => sum + line.quantity) ??
      0;

  double get _voucherTotal =>
      _voucherDiscounts.values.fold<double>(0, (sum, value) => sum + value);

  double get _shippingTotal =>
      _preview?.shops.fold<double>(
        0,
        (sum, shop) => sum + _shippingFeeFor(shop.sellerId),
      ) ??
      0;

  double get _payableTotal {
    final total = _itemsTotal - _voucherTotal + _shippingTotal;
    return total < 0 ? 0 : total;
  }

  String _peso(double amount) => '₱${amount.toStringAsFixed(2)}';

  bool get _canPlaceOrder =>
      !_placing &&
      !_quoting &&
      _quote != null &&
      _quoteError == null &&
      _selected != null &&
      _selected!.usable &&
      (_preview?.shops.every((shop) => _logistics.containsKey(shop.sellerId)) ??
          false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _plum,
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
      // Fixed at the bottom of the screen, stays put while the page scrolls.
      bottomNavigationBar: _loading || _error != null || _preview == null
          ? null
          : _bottomBar(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44, color: _lite),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _plum),
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
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _addressSection(),
        _itemsSection(preview),
        _paymentSection(),
        _summarySection(),
      ],
    );
  }

  // ── Fixed bottom bar: Place order (left) + total (right of it) ───────────
  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          children: [
            // Total sits right next to the button, on its left side.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _quoting ? 'Calculating…' : _peso(_payableTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _plumMid,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Place order at the bottom right corner.
            SizedBox(
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _plum,
                  disabledBackgroundColor: const Color(0xFFC9BCCC),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _canPlaceOrder ? _placeOrder : null,
                child: Text(_placing ? 'Placing order…' : 'Place order'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delivery address ──────────────────────────────────────────────────────
  Widget _addressSection() {
    return _section(
      title: 'Delivery address',
      subtitle: 'Choose where this order should be delivered.',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _plumMid,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _plumMid,
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeliveryAddressScreen(),
                ),
              );
              if (mounted) _load();
            },
            child: const Text('Manage saved addresses'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _plumMid,
              side: const BorderSide(color: _accent),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: _openAddAddress,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add new address'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final choice in _addresses) _addressTile(choice),
          if (_selected == null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF1F3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Add a delivery address to place your order.',
                style: TextStyle(fontSize: 12, color: _red),
              ),
            ),
          const Text(
            'A delivery pin helps the assigned Rider find the destination. It is shared with Vendo and the Rider assigned to this order.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _addressTile(_AddressChoice address) {
    final selected = address.id == _selectedId;
    return GestureDetector(
      onTap: address.usable
          ? () {
              setState(() {
                _selectedId = address.id;
                _quote = null;
                _quoteError = null;
                _logistics.clear();
              });
              _refreshQuote();
            }
          : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _accent : _fieldBorder),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x14805487), spreadRadius: 1)]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _radioDot(selected),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: address.usable ? 1 : 0.7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          address.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        if (address.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _gold,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _plum,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (address.registered)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            _preview?.buyerName ?? '',
                            _preview?.buyerPhone ?? '',
                          ].where((part) => part.isNotEmpty).join(', '),
                          style: const TextStyle(fontSize: 12.5, color: _body),
                        ),
                      ),
                    if (address.usable)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          address.fullLine,
                          style: const TextStyle(fontSize: 12.5, color: _body),
                        ),
                      ),
                    if (address.usable &&
                        address.latitude != null &&
                        address.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 12,
                              color: _green,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Delivery pin saved',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _green,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Text(
                          'This address is incomplete, so it cannot be used for delivery. Add a new address, or update it in your profile.',
                          style: TextStyle(fontSize: 12, color: _red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _radioDot(bool selected) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _accent : Colors.white,
        border: Border.all(
          color: selected ? _accent : const Color(0xFFC9BCCC),
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _openAddAddress() async {
    final labelCtrl = TextEditingController();
    final lineCtrl = TextEditingController();
    int provinceIndex = _provinces.indexWhere(
      (province) => province.code == _selected?.provinceCode,
    );
    String? cityCode = _selected?.cityCode;
    String? sheetError;
    String? pinError;
    String mapAddress = '';
    double? latitude;
    double? longitude;
    bool locating = false;

    final added = await showModalBottomSheet<_AddressChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final province =
                provinceIndex >= 0 && provinceIndex < _provinces.length
                ? _provinces[provinceIndex]
                : null;
            final cities = province?.cities ?? const <ApiCity>[];

            // Applies a pin (from the map or the device) to the draft address:
            // coordinates, the written line and the province/city selects.
            void applyPin(ApiGeoPlace place) {
              setSheetState(() {
                latitude = place.latitude;
                longitude = place.longitude;
                mapAddress = place.formatted;
                pinError = null;
                final line = place.line.isNotEmpty
                    ? place.line
                    : place.formatted;
                if (line.isNotEmpty) lineCtrl.text = line;
                final index = _provinces.indexWhere(
                  (entry) => entry.code == place.provinceCode,
                );
                if (index >= 0) {
                  provinceIndex = index;
                  for (final entry in _provinces[index].cities) {
                    if (entry.code == place.cityCode) {
                      cityCode = entry.code;
                      break;
                    }
                  }
                }
              });
            }

            Future<void> openPinMap() async {
              final place = await Navigator.push<ApiGeoPlace>(
                sheetContext,
                MaterialPageRoute(
                  builder: (_) => AddressPinScreen(
                    initialLatitude: latitude,
                    initialLongitude: longitude,
                  ),
                ),
              );
              if (place != null) applyPin(place);
            }

            Future<void> useDeviceLocation() async {
              setSheetState(() {
                locating = true;
                pinError = null;
              });
              try {
                final place = await devicePinnedPlace();
                applyPin(place);
              } on DeviceLocationException catch (e) {
                if (mounted) setSheetState(() => pinError = e.message);
              } catch (_) {
                if (mounted) {
                  setSheetState(
                    () => pinError =
                        'Could not get the device location. Try again where the address is.',
                  );
                }
              } finally {
                if (mounted) setSheetState(() => locating = false);
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Add a delivery address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This address is used for this checkout only. To reuse it next time, save it on the web under Saved addresses.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _label('Label (optional)'),
                    TextField(
                      controller: labelCtrl,
                      maxLength: 40,
                      decoration: _fieldDeco(
                        hint: "Home, office, parents' house",
                      ),
                    ),
                    _label('House number, street, barangay and ZIP code'),
                    TextField(
                      controller: lineCtrl,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: _fieldDeco(),
                    ),
                    const SizedBox(height: 4),
                    _label('Province / Metro Manila'),
                    DropdownButtonFormField<int>(
                      initialValue: provinceIndex >= 0 ? provinceIndex : null,
                      isExpanded: true,
                      decoration: _fieldDeco(hint: 'Select province'),
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
                      onChanged: (index) => setSheetState(() {
                        provinceIndex = index ?? -1;
                        cityCode = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    _label('City / municipality'),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet-city-${province?.code}'),
                      initialValue: cities.any((city) => city.code == cityCode)
                          ? cityCode
                          : null,
                      isExpanded: true,
                      decoration: _fieldDeco(hint: 'Select city'),
                      items: cities
                          .map(
                            (city) => DropdownMenuItem(
                              value: city.code,
                              child: Text(
                                city.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: province == null
                          ? null
                          : (code) => setSheetState(() => cityCode = code),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: _fieldBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery pin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _body,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Place the pin on the map, or use this device’s location when you are at the address.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: openPinMap,
                                icon: const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  latitude == null
                                      ? 'Pin this address on the map'
                                      : 'Change on map',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _plumMid,
                                  side: const BorderSide(color: _accent),
                                  minimumSize: const Size(0, 40),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: locating ? null : useDeviceLocation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _plumMid,
                                  side: const BorderSide(color: _fieldBorder),
                                  minimumSize: const Size(0, 40),
                                ),
                                child: Text(
                                  locating
                                      ? 'Getting location…'
                                      : 'Use this device’s location',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          if (mapAddress.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Map address: $mapAddress',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: _green,
                                ),
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'No map pin yet. The typed address still works.',
                                style: TextStyle(fontSize: 11, color: _lite),
                              ),
                            ),
                          if (pinError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                pinError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (sheetError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          sheetError!,
                          style: const TextStyle(fontSize: 12, color: _red),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _body,
                              side: const BorderSide(color: _fieldBorder),
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _plum,
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: () {
                              final line = lineCtrl.text
                                  .replaceAll(RegExp(r'\s*\n\s*'), ', ')
                                  .trim();
                              final province =
                                  provinceIndex >= 0 &&
                                      provinceIndex < _provinces.length
                                  ? _provinces[provinceIndex]
                                  : null;
                              ApiCity? city;
                              for (final entry
                                  in province?.cities ?? const <ApiCity>[]) {
                                if (entry.code == cityCode) city = entry;
                              }
                              if (line.isEmpty) {
                                setSheetState(
                                  () => sheetError =
                                      'Enter your house number, street, barangay and ZIP code.',
                                );
                                return;
                              }
                              if (province == null) {
                                setSheetState(
                                  () => sheetError = 'Select a province.',
                                );
                                return;
                              }
                              if (city == null) {
                                setSheetState(
                                  () => sheetError =
                                      'Select a city or municipality.',
                                );
                                return;
                              }
                              Navigator.pop(
                                sheetContext,
                                _AddressChoice(
                                  id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
                                  label: labelCtrl.text.trim().isEmpty
                                      ? 'New address'
                                      : labelCtrl.text.trim(),
                                  line: line,
                                  province: province.name,
                                  city: city.name,
                                  provinceCode: province.code,
                                  cityCode: city.code,
                                  latitude: latitude,
                                  longitude: longitude,
                                  usable: true,
                                ),
                              );
                            },
                            child: const Text('Use this address'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    labelCtrl.dispose();
    lineCtrl.dispose();

    if (added == null || !mounted) return;
    setState(() {
      _addresses = [..._addresses, added];
      _selectedId = added.id;
      _quote = null;
      _quoteError = null;
      _logistics.clear();
    });
    _refreshQuote();
  }

  // ── Your items ────────────────────────────────────────────────────────────
  Widget _itemsSection(ApiCheckoutPreview preview) {
    final shops = preview.cart.shops;
    return _section(
      title: 'Your items',
      subtitle: shops.length > 1
          ? 'Items from different shops are placed as separate orders.'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < shops.length; index++) ...[
            if (index > 0) const Divider(height: 26, color: Color(0xFFF1E8F2)),
            _shopBlock(shops[index], preview, shops.length > 1),
          ],
          if (_quoteError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _quoteError!,
                style: const TextStyle(fontSize: 12, color: _red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shopBlock(
    ApiCartShop shop,
    ApiCheckoutPreview preview,
    bool multiShop,
  ) {
    final sellerId = shop.sellerId;
    final options = _quote?.options[sellerId] ?? const <ApiShippingOption>[];
    final option = _logisticsOption(sellerId);
    final discount = _voucherDiscounts[sellerId] ?? 0;
    final vouchers = preview.shops
        .firstWhere(
          (entry) => entry.sellerId == sellerId,
          orElse: () => const ApiCheckoutShop(
            sellerId: 0,
            shop: '',
            items: '',
            itemsValue: 0,
          ),
        )
        .vouchers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 16, color: _accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                shop.shop,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _plum,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final line in shop.items) _itemRow(line),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _fieldBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _quoting
                      ? 'Shipping · getting route quote…'
                      : option == null
                      ? 'Shipping'
                      : 'Shipping · ${option.hubCount} hub${option.hubCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
              Text(
                _quoting
                    ? '…'
                    : option == null
                    ? '—'
                    : _peso(option.fee),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _plum,
                ),
              ),
            ],
          ),
        ),
        if (options.length > 1)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose a Logistics provider',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _plum,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Only providers with a Station Hub near both this shop and your address are shown.',
                  style: TextStyle(fontSize: 11, color: _muted, height: 1.35),
                ),
                const SizedBox(height: 8),
                for (final candidate in options)
                  _logisticsTile(sellerId, candidate),
              ],
            ),
          ),
        if (preview.sellerNotesEnabled) ...[
          const SizedBox(height: 14),
          _label('Message for the seller (optional)'),
          TextField(
            controller: _noteCtrl(sellerId),
            maxLines: 2,
            minLines: 2,
            maxLength: 300,
            style: const TextStyle(fontSize: 13, color: _ink),
            decoration:
                _fieldDeco(
                  hint:
                      'Anything ${shop.shop} should know, like a preferred delivery time or a gift message',
                ).copyWith(
                  helperText: 'The seller sees this with your order.',
                  helperStyle: const TextStyle(fontSize: 11, color: _muted),
                  counterStyle: const TextStyle(fontSize: 11, color: _muted),
                ),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _fieldBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Shop voucher (optional)'),
              if (vouchers.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Shop vouchers matching these items',
                    style: TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
              for (final voucher in vouchers)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7FB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${voucher.code} — ${voucher.discountLabel}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _plumMid,
                        ),
                      ),
                      if (voucher.details.isNotEmpty)
                        Text(
                          voucher.details,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: _muted,
                          ),
                        ),
                      if (!voucher.eligible && voucher.reason != null)
                        Text(
                          voucher.reason!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _red,
                          ),
                        ),
                    ],
                  ),
                ),
              if (vouchers.any((voucher) => voucher.eligible)) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('voucher-choice-$sellerId'),
                  isExpanded: true,
                  decoration: _fieldDeco(hint: 'Choose a shop voucher'),
                  items: vouchers
                      .where((voucher) => voucher.eligible)
                      .map(
                        (voucher) => DropdownMenuItem(
                          value: voucher.code,
                          child: Text(
                            '${voucher.name} · ${voucher.code} · ${voucher.discountLabel}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (code) {
                    if (code == null) return;
                    _codeCtrl(sellerId).text = code;
                    _choiceCtrl(sellerId).text = code;
                    _applyVoucher(sellerId);
                  },
                ),
                const SizedBox(height: 10),
              ],
              _label('Or enter a voucher code'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl(sellerId),
                      maxLength: 12,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[A-Za-z0-9]'),
                        ),
                      ],
                      style: const TextStyle(fontSize: 13, color: _ink),
                      decoration: _fieldDeco(
                        hint: 'Enter code',
                      ).copyWith(counterText: ''),
                      onChanged: (_) => setState(() {
                        _voucherDiscounts[sellerId] = 0;
                        _appliedVoucherKey[sellerId] = '';
                        _voucherErrors.remove(sellerId);
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _plumMid,
                        side: const BorderSide(color: _accent),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _applyingVoucher.contains(sellerId)
                          ? null
                          : () => _applyVoucher(sellerId),
                      child: _applyingVoucher.contains(sellerId)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _label(
                'Second voucher (optional — one shop-wide plus one product or category voucher)',
              ),
              TextField(
                controller: _extraCtrl(sellerId),
                maxLength: 12,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                ],
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: _fieldDeco(
                  hint: 'Enter a second code',
                ).copyWith(counterText: ''),
                onChanged: (_) => setState(() {
                  _voucherDiscounts[sellerId] = 0;
                  _appliedVoucherKey[sellerId] = '';
                  _voucherErrors.remove(sellerId);
                }),
              ),
              if (discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Discount: ${_peso(discount)}',
                    style: const TextStyle(fontSize: 12, color: _green),
                  ),
                ),
              if (_voucherErrors[sellerId] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _voucherErrors[sellerId]!,
                    style: const TextStyle(fontSize: 12, color: _red),
                  ),
                ),
            ],
          ),
        ),
        if (multiShop)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Order from this shop',
                    style: TextStyle(fontSize: 12, color: _body),
                  ),
                ),
                Text(
                  _peso(shop.subtotalValue),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _itemRow(ApiCartLine line) {
    final options = [
      if (line.variantLabel != null && line.variantLabel!.isNotEmpty)
        line.variantLabel!,
      if (line.color != null && line.color!.isNotEmpty) 'Color: ${line.color}',
      if (line.size != null && line.size!.isNotEmpty) 'Size: ${line.size}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 64,
              height: 64,
              color: const Color(0xFFFAF7FB),
              child: line.image.isEmpty
                  ? const Icon(
                      Icons.image_not_supported_outlined,
                      size: 22,
                      color: _lite,
                    )
                  : Image.network(
                      line.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 22,
                        color: _lite,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: _ink,
                  ),
                ),
                if (options.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      options.join(', '),
                      style: const TextStyle(fontSize: 12, color: _lite),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '${_peso(line.unitPriceValue)} each, quantity ${line.quantity}',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _peso(line.unitPriceValue * line.quantity),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _plumMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logisticsTile(int sellerId, ApiShippingOption option) {
    final selected = _logistics[sellerId] == option.companyId;
    return GestureDetector(
      onTap: () => setState(() => _logistics[sellerId] = option.companyId),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? _selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? _accent : _fieldBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _radioDot(selected),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        option.companyName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      if (option.isCheapest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'Lowest fee',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _plum,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.routeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _peso(option.fee),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _plumMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment ───────────────────────────────────────────────────────────────
  Widget _paymentSection() {
    return _section(
      title: 'Payment method',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _selectedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accent),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _radioDot(true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cash on delivery',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Pay in cash when your order is delivered. Other payment methods are not available yet.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _body,
                      height: 1.35,
                    ),
                  ),
                  if (_payableTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Pay ${_peso(_payableTotal)} in cash to the rider (items plus delivery fee).',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _plumMid,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Order summary (no button here; Place order lives in the bottom bar) ──
  Widget _summarySection() {
    final address = _selected;
    return _section(
      title: 'Order summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Items ($_itemCount)', _peso(_itemsTotal)),
          if (_voucherTotal > 0)
            _summaryRow(
              'Shop vouchers',
              '−${_peso(_voucherTotal)}',
              green: true,
            ),
          _summaryRow(
            'Shipping fee',
            _quoting ? 'Calculating…' : _peso(_shippingTotal),
          ),
          const Divider(height: 22, color: Color(0xFFF1E8F2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                _peso(_payableTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _plumMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '₱45 minimum covers up to two hubs. Each additional hub adds ₱10.',
            style: TextStyle(fontSize: 11, color: _lite),
          ),
          if (address != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _band,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivering to',
                    style: TextStyle(fontSize: 12, color: _lite),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.fullLine,
                    style: const TextStyle(fontSize: 12.5, color: _ink),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: Text(
              'By placing your order you agree to pay ${_peso(_payableTotal)} on delivery.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _lite),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool green = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: green ? _green : _muted),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: green ? _green : _ink),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ───────────────────────────────────────────────────────────
  Widget _section({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: _band,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _plum,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: trailing,
                  ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _body,
        ),
      ),
    );
  }

  InputDecoration _fieldDeco({String? hint}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFB7A9BA)),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: border(_fieldBorder),
      focusedBorder: border(_accent),
      border: border(_fieldBorder),
    );
  }
}