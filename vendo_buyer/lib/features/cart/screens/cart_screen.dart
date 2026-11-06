import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/checkout/screens/checkout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette — "Luxe Marketplace Cart" design system
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFFFF7FF); // background / surface
  static const card = Color(0xFFFFFFFF); // surface-container-lowest
  static const plum = Color(0xFF2E1535); // primary-container
  static const ink = Color(0xFF120019); // primary
  static const onSurfaceVar = Color(0xFF4C444C);
  static const outline = Color(0xFF7D747C);
  static const outlineVar = Color(0xFFCEC3CC);
  static const border = Color(0xFFE4DDE6); // outline-variant @ ~40%
  static const hairline = Color(0xFFEFE8F1); // outline-variant @ ~30%
  static const tint = Color(0xFFFBF0FF); // surface-container-low
  static const tintHigh = Color(0xFFF1E4F9); // surface-container-high
  static const tintHighest = Color(0xFFEBDEF3); // surface-container-highest
  static const deleteRed = Color(0xFF5C1324);
}

// Fonts from the design (Epilogue / Plus Jakarta Sans). If they are not
// bundled in pubspec.yaml Flutter silently falls back to the default font.
const String _fHead = 'Epilogue';
const String _fBody = 'PlusJakartaSans';

const double _freeShippingMin = 1000;

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _CartItem {
  final int id;
  final int productId;
  final String name;
  final String variant;
  final double price;
  final String image;
  final int stock;
  final IconData icon;
  bool selected = false;
  int qty;

  _CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.variant,
    required this.price,
    required this.image,
    required this.stock,
    required this.icon,
    this.qty = 1,
  });
}

class _CartShop {
  final int sellerId;
  final String name;
  final List<_CartItem> items;
  bool selected = false;

  _CartShop({required this.sellerId, required this.name, required this.items});
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _formatPrice(double value) {
  final text = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  final parts = text.split('.');
  final whole = parts.first;
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  if (parts.length > 1) buf.write('.${parts.last}');
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Cart screen
// ─────────────────────────────────────────────────────────────────────────────
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<_CartShop> _shops = [];
  bool _loading = true;
  String? _error;
  bool _showHint = true;
  bool _editMode = false;

  final TextEditingController _couponCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cart = await BuyerApi.instance.cart();
      if (!mounted) return;
      setState(() {
        _shops = cart.shops.map(_mapShop).toList();
        _loading = false;
        _selectAll = false;
      });
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

  _CartShop _mapShop(ApiCartShop shop) => _CartShop(
    sellerId: shop.sellerId,
    name: shop.shop,
    items: shop.items
        .map((line) => _CartItem(
              id: line.id,
              productId: line.productId,
              name: line.name,
              variant: line.variantText,
              price: line.unitPriceValue,
              image: line.image,
              stock: line.stock,
              qty: line.quantity,
              icon: Icons.shopping_bag_outlined,
            ))
        .toList(),
  );

  bool _selectAll = false;

  int get _totalItems => _shops.fold(0, (s, shop) => s + shop.items.length);

  double get _selectedTotal => _shops.fold<double>(0, (sum, shop) {
    return sum +
        shop.items.fold<double>(
          0,
          (s, item) => s + (item.selected ? item.price * item.qty : 0),
        );
  });

  List<int> get _selectedIds => _shops
      .expand((shop) => shop.items)
      .where((item) => item.selected)
      .map((item) => item.id)
      .toList();

  Future<void> _checkout() async {
    final ids = _selectedIds;
    if (ids.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(itemIds: ids)),
    );
    if (mounted) _loadCart();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int get _selectedCount => _shops.fold(
    0,
    (s, shop) => s + shop.items.where((i) => i.selected).length,
  );

  void _toggleAll(bool? val) {
    final v = val ?? false;
    setState(() {
      _selectAll = v;
      for (final shop in _shops) {
        shop.selected = v;
        for (final item in shop.items) {
          item.selected = v;
        }
      }
    });
  }

  void _toggleShop(_CartShop shop, bool? val) {
    final v = val ?? false;
    setState(() {
      shop.selected = v;
      for (final item in shop.items) {
        item.selected = v;
      }
      _syncSelectAll();
    });
  }

  void _toggleItem(_CartShop shop, _CartItem item, bool? val) {
    setState(() {
      item.selected = val ?? false;
      shop.selected = shop.items.every((i) => i.selected);
      _syncSelectAll();
    });
  }

  void _syncSelectAll() {
    _selectAll = _shops.isNotEmpty &&
        _shops.every((shop) => shop.items.isNotEmpty && shop.items.every((i) => i.selected));
  }

  Future<void> _changeQty(_CartItem item, int delta) async {
    final next = item.qty + delta;
    if (next < 1 || next > item.stock) return;
    final previous = item.qty;
    setState(() => item.qty = next);
    try {
      await BuyerApi.instance.updateCartLine(item.id, next);
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() => item.qty = previous);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => item.qty = previous);
      _toast('Could not update the cart. Check your connection.');
    }
  }

  /// Removes the line on the server. Returns true when it succeeded.
  Future<bool> _removeRemote(_CartItem item) async {
    try {
      await BuyerApi.instance.removeCartLine(item.id);
      return true;
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
      return false;
    } catch (_) {
      if (mounted) _toast('Could not remove the item. Check your connection.');
      return false;
    }
  }

  void _removeLocal(_CartShop shop, _CartItem item) {
    if (!mounted) return;
    setState(() {
      shop.items.remove(item);
      if (shop.items.isEmpty) _shops.remove(shop);
      _syncSelectAll();
    });
  }

  // Used by the trash button (edit mode).
  Future<void> _deleteItem(_CartShop shop, _CartItem item) async {
    if (!await _removeRemote(item)) return;
    _removeLocal(shop, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
      Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          _CartHeader(
            totalItems: _totalItems,
            editMode: _editMode,
            onBack: () => Navigator.of(context).maybePop(),
            onEdit: () => setState(() => _editMode = !_editMode),
          ),

          // ── List ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _C.plum),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: _fBody,
                              color: _C.onSurfaceVar,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _C.plum,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _loadCart,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _shops.isEmpty
                ? const _EmptyCart()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                    children: [
                      if (_showHint) ...[
                        _SwipeHint(
                          onClose: () => setState(() => _showHint = false),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _FreeShippingCard(subtotal: _selectedTotal),
                      const SizedBox(height: 8),
                      for (final shop in _shops) ...[
                        _ShopCard(
                          shop: shop,
                          editMode: _editMode,
                          onToggleShop: (v) => _toggleShop(shop, v),
                          onToggleItem: (item, v) => _toggleItem(shop, item, v),
                          onChangeQty: _changeQty,
                          onTrash: (item) => _deleteItem(shop, item),
                          onConfirmSwipe: _removeRemote,
                          onSwiped: (item) => _removeLocal(shop, item),
                        ),
                        const SizedBox(height: 8),
                      ],
                      _VendoVoucherCard(controller: _couponCtrl, onApply: () {
                        FocusScope.of(context).unfocus();
                        if (_couponCtrl.text.trim().isEmpty) return;
                        _toast('Voucher codes are applied at checkout.');
                      }),
                    ],
                  ),
          ),

          // ── Checkout bar ─────────────────────────────────────────
          _CheckoutBar(
            key: _barKey,
            selectAll: _selectAll,
            onSelectAll: _toggleAll,
            total: _selectedTotal,
            selectedCount: _selectedCount,
            onCheckout: _checkout,
            summaryOpen: _summaryOpen,
            onShowSummary: _toggleSummary,
          ),
        ],
      ),

      // ── Payment summary: scrim + panel that sits ABOVE the checkout bar ──
      if (_summaryOpen) ...[
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: _barHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleSummary,
            child: Container(color: const Color(0x66120019)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: _barHeight,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: const BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: _PaymentSummary(total: _selectedTotal),
          ),
        ),
      ],
        ],
      ),
    );
  }

  final GlobalKey _barKey = GlobalKey();
  bool _summaryOpen = false;
  double _barHeight = 0;

  void _toggleSummary() {
    if (!_summaryOpen) {
      _barHeight = (_barKey.currentContext?.size?.height) ?? 64;
    }
    setState(() => _summaryOpen = !_summaryOpen);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _CartHeader extends StatelessWidget {
  final int totalItems;
  final bool editMode;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  const _CartHeader({
    required this.totalItems,
    required this.editMode,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.bg,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F2E1535),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // Cart is opened as a pushed route, so the arrow returns to the previous screen.
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: _C.ink,
                    size: 22,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Shopping Cart ($totalItems)',
                    style: const TextStyle(
                      fontFamily: _fHead,
                      color: _C.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: _C.ink,
                    minimumSize: const Size(48, 44),
                  ),
                  child: Text(
                    editMode ? 'Done' : 'Edit',
                    style: const TextStyle(
                      fontFamily: _fBody,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe hint
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeHint extends StatelessWidget {
  final VoidCallback onClose;
  const _SwipeHint({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: _C.tintHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.outlineVar.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swipe_left_alt_rounded, size: 16, color: _C.plum),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Swipe any item left to delete',
              style: TextStyle(
                fontFamily: _fBody,
                color: _C.onSurfaceVar,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 14, color: _C.outline),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Free shipping progress
// ─────────────────────────────────────────────────────────────────────────────
class _FreeShippingCard extends StatelessWidget {
  final double subtotal;
  const _FreeShippingCard({required this.subtotal});

  @override
  Widget build(BuildContext context) {
    final unlocked = subtotal >= _freeShippingMin;
    final progress = (subtotal / _freeShippingMin).clamp(0.0, 1.0);
    final remaining = _freeShippingMin - subtotal;

    return _Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 20, color: _C.plum),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  unlocked ? 'Free Shipping Unlocked!' : 'Almost free shipping',
                  style: const TextStyle(
                    fontFamily: _fBody,
                    color: _C.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Min. ₱${_formatPrice(_freeShippingMin)} spend',
                style: const TextStyle(
                  fontFamily: _fBody,
                  color: _C.onSurfaceVar,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: _C.tintHighest,
              valueColor: const AlwaysStoppedAnimation(_C.plum),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                unlocked ? Icons.check_circle : Icons.info_outline_rounded,
                size: 14,
                color: _C.plum,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  unlocked
                      ? 'Your order qualifies for nationwide free parcel delivery'
                      : 'Add ₱${_formatPrice(remaining)} more to unlock free parcel delivery',
                  style: const TextStyle(
                    fontFamily: _fBody,
                    color: _C.onSurfaceVar,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shop card  (groups items from the same shop)
// ─────────────────────────────────────────────────────────────────────────────
class _ShopCard extends StatelessWidget {
  final _CartShop shop;
  final bool editMode;
  final ValueChanged<bool?> onToggleShop;
  final void Function(_CartItem, bool?) onToggleItem;
  final void Function(_CartItem, int) onChangeQty;
  final void Function(_CartItem) onTrash;
  final Future<bool> Function(_CartItem) onConfirmSwipe;
  final void Function(_CartItem) onSwiped;

  const _ShopCard({
    required this.shop,
    required this.editMode,
    required this.onToggleShop,
    required this.onToggleItem,
    required this.onChangeQty,
    required this.onTrash,
    required this.onConfirmSwipe,
    required this.onSwiped,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Shop header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.hairline)),
            ),
            child: Row(
              children: [
                _Checkbox(value: shop.selected, onChanged: onToggleShop),
                const SizedBox(width: 8),
                const Icon(Icons.storefront_outlined, size: 18, color: _C.ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    shop.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _fBody,
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 20, color: _C.onSurfaceVar),
              ],
            ),
          ),

          // ── Items ──────────────────────────────────────────────
          for (var i = 0; i < shop.items.length; i++) ...[
            _SwipeToDelete(
              key: ValueKey('cart-line-${shop.items[i].id}'),
              onConfirm: () => onConfirmSwipe(shop.items[i]),
              onDismissed: () => onSwiped(shop.items[i]),
              child: _CartItemRow(
                item: shop.items[i],
                editMode: editMode,
                onToggle: (v) => onToggleItem(shop.items[i], v),
                onChangeQty: (d) => onChangeQty(shop.items[i], d),
                onTrash: () => onTrash(shop.items[i]),
              ),
            ),
            if (i < shop.items.length - 1)
              const Divider(height: 1, color: _C.hairline),
          ],

          // ── Store voucher banner ───────────────────────────────
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.tint,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.sell_outlined, size: 18, color: _C.plum),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add shop voucher code',
                    style: TextStyle(
                      fontFamily: _fBody,
                      color: _C.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: _C.plum),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe-left-to-delete wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeToDelete extends StatelessWidget {
  final Widget child;
  final Future<bool> Function() onConfirm;
  final VoidCallback onDismissed;

  const _SwipeToDelete({
    super.key,
    required this.child,
    required this.onConfirm,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      confirmDismiss: (_) => onConfirm(),
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: const BoxDecoration(
          color: _C.deleteRed,
          borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(height: 2),
            Text(
              'Delete',
              style: TextStyle(
                fontFamily: _fBody,
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single cart item row
// ─────────────────────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final _CartItem item;
  final bool editMode;
  final ValueChanged<bool?> onToggle;
  final ValueChanged<int> onChangeQty;
  final VoidCallback onTrash;

  const _CartItemRow({
    required this.item,
    required this.editMode,
    required this.onToggle,
    required this.onChangeQty,
    required this.onTrash,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.card, // keeps the row opaque while it is swiped
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Checkbox(value: item.selected, onChanged: onToggle),
          const SizedBox(width: 8),

          // Product photo (falls back to an icon when the photo cannot load)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.tintHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              item.image,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(item.icon, size: 34, color: _C.plum),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: SizedBox(
              height: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _fBody,
                          color: _C.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (item.variant.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _C.tint,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _C.outlineVar.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  item.variant,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: _fBody,
                                    color: _C.onSurfaceVar,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 12,
                                color: _C.onSurfaceVar,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Price + quantity stepper
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '₱${_formatPrice(item.price)}',
                            style: const TextStyle(
                              fontFamily: _fHead,
                              color: _C.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                      if (editMode) ...[
                        GestureDetector(
                          onTap: onTrash,
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: _C.deleteRed,
                            ),
                          ),
                        ),
                      ],
                      _QtyStepper(
                        qty: item.qty,
                        canIncrease: item.qty < item.stock,
                        onMinus: () => onChangeQty(-1),
                        onPlus: () => onChangeQty(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity stepper  — [ − qty + ]
// ─────────────────────────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  final int qty;
  final bool canIncrease;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyStepper({
    required this.qty,
    required this.canIncrease,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: _C.card,
        border: Border.all(color: _C.outlineVar.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove, onTap: onMinus, enabled: qty > 1),
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '$qty',
                style: const TextStyle(
                  fontFamily: _fBody,
                  color: _C.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _StepBtn(icon: Icons.add, onTap: onPlus, enabled: canIncrease),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _StepBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          icon,
          size: 14,
          color: enabled ? _C.ink : _C.outlineVar,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vendo platform vouchers
// ─────────────────────────────────────────────────────────────────────────────
class _VendoVoucherCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onApply;
  const _VendoVoucherCard({required this.controller, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.confirmation_number, size: 22, color: _C.plum),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Vendo Vouchers',
                  style: TextStyle(
                    fontFamily: _fBody,
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onApply(),
                    style: const TextStyle(
                      fontFamily: _fBody,
                      color: _C.ink,
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      hintStyle: const TextStyle(
                        fontFamily: _fBody,
                        color: _C.outline,
                        fontSize: 12,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: _C.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _C.outlineVar),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _C.plum),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.plum,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontFamily: _fBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Payment summary
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentSummary extends StatelessWidget {
  final double total;
  const _PaymentSummary({required this.total});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.hairline)),
            ),
            child: const Text(
              'Payment Summary',
              style: TextStyle(
                fontFamily: _fBody,
                color: _C.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Merchandise Subtotal',
            value: '₱${_formatPrice(total)}',
          ),
          const SizedBox(height: 8),
          const _SummaryRow(
            label: 'Shipping Fee',
            value: 'Calculated at checkout',
            smallValue: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.hairline)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Total Payment',
                  style: TextStyle(
                    fontFamily: _fBody,
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '₱${_formatPrice(total)}',
                  style: const TextStyle(
                    fontFamily: _fHead,
                    color: _C.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool smallValue;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: _fBody,
            color: _C.onSurfaceVar,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: _fBody,
            color: smallValue ? _C.onSurfaceVar : _C.ink,
            fontSize: smallValue ? 12 : 15,
            fontWeight: smallValue ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom checkout bar
// ─────────────────────────────────────────────────────────────────────────────
class _CheckoutBar extends StatelessWidget {
  final bool selectAll;
  final ValueChanged<bool?> onSelectAll;
  final double total;
  final int selectedCount;
  final VoidCallback? onCheckout;
  final VoidCallback onShowSummary;
  final bool summaryOpen;

  const _CheckoutBar({
    super.key,
    required this.summaryOpen,
    required this.selectAll,
    required this.onSelectAll,
    required this.total,
    required this.selectedCount,
    required this.onShowSummary,
    this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0;
    return Container(
      decoration: const BoxDecoration(
        color: _C.card,
        border: Border(top: BorderSide(color: _C.hairline)),
        boxShadow: [
          BoxShadow(
            color: Color(0x142E1535),
            blurRadius: 24,
            spreadRadius: -4,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              // Select all
              _Checkbox(value: selectAll, onChanged: onSelectAll),
              const SizedBox(width: 6),
              const Text(
                'All',
                style: TextStyle(
                  fontFamily: _fBody,
                  color: _C.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),

              // Total (right side, next to the button) — tap to toggle summary
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onShowSummary,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total Payment',
                              style: TextStyle(
                                fontFamily: _fBody,
                                color: _C.onSurfaceVar,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '₱${_formatPrice(total)}',
                                style: const TextStyle(
                                  fontFamily: _fHead,
                                  color: _C.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        summaryOpen
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        size: 22,
                        color: _C.plum,
                      ),
                    ],
                  ),
                ),
                ),
              ),
              const SizedBox(width: 8),

              // Checkout button (boxy with soft corners)
              ElevatedButton(
                onPressed: enabled ? onCheckout : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.plum,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD9D2DC),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Check Out ($selectedCount)',
                  style: const TextStyle(
                    fontFamily: _fBody,
                    fontSize: 13,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty cart state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: _C.tintHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: _C.plum,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontFamily: _fHead,
              color: _C.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items from the store to get started.',
            style: TextStyle(
              fontFamily: _fBody,
              color: _C.onSurfaceVar,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card container
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom plum checkbox (44px tap target, 20px visual)
// ─────────────────────────────────────────────────────────────────────────────
class _Checkbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _Checkbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? _C.plum : _C.card,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: value ? _C.plum : _C.outline,
              width: 1.5,
            ),
          ),
          child: value
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}