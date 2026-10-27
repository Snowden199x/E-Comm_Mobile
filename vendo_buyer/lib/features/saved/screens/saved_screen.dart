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
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder saved item model
// ─────────────────────────────────────────────────────────────────────────────
class _SavedItem {
  final String name;
  final String shop;
  final String price;
  final IconData icon;

  const _SavedItem({
    required this.name,
    required this.shop,
    required this.price,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved Items Screen
// ─────────────────────────────────────────────────────────────────────────────
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  // Placeholder data — will be replaced with API data
  final List<_SavedItem> _items = const [
    _SavedItem(
      name: 'Wireless Earbuds Pro',
      shop: 'Vendo Official Store',
      price: '₱1,299',
      icon: Icons.headphones,
    ),
    _SavedItem(
      name: 'Smart Watch Series 5',
      shop: 'Tech Gadgets PH',
      price: '₱2,499',
      icon: Icons.watch,
    ),
    _SavedItem(
      name: "Women's Running Sneakers",
      shop: 'Fashion Hub MNL',
      price: '₱1,799',
      icon: Icons.do_not_step,
    ),
    _SavedItem(
      name: 'Travel Backpack Pro',
      shop: 'Outdoor Gear PH',
      price: '₱899',
      icon: Icons.backpack,
    ),
    _SavedItem(
      name: 'Coffee Maker Deluxe',
      shop: 'Home Essentials Store',
      price: '₱3,299',
      icon: Icons.coffee,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _SavedHeader(count: _items.length),
          Expanded(
            child: _items.isEmpty
                ? const _EmptySaved()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.70,
                        ),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _SavedCard(
                      item: _items[i],
                      onRemove: () => setState(() => _items.removeAt(i)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _SavedHeader extends StatelessWidget {
  final int count;
  const _SavedHeader({required this.count});

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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saved Items',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count item${count == 1 ? '' : 's'} saved',
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Heart illustration
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 22,
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
// Saved item card
// ─────────────────────────────────────────────────────────────────────────────
class _SavedCard extends StatelessWidget {
  final _SavedItem item;
  final VoidCallback onRemove;

  const _SavedCard({required this.item, required this.onRemove});

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
          // Image area
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE5F5),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                  child: Center(
                    child: Icon(item.icon, size: 52, color: _C.purpleMid),
                  ),
                ),
                // Remove (unsave) button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x22000000), blurRadius: 4),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 11,
                      color: _C.muted,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        item.shop,
                        style: const TextStyle(color: _C.muted, fontSize: 10.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.price,
                      style: const TextStyle(
                        color: _C.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _C.purpleDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Add to Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

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
              Icons.favorite_border_rounded,
              size: 52,
              color: _C.purpleMid,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No saved items yet',
            style: TextStyle(
              color: _C.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the heart on any product to save it here.',
            style: TextStyle(color: _C.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
