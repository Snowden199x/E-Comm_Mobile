import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (matches the buyer app)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const headerTop = Color(0xFF3B1F52);
  static const headerBot = Color(0xFF2A1440);
  static const orange = Color(0xFFE8873A);
  static const purpleDark = Color(0xFF2D1B3D);
  static const purpleMid = Color(0xFF7B2FBE);
  static const bg = Color(0xFFF4F1F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF888888);
  static const border = Color(0xFFECE6EA);
  static const checkActive = Color(0xFFE8873A);
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder data models
// ─────────────────────────────────────────────────────────────────────────────
class _CartItem {
  final String name;
  final String variant;
  final int price;
  final IconData icon;
  bool selected = false;
  int qty = 1;

  _CartItem({
    required this.name,
    required this.variant,
    required this.price,
    required this.icon,
  });
}

class _CartShop {
  final String name;
  final List<_CartItem> items;
  bool selected = false;

  _CartShop({required this.name, required this.items});
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
  // Placeholder data — will be replaced with API data
  final List<_CartShop> _shops = [
    _CartShop(
      name: 'Vendo Official Store',
      items: [
        _CartItem(
          name: 'Wireless Earbuds Pro',
          variant: 'Black',
          price: 1299,
          icon: Icons.headphones,
        ),
        _CartItem(
          name: 'USB-C Charging Cable 2m',
          variant: 'White',
          price: 249,
          icon: Icons.cable,
        ),
      ],
    ),
    _CartShop(
      name: 'Tech Gadgets PH',
      items: [
        _CartItem(
          name: 'Smart Watch Series 5',
          variant: 'Silver / 44mm',
          price: 2499,
          icon: Icons.watch,
        ),
      ],
    ),
    _CartShop(
      name: 'Fashion Hub MNL',
      items: [
        _CartItem(
          name: "Women's Running Sneakers",
          variant: 'White / Size 7',
          price: 1799,
          icon: Icons.do_not_step,
        ),
        _CartItem(
          name: 'Canvas Tote Bag',
          variant: 'Beige',
          price: 599,
          icon: Icons.backpack,
        ),
      ],
    ),
  ];

  bool _selectAll = false;

  int get _totalItems => _shops.fold(0, (s, shop) => s + shop.items.length);

  int get _selectedTotal => _shops.fold(0, (sum, shop) {
    return sum +
        shop.items.fold(
          0,
          (s, item) => s + (item.selected ? item.price * item.qty : 0),
        );
  });

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
    _selectAll = _shops.every((shop) => shop.items.every((i) => i.selected));
  }

  void _changeQty(_CartItem item, int delta) {
    setState(() {
      final next = item.qty + delta;
      if (next >= 1) item.qty = next;
    });
  }

  void _deleteItem(_CartShop shop, _CartItem item) {
    setState(() {
      shop.items.remove(item);
      if (shop.items.isEmpty) _shops.remove(shop);
      _syncSelectAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          _CartHeader(totalItems: _totalItems),

          // ── List ────────────────────────────────────────────────
          Expanded(
            child: _shops.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _shops.length + 1, // +1 for voucher row
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index < _shops.length) {
                        return _ShopCard(
                          shop: _shops[index],
                          onToggleShop: (v) => _toggleShop(_shops[index], v),
                          onToggleItem: (item, v) =>
                              _toggleItem(_shops[index], item, v),
                          onChangeQty: _changeQty,
                          onDelete: (item) => _deleteItem(_shops[index], item),
                        );
                      }
                      // Platform voucher row at the end
                      return _VendoVoucherRow();
                    },
                  ),
          ),

          // ── Checkout bar ─────────────────────────────────────────
          _CheckoutBar(
            selectAll: _selectAll,
            onSelectAll: _toggleAll,
            total: _selectedTotal,
            selectedCount: _selectedCount,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _CartHeader extends StatelessWidget {
  final int totalItems;
  const _CartHeader({required this.totalItems});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.headerTop, _C.headerBot],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
          child: Row(
            children: [
              // Back arrow (visual only inside tab — kept for consistency)
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              Expanded(
                child: Text(
                  'Shopping Cart ($totalItems)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Edit button
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 36),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Chat icon with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: _C.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop card  (groups items from the same shop)
// ─────────────────────────────────────────────────────────────────────────────
class _ShopCard extends StatelessWidget {
  final _CartShop shop;
  final ValueChanged<bool?> onToggleShop;
  final void Function(_CartItem, bool?) onToggleItem;
  final void Function(_CartItem, int) onChangeQty;
  final void Function(_CartItem) onDelete;

  const _ShopCard({
    required this.shop,
    required this.onToggleShop,
    required this.onToggleItem,
    required this.onChangeQty,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Shop header ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                _Checkbox(value: shop.selected, onChanged: onToggleShop),
                const SizedBox(width: 8),
                const Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: _C.purpleDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    shop.name,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: _C.muted),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _C.border),

          // ── Items ──────────────────────────────────────────────
          ...shop.items.map(
            (item) => _CartItemRow(
              item: item,
              onToggle: (v) => onToggleItem(item, v),
              onChangeQty: (d) => onChangeQty(item, d),
              onDelete: () => onDelete(item),
            ),
          ),

          const Divider(height: 1, color: _C.border),

          // ── Voucher row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: const [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 16,
                  color: _C.orange,
                ),
                SizedBox(width: 8),
                Text(
                  'Add shop voucher code',
                  style: TextStyle(color: _C.ink, fontSize: 13),
                ),
                Spacer(),
                Icon(Icons.chevron_right, size: 16, color: _C.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single cart item row
// ─────────────────────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final _CartItem item;
  final ValueChanged<bool?> onToggle;
  final ValueChanged<int> onChangeQty;
  final VoidCallback onDelete;

  const _CartItemRow({
    required this.item,
    required this.onToggle,
    required this.onChangeQty,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: _Checkbox(value: item.selected, onChanged: onToggle),
          ),
          const SizedBox(width: 10),

          // Product image placeholder
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border),
            ),
            child: Center(
              child: Icon(item.icon, size: 36, color: _C.purpleMid),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  item.name,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Variant chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _C.border),
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFFF8F5FB),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.variant,
                        style: const TextStyle(color: _C.ink, fontSize: 11.5),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: _C.muted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Price + quantity stepper
                Row(
                  children: [
                    Text(
                      '₱${item.price}',
                      style: const TextStyle(
                        color: _C.orange,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),

                    // Delete
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: _C.muted,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Stepper
                    _QtyStepper(
                      qty: item.qty,
                      onMinus: () => onChangeQty(-1),
                      onPlus: () => onChangeQty(1),
                    ),
                  ],
                ),
              ],
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
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove, onTap: onMinus, enabled: qty > 1),
          Container(width: 1, height: double.infinity, color: _C.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$qty',
              style: const TextStyle(
                color: _C.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(width: 1, height: double.infinity, color: _C.border),
          _StepBtn(icon: Icons.add, onTap: onPlus, enabled: true),
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
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 16, color: enabled ? _C.ink : _C.border),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vendo platform voucher row  (below the shop cards)
// ─────────────────────────────────────────────────────────────────────────────
class _VendoVoucherRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: const [
          Icon(Icons.local_offer_outlined, size: 18, color: _C.orange),
          SizedBox(width: 10),
          Text(
            'Vendo Vouchers',
            style: TextStyle(
              color: _C.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          Spacer(),
          Text(
            'Select or enter code',
            style: TextStyle(color: _C.muted, fontSize: 12.5),
          ),
          SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: _C.muted),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom checkout bar
// ─────────────────────────────────────────────────────────────────────────────
class _CheckoutBar extends StatelessWidget {
  final bool selectAll;
  final ValueChanged<bool?> onSelectAll;
  final int total;
  final int selectedCount;

  const _CheckoutBar({
    required this.selectAll,
    required this.onSelectAll,
    required this.total,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              // Select all
              _Checkbox(value: selectAll, onChanged: onSelectAll),
              const SizedBox(width: 6),
              const Text(
                'All',
                style: TextStyle(
                  color: _C.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              // Total
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${total == 0 ? '0' : _formatPrice(total)}',
                    style: const TextStyle(
                      color: _C.orange,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Checkout button
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: selectedCount > 0 ? () {} : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.orange,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    elevation: 0,
                  ),
                  child: Text(
                    'Check Out ($selectedCount)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(int p) {
    final s = p.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
              color: Color(0xFFEDE5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 52,
              color: _C.purpleMid,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              color: _C.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items from the store to get started.',
            style: TextStyle(color: _C.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom orange checkbox
// ─────────────────────────────────────────────────────────────────────────────
class _Checkbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _Checkbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value ? _C.checkActive : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: value ? _C.checkActive : const Color(0xFFCCCCCC),
            width: 1.5,
          ),
        ),
        child: value
            ? const Icon(Icons.check, size: 13, color: Colors.white)
            : null,
      ),
    );
  }
}
