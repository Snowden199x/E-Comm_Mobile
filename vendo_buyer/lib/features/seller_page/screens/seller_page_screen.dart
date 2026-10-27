import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const headerTop = Color(0xFF3B1F52);
  static const headerBot = Color(0xFF2A1440);
  static const orange = Color(0xFFE8873A);
  static const purpleDark = Color(0xFF2D1B3D);
  static const purpleMid = Color(0xFF7B2FBE);
  static const lilac = Color(0xFFEDE5F5);
  static const bg = Color(0xFFF4F1F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF888888);
  static const border = Color(0xFFECE6EA);
  static const star = Color(0xFFFFC107);
  static const gold = Color(0xFFC9923A);
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder product model (replace with real data later)
// ─────────────────────────────────────────────────────────────────────────────
class _SP {
  final String title;
  final String price;
  final String sold;
  final IconData icon;
  final double rating;
  final String? discount;
  final bool deal;
  final String? strip;

  const _SP({
    required this.title,
    required this.price,
    required this.sold,
    required this.icon,
    this.rating = 4.9,
    this.discount,
    this.deal = false,
    this.strip,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Seller Page Screen
// ─────────────────────────────────────────────────────────────────────────────
class SellerPageScreen extends StatefulWidget {
  const SellerPageScreen({super.key});

  @override
  State<SellerPageScreen> createState() => _SellerPageScreenState();
}

class _SellerPageScreenState extends State<SellerPageScreen> {
  final ScrollController _scroll = ScrollController();
  bool _showTop = false;
  bool _following = false;
  int _tab = 0;

  // ── Sample data ──────────────────────────────────────────────────────────
  static const _featured = <_SP>[
    _SP(
      title: 'Wireless Earbuds Bluetooth 5.3 Original Set of 2',
      price: '320',
      sold: '1K+ sold',
      icon: Icons.headphones,
      discount: '-11%',
      deal: true,
      strip: 'Set of 2',
    ),
    _SP(
      title: 'Wireless Earbuds Bluetooth 5.3 Sport Variant',
      price: '320',
      sold: '899 sold',
      icon: Icons.headset_mic_outlined,
      discount: '-11%',
      strip: 'Sport',
    ),
  ];

  static const _highest = <_SP>[
    _SP(
      title: 'Smart Watch Waterproof Fitness Tracker',
      price: '615',
      sold: '5K+ sold',
      icon: Icons.watch,
      discount: '-10%',
    ),
    _SP(
      title: 'Travel Backpack Large Capacity',
      price: '9',
      sold: '8K+ sold',
      icon: Icons.backpack,
      discount: '-72%',
    ),
    _SP(
      title: 'Basketball Official Size Indoor Outdoor',
      price: '17',
      sold: '2K+ sold',
      icon: Icons.sports_basketball,
      discount: '-70%',
    ),
  ];

  static const _top = <_SP>[
    _SP(
      title: 'Coffee Maker Automatic Drip Machine',
      price: '9',
      sold: '740 Sold/Month',
      icon: Icons.coffee,
    ),
    _SP(
      title: 'Women\'s Sneakers Comfortable Casual Shoes',
      price: '8',
      sold: '330 Sold/Month',
      icon: Icons.do_not_step,
    ),
    _SP(
      title: 'Smart Watch Waterproof Fitness Tracker',
      price: '141',
      sold: '210 Sold/Month',
      icon: Icons.watch,
    ),
  ];

  static const _forYou = <_SP>[
    _SP(
      title: 'Wireless Earbuds Chocolate Edition 3 pcs',
      price: '9',
      sold: '1K+ sold',
      icon: Icons.headphones,
      discount: '-71%',
      rating: 4.8,
    ),
    _SP(
      title: 'Travel Backpack Water Resistant 6 Sheets',
      price: '124',
      sold: '3K+ sold',
      icon: Icons.backpack,
      discount: '-24%',
    ),
    _SP(
      title: 'Basketball Blushy Pink 25g Indoor Outdoor',
      price: '7',
      sold: '206 sold',
      icon: Icons.sports_basketball,
      discount: '-71%',
      rating: 5.0,
    ),
    _SP(
      title: 'Coffee Maker Mini Petroleum 25g Compact',
      price: '14',
      sold: '936 sold',
      icon: Icons.coffee,
      discount: '-71%',
    ),
    _SP(
      title: 'Women\'s Sneakers Casual Everyday Wear',
      price: '199',
      sold: '4K+ sold',
      icon: Icons.do_not_step,
      discount: '-33%',
      rating: 4.7,
    ),
    _SP(
      title: 'Smart Watch Fitness Tracker Black Edition',
      price: '349',
      sold: '1K+ sold',
      icon: Icons.watch,
      discount: '-18%',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 700;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Hook this up to your product detail screen.
  // Example (fix the import path first):
  //   Navigator.push(context, MaterialPageRoute(
  //     builder: (_) => ProductDetailScreen(
  //       product: ProductData(
  //         title: p.title, price: p.price, sold: p.sold,
  //         delivery: '1-3 Days', location: 'Manila', icon: p.icon,
  //         discount: p.discount,
  //       ),
  //     ),
  //   ));
  void _openProduct(_SP p) {}

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _ShopHeaderDelegate(
                  topPad: topPad,
                  tab: _tab,
                  following: _following,
                  onTab: (i) => setState(() => _tab = i),
                  onFollow: () => setState(() => _following = !_following),
                ),
              ),
              SliverToBoxAdapter(child: _buildBody()),
            ],
          ),

          // Scroll-to-top button
          if (_showTop)
            Positioned(
              right: 14,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: GestureDetector(
                onTap: () => _scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _C.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.border),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 8),
                    ],
                  ),
                  child: const Icon(
                    Icons.vertical_align_top_rounded,
                    color: _C.orange,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Body (switches by tab)
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final bottom = MediaQuery.of(context).padding.bottom;

    switch (_tab) {
      case 0:
        return Padding(
          padding: EdgeInsets.only(top: 10, bottom: 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeatured(),
              _buildHighestSales(),
              _buildTopProducts(),
              _buildPromoBanner(),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  'Just For You',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _grid(_forYou),
            ],
          ),
        );
      case 1:
        final all = [..._forYou, ..._highest, ..._featured];
        return Padding(
          padding: EdgeInsets.fromLTRB(0, 12, 0, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  '${all.length} products',
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _grid(all),
            ],
          ),
        );
      case 2:
        return _placeholder(Icons.rate_review_outlined, 'Reviews');
      default:
        return _placeholder(Icons.grid_view_rounded, 'Categories');
    }
  }

  Widget _placeholder(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 14),
            Text(
              '$title coming soon',
              style: const TextStyle(
                color: _C.muted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<_SP> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (_, i) =>
            _GridCard(p: items[i], onTap: () => _openProduct(items[i])),
      ),
    );
  }

  // ── Featured collection (2 big cards) ───────────────────────────────────
  Widget _buildFeatured() {
    return _SectionCard(
      title: 'BEST SELLERS COLLECTION',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _featured.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _BigCard(
                p: _featured[i],
                onTap: () => _openProduct(_featured[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Highest sales (3 mini cards) ────────────────────────────────────────
  Widget _buildHighestSales() {
    return _SectionCard(
      title: 'Highest Sales',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _highest.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _MiniCard(
                p: _highest[i],
                onTap: () => _openProduct(_highest[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Top products (horizontal list with TOP ribbons) ─────────────────────
  Widget _buildTopProducts() {
    return _SectionCard(
      title: 'Top Products',
      trailing: GestureDetector(
        onTap: () {},
        child: const Row(
          children: [
            Text(
              'See More',
              style: TextStyle(
                color: _C.orange,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(Icons.chevron_right, color: _C.orange, size: 20),
          ],
        ),
      ),
      child: SizedBox(
        height: 235,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _top.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _TopCard(
            rank: i + 1,
            p: _top[i],
            onTap: () => _openProduct(_top[i]),
          ),
        ),
      ),
    );
  }

  // ── Promo banner ────────────────────────────────────────────────────────
  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A2468), Color(0xFF2A1440)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 130, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(height: 10),
                const Text(
                  'Find all your\nneeds here!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Shop favorites from our\nofficial store.',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _C.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Shop Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
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
// Collapsing header: banner + shop info + tabs → compact tab bar
// ─────────────────────────────────────────────────────────────────────────────
class _ShopHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPad;
  final int tab;
  final bool following;
  final ValueChanged<int> onTab;
  final VoidCallback onFollow;

  const _ShopHeaderDelegate({
    required this.topPad,
    required this.tab,
    required this.following,
    required this.onTab,
    required this.onFollow,
  });

  static const _tabs = ['Shop', 'Products', 'Reviews', 'Categories'];
  static const double _bannerH = 236;
  static const double _tabsH = 50;
  static const double _compactH = 56;

  @override
  double get maxExtent => topPad + _bannerH + _tabsH;
  @override
  double get minExtent => topPad + _compactH;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final fade = 1 - t;
    final iconColor = Color.lerp(Colors.white, _C.purpleDark, t)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t > 0.5 ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          // Banner background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_C.headerTop, _C.headerBot],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -50,
                    top: -30,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    bottom: 40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // White background when collapsed
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(opacity: t, child: Container(color: _C.white)),
            ),
          ),

          // Banner content (shop info, perks, chat bar)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: t > 0.5,
              child: Opacity(
                opacity: fade,
                child: Stack(
                  children: [
                    // Search pill
                    Positioned(
                      top: topPad + 8,
                      left: 56,
                      right: 56,
                      height: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Search in shop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Shop info row
                    Positioned(
                      top: topPad + 58,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _C.orange,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Center(
                                  child: Text(
                                    'v',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                    ),
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
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Official Vendo Store',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: _C.star,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      '4.9',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '13.3K Followers',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onFollow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: following
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white),
                              ),
                              child: Text(
                                following ? 'Following' : '+ Follow',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Perks strip
                    Positioned(
                      top: topPad + 128,
                      left: 14,
                      right: 14,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _C.orange.withValues(alpha: 0.7),
                          ),
                        ),
                        child: const Row(
                          children: [
                            _PerkItem('FREE\nSHIPPING', _C.orange),
                            _PerkItem('AUTHENTIC\nPRODUCTS', Colors.white),
                            _PerkItem('COD\nAVAILABLE', _C.orange),
                          ],
                        ),
                      ),
                    ),
                    // Chat with seller
                    Positioned(
                      top: topPad + 176,
                      left: 14,
                      right: 14,
                      height: 44,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Chat with Seller',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tabs row (sticks to the bottom, becomes the compact bar)
          Positioned(
            bottom: 0,
            height: _tabsH,
            left: lerpDouble(0, 48, t)!,
            right: lerpDouble(0, 128, t)!,
            child: Container(
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(lerpDouble(16, 0, t)!),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _tabs.length,
                itemBuilder: (_, i) {
                  final on = i == tab;
                  return GestureDetector(
                    onTap: () => onTab(i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Center(
                            child: Text(
                              _tabs[i],
                              style: TextStyle(
                                color: on ? _C.orange : _C.ink,
                                fontSize: 15.5,
                                fontWeight: on
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Container(
                            height: 3,
                            color: on ? _C.orange : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Back button (always visible)
          Positioned(
            top: topPad + 8,
            left: 8,
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: iconColor,
                  size: 26,
                ),
              ),
            ),
          ),

          // Right icons (search + chat fade in when collapsed)
          Positioned(
            top: topPad + 8,
            right: 8,
            child: Row(
              children: [
                IgnorePointer(
                  ignoring: t < 0.5,
                  child: Opacity(
                    opacity: t,
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.search, color: iconColor, size: 25),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: t < 0.5,
                  child: Opacity(
                    opacity: t,
                    child: GestureDetector(
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: iconColor,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.more_horiz, color: iconColor, size: 26),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ShopHeaderDelegate old) =>
      old.topPad != topPad || old.tab != tab || old.following != following;
}

class _PerkItem extends StatelessWidget {
  final String text;
  final Color color;
  const _PerkItem(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small pieces
// ─────────────────────────────────────────────────────────────────────────────
class _Price extends StatelessWidget {
  final String price;
  final double big;
  const _Price(this.price, {required this.big});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '₱', style: TextStyle(fontSize: big * 0.62)),
          TextSpan(text: price, style: TextStyle(fontSize: big)),
        ],
      ),
      style: const TextStyle(color: _C.orange, fontWeight: FontWeight.bold),
    );
  }
}

class _VoucherIcon extends StatelessWidget {
  const _VoucherIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.confirmation_number_outlined,
      size: 16,
      color: _C.orange,
    );
  }
}

class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip(this.rating);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFD27A)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: _C.star),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(color: _C.ink, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _DealChip extends StatelessWidget {
  const _DealChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: _C.purpleMid,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thumb_up_alt, size: 11, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'Vendo Deal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Product image block: placeholder icon, discount badge, COD strip.
class _Img extends StatelessWidget {
  final _SP p;
  final bool band;
  final double iconSize;

  const _Img({required this.p, this.band = false, this.iconSize = 56});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          color: _C.lilac,
          child: Center(
            child: Icon(p.icon, size: iconSize, color: _C.purpleMid),
          ),
        ),
        if (p.discount != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: const BoxDecoration(
                color: _C.orange,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8)),
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
        if (band)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xCC2D1B3D),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: _C.orange,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'COD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (p.strip != null)
                    Text(
                      p.strip!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Big card  (featured collection)
// ─────────────────────────────────────────────────────────────────────────────
class _BigCard extends StatelessWidget {
  final _SP p;
  final VoidCallback onTap;
  const _BigCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1, child: _Img(p: p, band: true)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 36,
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (p.deal) ...[
                        const _DealChip(),
                        const SizedBox(width: 6),
                      ],
                      _RatingChip(p.rating),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _Price(p.price, big: 18),
                      const SizedBox(width: 4),
                      const _VoucherIcon(),
                      const Spacer(),
                      Text(
                        p.sold,
                        style: const TextStyle(color: _C.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini card  (highest sales)
// ─────────────────────────────────────────────────────────────────────────────
class _MiniCard extends StatelessWidget {
  final _SP p;
  final VoidCallback onTap;
  const _MiniCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _Img(p: p, iconSize: 40),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34,
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Flexible(child: _Price(p.price, big: 16)),
                      const SizedBox(width: 3),
                      const _VoucherIcon(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top card  (TOP 1 / 2 / 3 ribbon)
// ─────────────────────────────────────────────────────────────────────────────
class _TopCard extends StatelessWidget {
  final int rank;
  final _SP p;
  final VoidCallback onTap;
  const _TopCard({required this.rank, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: Stack(
                children: [
                  Positioned.fill(child: _Img(p: p, iconSize: 50)),
                  Positioned(
                    top: 0,
                    left: 6,
                    child: Container(
                      width: 30,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: const BoxDecoration(
                        color: _C.gold,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(6),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$rank',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34,
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Price(p.price, big: 16),
                      const SizedBox(width: 3),
                      const _VoucherIcon(),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          p.sold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _C.muted, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid card  (Just For You)
// ─────────────────────────────────────────────────────────────────────────────
class _GridCard extends StatelessWidget {
  final _SP p;
  final VoidCallback onTap;
  const _GridCard({required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Img(p: p, band: true)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34,
                    child: Text(
                      p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Price(p.price, big: 17),
                      const SizedBox(width: 6),
                      if (p.discount != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEFE6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            p.discount!,
                            style: const TextStyle(
                              color: _C.orange,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const _VoucherIcon(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _RatingChip(p.rating),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p.sold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _C.muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}