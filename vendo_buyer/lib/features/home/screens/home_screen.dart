import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/cart/screens/cart_screen.dart';
import 'package:vendo_buyer/features/home/screens/category_products_screen.dart';
import 'package:vendo_buyer/features/home/widgets/buyer_nav_bar.dart';
import 'package:vendo_buyer/features/notifications/screens/notifications_screen.dart';
import 'package:vendo_buyer/features/orders/screens/orders_screen.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';
import 'package:vendo_buyer/features/profile/screens/profile_screen.dart';
import 'package:vendo_buyer/features/saved/screens/saved_screen.dart';
import 'package:vendo_buyer/features/search/screens/search_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo buyer palette (plum + gold)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const plum = Color(0xFF2E1535);
  static const plumDeep = Color(0xFF230E2A);
  static const plumLight = Color(0xFF43214D);
  static const accent = Color(0xFFECC570);
  static const accentHover = Color(0xFFE2B85E);
  static const bg = Color(0xFFF8F6FA);
  static const white = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFECE7F0);
  static const lavenderBg = Color(0xFFF4EFF7);
  static const lavenderMuted = Color(0xFF9B8EA6);
  static const ink = Color(0xFF1F1724);
  static const muted = Color(0xFF6D6475);
  static const hotRed = Color(0xFFB91C1C);
  static const amberText = Color(0xFFB45309);
  static const amberBg = Color(0xFFFFFBEB);
  static const price = Color(0xFF43214D); // purple price text
  static const discountBg = Color(0xFFEADCF2); // soft purple discount badge
  static const strikeGray = Color(0xFF9CA3AF); // original (crossed-out) price
}

/// Home screen — post-login landing. The bottom bar lives in
/// `features/home/widgets/buyer_nav_bar.dart`.
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
        // The page runs behind the floating bar instead of stopping above it,
        // so the bar's translucent background shows the page underneath.
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const _HomeTab(),
            const SavedScreen(),
            // Only the visible tab polls, so a hidden tab stays quiet.
            NotificationsScreen(isActive: _currentIndex == 2),
            const BuyerProfileScreen(),
          ],
        ),
        bottomNavigationBar: BuyerNavBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home tab
// ─────────────────────────────────────────────────────────────────────────────
enum _Filter { all, top }

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<_Product> _products = const [];
  List<_HomeCategory> _categories = const [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHome();
    _loadCartCount();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openSearch() {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: '/search'),
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const SearchResultsScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          // Fade outpaces the slide so the screen is readable while it settles.
          final fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.7, curve: Curves.easeOut),
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Fills the header badge from the server; a failure leaves the last known
  /// count (the badge is decoration, not critical data).
  Future<void> _loadCartCount() async {
    try {
      await BuyerApi.instance.cart();
    } catch (_) {
      // Offline or signed out: keep whatever count the badge already shows.
    }
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BuyerApi.instance.home();
      if (!mounted) return;
      setState(() {
        _products = (data['products'] as List? ?? [])
            .map(
              (e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .map(_Product.fromApi)
            .toList();
        _categories = (data['categories'] as List? ?? [])
            .map(
              (e) => _HomeCategory(
                int.tryParse('${e['id']}') ?? 0,
                '${e['name']}',
              ),
            )
            .toList();
        _loading = false;
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

  List<_Product> get _visibleProducts {
    switch (_filter) {
      case _Filter.all:
        return _products;
      case _Filter.top:
        // No rating field on the home feed yet, so "Top Rated" ranks by sales.
        final sorted = [..._products]
          ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
        return sorted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProducts;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status bar icons because the header is now light
      value: SystemUiOverlayStyle.dark,
      child: CustomScrollView(
        // Stable identity keeps hot reload/rebuilds from swapping this
        // Scrollable with another one in the same slot.
        key: const PageStorageKey<String>('buyer-home-scroll'),
        controller: _scrollCtrl,
        slivers: [
          // ── Sticky header ─────────────────────────────────────────
          // Expanded: brand row + search bar. As the page scrolls, the search
          // bar fades out and collapses; the brand row stays pinned and a
          // search icon appears before the heart icon.
          SliverPersistentHeader(
            key: const ValueKey<String>('buyer-home-header'),
            pinned: true,
            delegate: _HomeHeaderDelegate(
              topPadding: MediaQuery.of(context).padding.top,
              onSearchTap: _openSearch,
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),

                // ── Welcome hero ───────────────────────────────────
                const _HeroBanner(),

                const SizedBox(height: 12),

                // ── Quick-action pills ─────────────────────────────
                const _QuickActions(),

                const SizedBox(height: 12),

                // ── Shop by category ───────────────────────────────
                if (_loading)
                  const _CategorySkeleton()
                else
                  _CategoryCard(categories: _categories),

                const SizedBox(height: 16),

                // ── Filter chips ───────────────────────────────────
                _FilterChips(
                  selected: _filter,
                  categories: _categories.take(4).toList(),
                  onSelect: (f) => setState(() => _filter = f),
                ),

                const SizedBox(height: 14),

                // ── Recommended for you ────────────────────────────
                _SectionHeader(
                  title: 'Recommended for you',
                  subtitle: 'Fresh verified picks tailored to your style',
                  actionLabel: 'View all',
                  onAction: () {},
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const _ProductGridSkeleton()
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _loadHome,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.plum,
                            side: const BorderSide(color: _C.plum),
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No products are available yet.',
                        style: const TextStyle(color: _C.muted, fontSize: 12.5),
                      ),
                    ),
                  )
                else ...[
                  _ProductGrid(products: visible),
                  const SizedBox(height: 18),
                  const _SeeMoreButton(),
                ],

                // Clearance so the last row can scroll above the floating nav bar.
                SizedBox(
                  height:
                      32 +
                      kBuyerNavBarClearance +
                      MediaQuery.of(context).padding.bottom,
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
// Collapsing header delegate
//   expanded  : brand row (logo + icons) and the search bar
//   collapsed : brand row only, with a search icon before the heart icon
// ─────────────────────────────────────────────────────────────────────────────
class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final VoidCallback onSearchTap;

  const _HomeHeaderDelegate({
    required this.topPadding,
    required this.onSearchTap,
  });

  static const double _vPad = 12;
  static const double _rowHeight = 36;
  static const double _gap = 8;
  static const double _searchHeight = 40;

  @override
  double get minExtent => topPadding + _vPad + _rowHeight + _vPad;

  @override
  double get maxExtent => minExtent + _gap + _searchHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final progress = (shrinkOffset / range).clamp(0.0, 1.0);
    return _HomeHeader(
      topPadding: topPadding,
      onSearchTap: onSearchTap,
      progress: progress,
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      topPadding != oldDelegate.topPadding ||
      onSearchTap != oldDelegate.onSearchTap;
}

/// [progress] goes from 0 (fully expanded, search bar visible) to 1 (fully
/// collapsed, only the brand row with the search icon).
class _HomeHeader extends StatefulWidget {
  final double topPadding;
  final VoidCallback onSearchTap;
  final double progress;

  const _HomeHeader({
    required this.topPadding,
    required this.onSearchTap,
    required this.progress,
  });

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader>
    with SingleTickerProviderStateMixin {
  // Drives the slow back-and-forth movement of the gradient.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = widget.topPadding;
    final onSearchTap = widget.onSearchTap;
    final progress = widget.progress;

    // The search bar fades out quickly (gone by ~60% of the collapse), and the
    // header search icon fades in as the bar disappears.
    final searchBarOpacity = (1 - progress * 1.6).clamp(0.0, 1.0);
    final searchIconT = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);

    const rowTopOffset = _HomeHeaderDelegate._vPad;
    const rowHeight = _HomeHeaderDelegate._rowHeight;
    const gap = _HomeHeaderDelegate._gap;
    const searchHeight = _HomeHeaderDelegate._searchHeight;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          decoration: BoxDecoration(
            // Lavender and warm gold tint (plum + gold theme) that slowly slides
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -0.5),
              end: Alignment(1 + 2 * t, 0.5),
              tileMode: TileMode.mirror,
              colors: const [
                Color(0xFFEADCF2),
                Color(0xFFF6EEF9),
                Color(0xFFFBEFD0),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A2E1535),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          // Children are positioned by hand so the content never overflows
          // while the header shrinks; whatever sticks out is clipped.
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Brand row: logo + icons (always visible) ────────
              Positioned(
                left: 16,
                right: 16,
                top: topPadding + rowTopOffset,
                height: rowHeight,
                child: Row(
                  children: [
                    const _BrandLogo(),
                    const Spacer(),
                    // ── Search icon (appears once the search bar is gone) ──
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: searchIconT,
                        child: IgnorePointer(
                          ignoring: searchIconT < 0.5,
                          child: Opacity(
                            opacity: searchIconT,
                            child: _HeaderIcon(
                              icon: Icons.search_rounded,
                              tooltip: 'Search',
                              onTap: onSearchTap,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── Saved (same screen as the "Saved items" pill) ──
                    _HeaderIcon(
                      icon: Icons.favorite_border_rounded,
                      tooltip: 'Saved items',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedScreen(),
                          ),
                        );
                      },
                    ),
                    // ── Chat ───────────────────────────────────────────
                    _HeaderIcon(
                      icon: Icons.chat_bubble_outline_rounded,
                      tooltip: 'Messages',
                      onTap: () {},
                    ),
                    // ── Cart (badge mirrors the live cart count) ───────
                    ValueListenableBuilder<int>(
                      valueListenable: BuyerApi.cartItemCount,
                      builder: (context, count, _) => _HeaderIcon(
                        icon: Icons.shopping_cart_outlined,
                        tooltip: 'Cart',
                        badge: '$count',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search bar (fades out while scrolling up) ───────
              Positioned(
                left: 16,
                right: 16,
                top: topPadding + rowTopOffset + rowHeight + gap,
                height: searchHeight,
                child: IgnorePointer(
                  ignoring: searchBarOpacity < 0.5,
                  child: Opacity(
                    opacity: searchBarOpacity,
                    child: _SearchBar(onTap: onSearchTap),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Vendo logo image + "vendo" wordmark
class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vendo app logo (assets/images/vendo_app_logo.png)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/vendo_app_logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'vendo',
          style: TextStyle(
            color: _C.plum,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final String? badge;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: _C.plum, size: 20),
              if (badge != null)
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _C.accent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: _C.plum,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1,
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
}

/// Pill search bar. It opens the search page, where typing searches products
/// and shops live; keeping text input off the pinned header also keeps the
/// Home sliver's element tree stable while the keyboard opens and on reload.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search products or shops',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            // Thin dark purple outline
            border: Border.all(color: _C.plum, width: 1),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: _C.plum.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search products or shops...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: _C.plum.withValues(alpha: 0.6),
                  size: 18,
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
// Welcome hero banner (plum card, gold CTA, shopping-bag illustration)
// ─────────────────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _C.plum,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Soft circle, bottom right
            Positioned(
              right: -32,
              bottom: -40,
              child: Container(
                width: 176,
                height: 176,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Gold dot, top right
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.accent.withValues(alpha: 0.8),
                ),
              ),
            ),
            // Shopping illustration
            const Positioned(
              right: -12,
              bottom: -4,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.9,
                  child: SizedBox(
                    width: 144,
                    height: 144,
                    child: CustomPaint(painter: _HeroIllustrationPainter()),
                  ),
                ),
              ),
            ),
            // Text + buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome to Vendo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      'Shop your favorites from approved sellers and get them delivered to your door.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _C.accent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Shop now',
                              style: TextStyle(
                                color: _C.plum,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: _C.plum,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        child: const Text(
                          'Browse categories',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

/// Gold shopping bag + lavender gift box (drawn in code, no image asset).
class _HeroIllustrationPainter extends CustomPainter {
  const _HeroIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 160);

    // Soft backdrop arc
    canvas.drawPath(
      Path()
        ..moveTo(130, 55)
        ..cubicTo(155, 85, 155, 125, 130, 155),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    // Gold shopping bag
    canvas.save();
    canvas.translate(60, 42);
    canvas.drawPath(
      Path()
        ..moveTo(22, 0)
        ..cubicTo(22, -14, 48, -14, 48, 0),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 8, 70, 74),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFF4D086),
    );
    final ribbon = Paint()..color = const Color(0xFFE8BD65);
    canvas.drawRect(const Rect.fromLTWH(29, 8, 12, 74), ribbon);
    canvas.drawRect(const Rect.fromLTWH(0, 32, 70, 10), ribbon);
    canvas.restore();

    // Lavender gift box in front
    canvas.save();
    canvas.translate(26, 75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 48, 48),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFD3BEDE),
    );
    final boxRibbon = Paint()..color = const Color(0xFFBCA3C8);
    canvas.drawRect(const Rect.fromLTWH(18, 0, 10, 48), boxRibbon);
    canvas.drawRect(const Rect.fromLTWH(0, 18, 48, 10), boxRibbon);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-action pills (scroll sideways)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = <_QuickAction>[
    _QuickAction(Icons.shopping_bag_outlined, 'Track orders'),
    _QuickAction(Icons.favorite_border_rounded, 'Saved items'),
    _QuickAction(Icons.credit_card_rounded, 'Cash on Delivery'),
    _QuickAction(Icons.location_on_outlined, 'Live status'),
    _QuickAction(Icons.verified_user_outlined, 'Approved sellers'),
    _QuickAction(Icons.chat_bubble_outline_rounded, 'Seller chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _QuickActionTile(action: _actions[i]),
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

  void _open(BuildContext context) {
    switch (action.label) {
      case 'Track orders':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersScreen()),
        );
      case 'Saved items':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: _C.lavenderBg,
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: _C.plum, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              action.label,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 12,
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
// Section header (title, optional subtitle, optional action link)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.subtitle,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: _C.muted, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      color: _C.plum,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _C.plum,
                    size: 16,
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
// Shop by category: white card with a sideways row of round icons (no labels)
// ─────────────────────────────────────────────────────────────────────────────
/// Top-level categories from `GET /api/v1/buyer/home`.
class _HomeCategory {
  final int id;
  final String name;
  const _HomeCategory(this.id, this.name);
}

class _CategoryCard extends StatelessWidget {
  final List<_HomeCategory> categories;
  const _CategoryCard({required this.categories});

  static const _icons = <String, IconData>{
    'Electronics and Gadgets': Icons.devices_outlined,
    "Women's Apparel": Icons.checkroom_outlined,
    "Men's Apparel": Icons.man_outlined,
    'Kids and Baby': Icons.child_care_outlined,
    'Home and Garden': Icons.home_outlined,
    'Sports and Outdoors': Icons.sports_basketball_outlined,
    'Health and Beauty': Icons.spa_outlined,
    'Makeup & Cosmetics': Icons.brush_outlined,
    'Books and Media': Icons.menu_book_outlined,
    'Food and Gourmet': Icons.restaurant_outlined,
    'Automotive & Motorcycle': Icons.two_wheeler_outlined,
    'Furniture and Office Equipment': Icons.chair_outlined,
    'Jewelry and Watches': Icons.watch_outlined,
    'Office and School Supplies': Icons.edit_outlined,
    'Pet Supplies': Icons.pets_outlined,
  };

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Shop by category',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See all',
                        style: TextStyle(
                          color: _C.plum,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _C.plum,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) {
                  final category = categories[i];
                  return _CatTile(
                    cat: _Cat(
                      _icons[category.name] ?? Icons.category_outlined,
                      category.name,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsScreen(
                          categoryId: category.id,
                          title: category.name,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
  final VoidCallback? onTap;
  const _CatTile({required this.cat, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _C.lavenderBg,
          shape: BoxShape.circle,
          border: Border.all(color: _C.cardBorder),
        ),
        child: Icon(cat.icon, color: _C.lavenderMuted, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chips: All Picks / Top Rated + a few categories
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChips extends StatelessWidget {
  final _Filter selected;
  final List<_HomeCategory> categories;
  final ValueChanged<_Filter> onSelect;

  const _FilterChips({
    required this.selected,
    required this.categories,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _C.plum : _C.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: active ? _C.plum : _C.cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _C.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip(
            'All Picks',
            selected == _Filter.all,
            () => onSelect(_Filter.all),
          ),
          const SizedBox(width: 6),
          chip(
            'Top Rated',
            selected == _Filter.top,
            () => onSelect(_Filter.top),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 6),
            chip(
              c.name,
              false,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoryProductsScreen(categoryId: c.id, title: c.name),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product grid: staggered 2 columns (left column starts a little lower)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List<_Product> products;
  const _ProductGrid({required this.products});

  /// Space between the two columns and between cards.
  static const double gap = 6.0;

  /// Rough height of a product card's text area (title, price, store row and
  /// padding). Used only to size the tall banner so it spans two cards; tweak
  /// this if the banner ends a little above or below the second card.
  static const double cardDetailsHeight = 74.0;

  /// Banner height as a multiple of one product card's height
  /// (1.0 = same height as a card, 1.25 = a little bit taller).
  static const double bannerHeightFactor = 1.25;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Same math as the layout below: 8px edges and one gap in the middle.
        final columnWidth = (constraints.maxWidth - 16 - gap) / 2;
        final bannerHeight =
            bannerHeightFactor * (columnWidth + cardDetailsHeight);

        final left = <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: SizedBox(
              height: bannerHeight,
              child: const _TallBannerCarousel(),
            ),
          ),
        ];
        final right = <Widget>[];

        // The banner counts as `bannerHeightFactor` cards in the left column;
        // each product goes to the shorter column so the bottoms stay close.
        var leftWeight = bannerHeightFactor;
        var rightWeight = 0.0;
        for (final product in products) {
          final card = Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: _ProductCard(product: product),
          );
          if (rightWeight < leftWeight) {
            right.add(card);
            rightWeight += 1;
          } else {
            left.add(card);
            leftWeight += 1;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8), // left/right edge
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: gap),
              Expanded(child: Column(children: right)),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tall banner carousel (top of the left column). Slides every 4.5 seconds.
// ─────────────────────────────────────────────────────────────────────────────
class _TallBannerCarousel extends StatefulWidget {
  /// Put your real banner widgets here later. While this is null or empty,
  /// three empty placeholder slides are shown.
  final List<Widget>? slides;

  const _TallBannerCarousel({this.slides});

  @override
  State<_TallBannerCarousel> createState() => _TallBannerCarouselState();
}

class _TallBannerCarouselState extends State<_TallBannerCarousel> {
  static const _autoSlideInterval = Duration(milliseconds: 4500);
  static const _slideDuration = Duration(milliseconds: 450);

  final PageController _pageCtrl = PageController();
  Timer? _timer;
  int _page = 0;
  bool _autoSliding = false;

  static const _placeholderGradients = <List<Color>>[
    [Color(0xFFEADCF2), Color(0xFFF6EEF9)],
    [Color(0xFFFBEFD0), Color(0xFFF6EEF9)],
    [Color(0xFFD3BEDE), Color(0xFFEADCF2)],
  ];

  List<Widget> get _slides {
    final given = widget.slides;
    if (given != null && given.isNotEmpty) return given;
    return [
      for (final colors in _placeholderGradients)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 36,
              color: _C.lavenderMuted.withValues(alpha: 0.6),
            ),
          ),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _TallBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimer();
  }

  /// One timer, only while there is more than one slide.
  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    if (_slides.length > 1) {
      _timer = Timer.periodic(_autoSlideInterval, (_) => _showNext());
    }
  }

  void _showNext() {
    if (!mounted || !_pageCtrl.hasClients) return;
    _autoSliding = true;
    _pageCtrl
        .nextPage(duration: _slideDuration, curve: Curves.easeInOut)
        .whenComplete(() => _autoSliding = false);
  }

  /// A shopper's swipe restarts the countdown so the slide stays readable.
  void _onPageChanged(int index) {
    setState(() => _page = index);
    if (_autoSliding) return;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    final count = slides.length;
    final active = _page % count;

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageCtrl,
              // Endless forward sliding; a single slide stays put.
              itemCount: count > 1 ? null : 1,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => slides[i % count],
            ),
          ),
          if (count > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  count,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: index == active ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: index == active
                          ? _C.plum
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Product {
  final int id;
  final String image;

  /// Nullable because a hot reload leaves the new field empty on view models
  /// that were built before it existed; readers treat that as "no photos".
  final List<String>? images;
  final String title, price, sold, delivery, location;
  final String province, municipality;
  final IconData icon;
  final String? discount; // e.g. '-84%'
  final int discountPercent;
  final int soldCount;

  /// Price before the discount (same formatting as [price]); null when the
  /// product is not discounted.
  final String? originalPrice;

  const _Product({
    required this.title,
    required this.price,
    required this.sold,
    required this.delivery,
    required this.location,
    required this.icon,
    this.province = '',
    this.municipality = '',
    this.id = 0,
    this.image = '',
    this.images = const [],
    this.discount,
    this.discountPercent = 0,
    this.soldCount = 0,
    this.originalPrice,
  });

  /// Maps a live API product card to this view model (the price arrives with the ₱ sign).
  factory _Product.fromApi(ApiProduct product) => _Product(
    id: product.id,
    image: product.image,
    images: product.images,
    title: product.name,
    price: product.price.replaceFirst('₱', ''),
    sold: product.sold > 0 ? '${product.sold} sold' : 'New arrival',
    delivery: 'COD',
    location: product.shop,
    province: product.province,
    municipality: product.municipality,
    icon: Icons.shopping_bag_outlined,
    discount: product.discountPercent > 0
        ? '-${product.discountPercent}%'
        : null,
    discountPercent: product.discountPercent,
    soldCount: product.sold,
    // Prefer the real original price from the API (same value the web shows);
    // fall back to deriving it from the discount percent.
    originalPrice:
        product.compareAtPrice?.replaceFirst('₱', '') ??
        _originalPriceOf(
          product.price.replaceFirst('₱', ''),
          product.discountPercent,
        ),
  );
}

/// Works backwards from the discounted price and the discount % to get the
/// original price, keeping the same comma/decimal formatting.
/// If your API returns the real original price, use that in `fromApi` instead.
String? _originalPriceOf(String price, int percent) {
  if (percent <= 0 || percent >= 100) return null;
  final current = double.tryParse(price.replaceAll(',', ''));
  if (current == null) return null;
  final original = current / (1 - percent / 100);
  final text = original.toStringAsFixed(price.contains('.') ? 2 : 0);
  final parts = text.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}

class _ProductCard extends StatefulWidget {
  final _Product product;
  const _ProductCard({required this.product});

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  /// A card with several photos cycles through them on its own.
  static const _autoSlideInterval = Duration(milliseconds: 4500);
  static const _slideDuration = Duration(milliseconds: 450);

  bool _liked = false;
  int _imageIndex = 0;
  bool _autoSliding = false;
  Timer? _slideTimer;
  final PageController _pageCtrl = PageController();

  /// Photos shown on the card: every product photo, or the single cover image.
  List<String> get _photos {
    final photos = (widget.product.images ?? const <String>[])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    return photos.isNotEmpty ? photos : [widget.product.image];
  }

  @override
  void initState() {
    super.initState();
    _syncAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAutoSlide();
  }

  /// Keeps one timer per card, and only while there is more than one photo.
  void _syncAutoSlide() {
    if (_photos.length > 1) {
      _slideTimer ??= Timer.periodic(_autoSlideInterval, (_) => _showNext());
    } else {
      _slideTimer?.cancel();
      _slideTimer = null;
    }
    if (_imageIndex >= _photos.length) {
      _imageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
      });
    }
  }

  void _showNext() {
    if (!mounted || !_pageCtrl.hasClients) return;
    final count = _photos.length;
    if (count < 2) return;
    _autoSliding = true;
    _pageCtrl
        .animateToPage(
          (_imageIndex + 1) % count,
          duration: _slideDuration,
          curve: Curves.easeInOut,
        )
        .whenComplete(() => _autoSliding = false);
  }

  /// A shopper's swipe restarts the countdown so the next photo stays readable.
  void _onPageChanged(int index) {
    setState(() => _imageIndex = index);
    if (_autoSliding) return;
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(_autoSlideInterval, (_) => _showNext());
  }

  Widget _photo(String url) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => Container(
      color: _C.lavenderBg,
      child: Center(
        child: Icon(widget.product.icon, size: 40, color: _C.lavenderMuted),
      ),
    ),
  );

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApiProductScreen(productId: p.id, title: p.title),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _C.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Square image ─────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _photos.length > 1
                          ? PageView.builder(
                              controller: _pageCtrl,
                              itemCount: _photos.length,
                              onPageChanged: _onPageChanged,
                              itemBuilder: (_, index) => _photo(_photos[index]),
                            )
                          : _photo(_photos.first),
                    ),
                    // Discount badge (top-left, flush to the corner)
                    if (p.discount != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: const BoxDecoration(
                            color: _C.discountBg,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Text(
                            p.discount!,
                            style: const TextStyle(
                              color: _C.plumLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    // Heart (top-right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _liked = !_liked),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: _liked
                                ? Colors.red
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                    // Photo dots (bottom-center) when the card slides
                    if (_photos.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _photos.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: index == _imageIndex ? 12 : 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: index == _imageIndex
                                    ? _C.plum
                                    : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Details ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Price (purple) + crossed-out original price when discounted,
                  // sold count pushed to the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '₱${p.price}',
                                style: const TextStyle(
                                  color: _C.price,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              if (p.originalPrice != null)
                                TextSpan(
                                  text: '  ₱${p.originalPrice}',
                                  style: const TextStyle(
                                    color: _C.strikeGray,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: _C.strikeGray,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p.sold,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _C.muted, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Store name on the left, location flush right on the same line.
                  // The name keeps as much width as it needs; the location gets up to
                  // half the row and is cut with "..." instead of wrapping.
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 12,
                          color: _C.plum.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.location.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (p.province.isNotEmpty ||
                            p.municipality.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.5,
                            ),
                            child: Text(
                              [
                                p.province,
                                p.municipality,
                              ].where((s) => s.isNotEmpty).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: _C.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
// "See more recommendations" outlined pill under the grid
// ─────────────────────────────────────────────────────────────────────────────
class _SeeMoreButton extends StatelessWidget {
  const _SeeMoreButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.plum),
        ),
        child: const Text(
          'See more recommendations',
          style: TextStyle(
            color: _C.plum,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading placeholders (shimmering grey blocks)
// ─────────────────────────────────────────────────────────────────────────────
const Color _kBone = Color(0xFFE9E3EE);
const Color _kBoneHighlight = Color(0xFFF7F3FA);

/// Sweeps a soft highlight across every [_Bone] inside [child].
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [_kBone, _kBoneHighlight, _kBone],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(-1 + 2 * _ctrl.value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double percent;
  const _SlideGradient(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}

/// A single grey placeholder block.
class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _Bone({this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kBone,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.cardBorder),
        ),
        child: _Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Bone(width: 110, height: 14),
                  _Bone(width: 44, height: 12),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, __) =>
                      const _Bone(width: 48, height: 48, radius: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    const gap = _ProductGrid.gap;
    // Same layout as the real grid (tall banner on the left) so nothing jumps
    // when data lands.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - 16 - gap) / 2;
        final bannerHeight =
            _ProductGrid.bannerHeightFactor *
            (columnWidth + _ProductGrid.cardDetailsHeight);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _Shimmer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _Bone(height: bannerHeight),
                      ),
                      const SizedBox(height: gap),
                      const _ProductCardSkeleton(),
                    ],
                  ),
                ),
                const SizedBox(width: gap),
                const Expanded(
                  child: Column(
                    children: [
                      _ProductCardSkeleton(),
                      SizedBox(height: gap),
                      _ProductCardSkeleton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 1,
            child: SizedBox.expand(child: ColoredBox(color: _kBone)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Bone(height: 12),
                SizedBox(height: 6),
                _Bone(width: 56, height: 10),
                SizedBox(height: 8),
                _Bone(width: 80, height: 16),
                SizedBox(height: 8),
                _Bone(width: 96, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}