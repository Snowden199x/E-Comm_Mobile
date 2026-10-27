import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/features/cart/screens/cart_screen.dart';
import 'package:vendo_buyer/features/product/screens/product_detail_screen.dart';
import 'package:vendo_buyer/features/profile/screens/profile_screen.dart';
import 'package:vendo_buyer/features/saved/screens/saved_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo buyer palette
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

/// Home screen — post-login landing with jelly-pill bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            _HomeTab(),
            SavedScreen(),
            _PlaceholderTab(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
            ),
            BuyerProfileScreen(),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder tab
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  const _PlaceholderTab({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 16),
            Text(
              '$title coming soon',
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;

  @override
  void dispose() {
    _bannerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Sticky purple header + search ─────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            topPadding: MediaQuery.of(context).padding.top,
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Quick-action icon strip ──────────────────────────
              _QuickActions(),

              const SizedBox(height: 2),

              // ── Hero banner carousel ─────────────────────────────
              _BannerCarousel(
                ctrl: _bannerCtrl,
                currentPage: _bannerPage,
                onPageChanged: (p) => setState(() => _bannerPage = p),
              ),

              const SizedBox(height: 12),

              // ── Trust badges row ─────────────────────────────────
              _TrustBadges(),

              const SizedBox(height: 16),

              // ── Shop by category ────────────────────────────────
              _SectionHeader(title: 'Shop by Category', onSeeAll: () {}),
              const SizedBox(height: 10),
              _CategoryRow(),

              const SizedBox(height: 20),

              // ── Recommended for you ──────────────────────────────
              _SectionHeader(
                title: 'Recommended for You',
                subtitle: 'Fresh picks from approved shops.',
                onSeeAll: () {},
              ),
              const SizedBox(height: 10),
              _ProductGrid(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky header delegate
// ─────────────────────────────────────────────────────────────────────────────
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;

  const _StickyHeaderDelegate({required this.topPadding});

  // Row height: logo-mark (32) + vertical padding (14*2) = 60
  static const double _rowHeight = 60;

  @override
  double get minExtent => topPadding + _rowHeight;
  @override
  double get maxExtent => topPadding + _rowHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.headerTop, _C.headerBot],
        ),
      ),
      child: Padding(
        // Reserve status-bar space manually so SafeArea doesn't compress us
        padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 10),
        child: Row(
          children: [
            // ── Search bar ─────────────────────────────────────────
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    // Vendo logo mark
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _C.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          'v',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search products, brands…',
                          hintStyle: TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(fontSize: 13.5),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.search,
                        color: Color(0xFF888888),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // ── Cart icon ──────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(
                      color: _C.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Chat icon ──────────────────────────────────────────
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.topPadding != topPadding;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-action icon strip  (below search, above banner)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  static const _actions = <_QuickAction>[
    _QuickAction(Icons.local_shipping_outlined, 'Track Orders'),
    _QuickAction(Icons.favorite_border_rounded, 'Saved Items'),
    _QuickAction(Icons.storefront_outlined, 'Shops'),
    _QuickAction(Icons.redeem_outlined, 'Vouchers'),
    _QuickAction(Icons.headset_mic_outlined, 'Help'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _actions.map((a) => _QuickActionTile(action: a)).toList(),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  const _QuickAction(this.icon, this.label);
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAF8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(action.icon, color: _C.purpleMid, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            style: const TextStyle(
              color: _C.ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner carousel
// ─────────────────────────────────────────────────────────────────────────────
class _BannerCarousel extends StatelessWidget {
  final PageController ctrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _BannerCarousel({
    required this.ctrl,
    required this.currentPage,
    required this.onPageChanged,
  });

  static const _banners = <_Banner>[
    _Banner(
      title: 'Welcome to Vendo',
      subtitle:
          'Shop your favorites from approved\nsellers, delivered to your door.',
      cta: 'Shop Now',
      accent: _C.purpleDark,
    ),
    _Banner(
      title: 'Deals of the Day',
      subtitle: 'Up to 40% off on selected items.\nLimited time offer.',
      cta: 'See Deals',
      accent: Color(0xFFBF3A2B),
    ),
    _Banner(
      title: 'Free Delivery',
      subtitle: 'On your first three orders.\nApproved sellers only.',
      cta: 'Order Now',
      accent: Color(0xFF1A6B3C),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: ctrl,
            itemCount: _banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => _BannerCard(banner: _banners[i]),
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _C.purpleDark : const Color(0xFFCCBBDD),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Banner {
  final String title, subtitle, cta;
  final Color accent;
  const _Banner({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.accent,
  });
}

class _BannerCard extends StatelessWidget {
  final _Banner banner;
  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            banner.accent,
            Color.lerp(banner.accent, Colors.black, 0.35)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Bag icon illustration
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          // Text content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 110, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // "Welcome" chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _C.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'vendo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  banner.subtitle,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _C.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    banner.cta,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Trust badges row  (COD · Track Orders · Approved Sellers · Chat)
// ─────────────────────────────────────────────────────────────────────────────
class _TrustBadges extends StatelessWidget {
  static const _badges = <_TrustBadge>[
    _TrustBadge(Icons.payments_outlined, 'Cash on\nDelivery'),
    _TrustBadge(Icons.location_on_outlined, 'Track Every\nOrder'),
    _TrustBadge(Icons.verified_outlined, 'Approved\nSellers'),
    _TrustBadge(Icons.chat_outlined, 'Chat With\nSellers'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: _badges.map((b) {
          return Expanded(
            child: Column(
              children: [
                Icon(b.icon, color: _C.purpleMid, size: 22),
                const SizedBox(height: 5),
                Text(
                  b.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrustBadge {
  final IconData icon;
  final String label;
  const _TrustBadge(this.icon, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header  (title + optional "See all")
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.subtitle, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: _C.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: const [
                  Text(
                    'See all',
                    style: TextStyle(
                      color: _C.purpleMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: _C.purpleMid, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop by category  — circular icons in a scrollable row
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryRow extends StatelessWidget {
  static const _cats = <_Cat>[
    _Cat(Icons.devices_outlined, 'Electronics\n& Gadgets'),
    _Cat(Icons.checkroom_outlined, "Women's\nApparel"),
    _Cat(Icons.man_outlined, "Men's\nApparel"),
    _Cat(Icons.child_care_outlined, 'Kids and\nBaby'),
    _Cat(Icons.home_outlined, 'Home and\nGarden'),
    _Cat(Icons.sports_basketball_outlined, 'Sports and\nOutdoors'),
    _Cat(Icons.spa_outlined, 'Health and\nBeauty'),
    _Cat(Icons.menu_book_outlined, 'Books and\nMedia'),
    _Cat(Icons.restaurant_outlined, 'Food and\nGourmet'),
    _Cat(Icons.two_wheeler_outlined, 'Automotive\n& Moto'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (_, i) => _CatTile(cat: _cats[i]),
        ),
      ),
    );
  }
}

class _Cat {
  final IconData icon;
  final String label;
  const _Cat(this.icon, this.label);
}

class _CatTile extends StatelessWidget {
  final _Cat cat;
  const _CatTile({required this.cat});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEDE5F5),
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: _C.purpleMid, size: 26),
            ),
            const SizedBox(height: 5),
            Text(
              cat.label,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product grid  — 2-column cards (discount badge, promo tag, sold, delivery)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  static const _products = <_Product>[
    _Product(
      title: 'Wireless Earbuds Bluetooth 5.3 High Quality Sound',
      price: '1,299',
      sold: '10K+ sold',
      delivery: '1-3 Days',
      location: 'Valenzuela City',
      icon: Icons.headphones,
      discount: '-45%',
      promo: '₱50 off Ends in 1 Hour',
      tag: 'Cash on Delivery',
      isLive: true,
    ),
    _Product(
      title: 'Smart Watch Waterproof Fitness Tracker',
      price: '2,499',
      sold: '5K+ sold',
      delivery: '2-4 Days',
      location: 'Quezon City',
      icon: Icons.watch,
      discount: '-30%',
      promo: '₱100 off Ends in 3 Hours',
      tag: 'Cash on Delivery',
    ),
    _Product(
      title: 'Travel Backpack Large Capacity Water Resistant',
      price: '899',
      sold: '8K+ sold',
      delivery: '1-3 Days',
      location: 'Manila',
      icon: Icons.backpack,
      discount: '-52%',
      isLive: true,
    ),
    _Product(
      title: 'Basketball Official Size Indoor Outdoor',
      price: '599',
      sold: '2K+ sold',
      delivery: '3-5 Days',
      location: 'Pasig City',
      icon: Icons.sports_basketball,
      promo: '₱20 off Ends in 2 Hours',
    ),
    _Product(
      title: "Women's Sneakers Comfortable Casual Shoes",
      price: '1,799',
      sold: '6K+ sold',
      delivery: '2-4 Days',
      location: 'Caloocan City',
      icon: Icons.do_not_step,
      discount: '-25%',
      tag: 'Cash on Delivery',
    ),
    _Product(
      title: 'Coffee Maker Automatic Drip Machine',
      price: '3,299',
      sold: '1K+ sold',
      delivery: '1-3 Days',
      location: 'Makati City',
      icon: Icons.coffee,
      discount: '-18%',
      promo: '₱150 off Ends in 5 Hours',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.56,
        ),
        itemBuilder: (_, i) => _ProductCard(product: _products[i]),
      ),
    );
  }
}

class _Product {
  final String title, price, sold, delivery, location;
  final IconData icon;
  final String? discount; // e.g. '-84%'
  final String? promo; // e.g. '₱3 off Ends in 1 Hour'
  final String? tag; // small label at the bottom of the image
  final bool isLive;

  const _Product({
    required this.title,
    required this.price,
    required this.sold,
    required this.delivery,
    required this.location,
    required this.icon,
    this.discount,
    this.promo,
    this.tag,
    this.isLive = false,
  });
}

class _ProductCard extends StatefulWidget {
  final _Product product;
  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _liked = false;

  static const _green = Color(0xFF1A9B5A);

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: ProductData(
              title: p.title,
              price: p.price,
              sold: p.sold,
              delivery: p.delivery,
              location: p.location,
              icon: p.icon,
              discount: p.discount,
              promo: p.promo,
              tag: p.tag,
              isLive: p.isLive,
            ),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image area ───────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFEDE5F5),
                    child: Center(
                      child: Icon(p.icon, size: 56, color: _C.purpleMid),
                    ),
                  ),
                  // Heart (top-left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _liked = !_liked),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x22000000), blurRadius: 4),
                          ],
                        ),
                        child: Icon(
                          _liked ? Icons.favorite : Icons.favorite_border,
                          size: 15,
                          color: _liked ? Colors.red : const Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                  // Discount badge (top-right)
                  if (p.discount != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          color: _C.orange,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          p.discount!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Tag strip (bottom-left of the image)
                  if (p.tag != null)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: const BoxDecoration(
                          color: _C.purpleDark,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          p.tag!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Details ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (with optional LIVE badge)
                  Text.rich(
                    TextSpan(
                      children: [
                        if (p.isLive)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _C.orange,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        TextSpan(text: p.title),
                      ],
                    ),
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Promo tag
                  if (p.promo != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E8),
                        border: Border.all(color: _C.orange, width: 0.8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            size: 11,
                            color: _C.orange,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              p.promo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _C.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Price + sold
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: '₱',
                                style: TextStyle(fontSize: 12),
                              ),
                              TextSpan(
                                text: p.price,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p.sold,
                        style: const TextStyle(color: _C.muted, fontSize: 10.5),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Delivery + location + more
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 13,
                        color: _green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        p.delivery,
                        style: const TextStyle(
                          color: _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: _C.muted,
                      ),
                      Expanded(
                        child: Text(
                          p.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _C.muted, fontSize: 10),
                        ),
                      ),
                      const Icon(Icons.more_horiz, size: 16, color: _C.muted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // Container (child of GestureDetector)
    ); // GestureDetector
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom navigation — "jelly" pill indicator (same design as the Rider app)
// ─────────────────────────────────────────────────────────────────────────────
class _NavColors {
  static const prune = Color(0xFF2D1B3D);
  static const inactive = Color(0xFF8C8290);
  static const shadow = Color(0x1A2D1B3D);
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav>
    with SingleTickerProviderStateMixin {
  static const _pillWidth = 56.0;
  static const _pillHeight = 32.0;
  static const _duration = Duration(milliseconds: 650);
  static const _squash = 0.14;

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.favorite_border_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Saves',
    ),
    _NavItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Notification',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  late final AnimationController _controller;
  late int _fromIndex;

  static final _leadCurve = Interval(0.0, 0.55, curve: Curves.easeOutCubic);
  static final _trailCurve = Interval(0.1, 1.0, curve: ElasticOutCurve(0.8));

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant _BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromIndex = oldWidget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _PillShape _pillShape(double cell) {
    final t = _controller.value;
    final from = _fromIndex;
    final to = widget.currentIndex;

    final fromCenter = cell * (from + 0.5);
    final toCenter = cell * (to + 0.5);
    final half = _pillWidth / 2;

    final movingRight = to >= from;
    final leadT = _leadCurve.transform(t);
    final trailT = _trailCurve.transform(t);

    final leftT = movingRight ? trailT : leadT;
    final rightT = movingRight ? leadT : trailT;

    final left =
        (fromCenter - half) + ((toCenter - half) - (fromCenter - half)) * leftT;
    final right =
        (fromCenter + half) +
        ((toCenter + half) - (fromCenter + half)) * rightT;

    final height = _pillHeight * (1 - _squash * math.sin(math.pi * t));
    final top = (_pillHeight - height) / 2;

    return _PillShape(left: left, right: right, top: top, height: height);
  }

  Color _iconColor(int index, double cell, _PillShape pill) {
    final center = cell * (index + 0.5);
    const iconHalf = 12.0;
    final overlap =
        (math.min(pill.right, center + iconHalf) -
            math.max(pill.left, center - iconHalf)) /
        (iconHalf * 2);
    final amount = overlap.clamp(0.0, 1.0).toDouble();
    return Color.lerp(_NavColors.inactive, Colors.white, amount)!;
  }

  void _onTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: _NavColors.shadow,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / _items.length;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final pill = _pillShape(cell);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: pill.left,
                        top: pill.top,
                        width: math.max(pill.right - pill.left, 0),
                        height: pill.height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _NavColors.prune,
                            borderRadius: BorderRadius.circular(
                              pill.height / 2,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(_items.length, (i) {
                          return Expanded(
                            child: _NavButton(
                              item: _items[i],
                              isActive: i == widget.currentIndex,
                              iconColor: _iconColor(i, cell, pill),
                              iconAreaHeight: _pillHeight,
                              onTap: () => _onTap(i),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PillShape {
  final double left, right, top, height;
  const _PillShape({
    required this.left,
    required this.right,
    required this.top,
    required this.height,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final Color iconColor;
  final double iconAreaHeight;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isActive,
    required this.iconColor,
    required this.iconAreaHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: iconAreaHeight,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    key: ValueKey(isActive),
                    size: 24,
                    color: iconColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _NavColors.prune : _NavColors.inactive,
              ),
              child: Text(item.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
