import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/features/cart/screens/cart_screen.dart';
import 'package:vendo_buyer/features/seller_page/screens/seller_page_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const headerTop = Color(0xFF3B1F52);
  static const orange = Color(0xFFE8873A);
  static const purpleDark = Color(0xFF2D1B3D);
  static const purpleMid = Color(0xFF7B2FBE);
  static const lilac = Color(0xFFEDE5F5);
  static const bg = Color(0xFFF4F1F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF888888);
  static const border = Color(0xFFECE6EA);
  static const green = Color(0xFF1A9B5A);
  static const star = Color(0xFFFFC107);
}

// ─────────────────────────────────────────────────────────────────────────────
// Product data model — passed from the product card
// ─────────────────────────────────────────────────────────────────────────────
class ProductData {
  final String title;
  final String price;
  final String sold;
  final String delivery;
  final String location;
  final IconData icon;
  final String? discount;
  final String? promo;
  final String? tag;
  final bool isLive;

  const ProductData({
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

// ─────────────────────────────────────────────────────────────────────────────
// Small helper models
// ─────────────────────────────────────────────────────────────────────────────
class _Variation {
  final String name;
  final Color color;
  const _Variation(this.name, this.color);
}

class _Review {
  final String author;
  final int stars;
  final String variation;
  final String text;
  final int helpful;
  const _Review(
    this.author,
    this.stars,
    this.variation,
    this.text,
    this.helpful,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProductDetailScreen extends StatefulWidget {
  final ProductData product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const double _heroHeight = 380;

  final ScrollController _scroll = ScrollController();
  double _headerOpacity = 0;
  bool _showTop = false;

  bool _saved = false;
  bool _descExpanded = false;
  int _selectedVar = 0;
  int _cartCount = 0;

  // Placeholder variations
  static const _variations = <_Variation>[
    _Variation('Black', Color(0xFFD9D4DE)),
    _Variation('White', Color(0xFFF3F0F7)),
    _Variation('Pink', Color(0xFFF8C9DD)),
    _Variation('Navy Blue', Color(0xFFBFD3E6)),
    _Variation('Gray', Color(0xFFD5D5D9)),
    _Variation('Purple', Color(0xFFD9C6F2)),
    _Variation('Teal', Color(0xFFBFE6E0)),
    _Variation('Red', Color(0xFFF5C6C0)),
  ];

  // Placeholder reviews
  static const _review = _Review(
    'maria_s123',
    5,
    'Navy Blue',
    'The color looks beautiful and matches the photos shown by the seller. '
        'It arrived well-packaged and in perfect condition. Very happy with it!',
    22,
  );

  // Placeholder "You may also like"
  static const _related = <ProductData>[
    ProductData(
      title: 'Soft Bath Towel for Adult Kids Quick Dry',
      price: '25',
      sold: '10K+ sold',
      delivery: '1-3 Days',
      location: 'San Miguel, Metro Manila',
      icon: Icons.bathtub_outlined,
      discount: '-83%',
      promo: '₱5 off Ends in 2 Hours',
      tag: 'Cash on Delivery',
    ),
    ProductData(
      title: 'Towel Bath Towel Korean Style Coral Velvet',
      price: '9',
      sold: '10K+ sold',
      delivery: '1-2 Days',
      location: 'Meycauayan City',
      icon: Icons.dry_cleaning_outlined,
      discount: '-94%',
      promo: '₱3 off Ends in 1 Hour',
      tag: 'Cash on Delivery',
      isLive: true,
    ),
    ProductData(
      title: 'Men\'s Sando Cotton Sleeveless Undershirt',
      price: '49',
      sold: '8K+ sold',
      delivery: '2-4 Days',
      location: 'Valenzuela City',
      icon: Icons.checkroom_outlined,
      discount: '-90%',
    ),
    ProductData(
      title: 'Microfiber Hand Towels Assorted Colors 3pcs',
      price: '39',
      sold: '3K+ sold',
      delivery: '1-3 Days',
      location: 'Quezon City',
      icon: Icons.layers_outlined,
      discount: '-71%',
      promo: '₱10 off Ends in 4 Hours',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final o = (_scroll.offset / (_heroHeight - 90)).clamp(0.0, 1.0);
    final top = _scroll.offset > 700;
    if (o != _headerOpacity || top != _showTop) {
      setState(() {
        _headerOpacity = o;
        _showTop = top;
      });
    }
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  // ── Variation + quantity bottom sheet ─────────────────────────────────────
  void _openSheet({required bool buyNow}) {
    final p = widget.product;
    int qty = 1;
    int sel = _selectedVar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Container(
            decoration: const BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _variations[sel].color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.border),
                      ),
                      child: Icon(p.icon, size: 36, color: _C.purpleMid),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PriceText(price: p.price, big: 22),
                          const SizedBox(height: 4),
                          Text(
                            'Variation: ${_variations[sel].name}',
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: _C.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Variation',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_variations.length, (i) {
                    final on = sel == i;
                    return GestureDetector(
                      onTap: () => setSheet(() => sel = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: on ? _C.purpleDark : _C.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: on ? _C.purpleDark : _C.border,
                            width: on ? 1.6 : 1,
                          ),
                        ),
                        child: Text(
                          _variations[i].name,
                          style: TextStyle(
                            color: on ? Colors.white : _C.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(
                        color: _C.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: qty > 1 ? () => setSheet(() => qty--) : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () => setSheet(() => qty++),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedVar = sel;
                        if (!buyNow) _cartCount += qty;
                      });
                      if (buyNow) {
                        _openCart();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to cart: ${p.title}'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      buyNow ? 'Buy Now' : 'Add to Cart',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            // ── Scrollable content ─────────────────────────────────
            SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(p),
                  _buildVariations(p),
                  _buildPriceAndTitle(p),
                  const SizedBox(height: 8),
                  _buildInfoRows(p),
                  const SizedBox(height: 8),
                  _buildRatings(),
                  const SizedBox(height: 8),
                  _buildShopReviews(),
                  const SizedBox(height: 8),
                  _buildFeaturedVideos(),
                  const SizedBox(height: 8),
                  _buildShopCard(),
                  const SizedBox(height: 8),
                  _buildDescription(p),
                  const SizedBox(height: 8),
                  _buildYouMayAlsoLike(),
                  SizedBox(height: 90 + bottomInset),
                ],
              ),
            ),

            // ── Floating top bar (fades to purple on scroll) ───────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: _C.headerTop.withValues(alpha: _headerOpacity),
                padding: EdgeInsets.fromLTRB(8, topPad + 6, 8, 6),
                child: Row(
                  children: [
                    _CircleBtn(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _CircleBtn(icon: Icons.share_outlined, onTap: () {}),
                    const SizedBox(width: 8),
                    _CircleBtn(
                      icon: Icons.shopping_cart_outlined,
                      badge: _cartCount > 0 ? '$_cartCount' : null,
                      onTap: _openCart,
                    ),
                    const SizedBox(width: 8),
                    _CircleBtn(icon: Icons.more_vert, onTap: () {}),
                  ],
                ),
              ),
            ),

            // ── Scroll-to-top button ───────────────────────────────
            if (_showTop)
              Positioned(
                right: 12,
                bottom: 80 + bottomInset,
                child: GestureDetector(
                  onTap: () => _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _C.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 6),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: _C.orange,
                      size: 26,
                    ),
                  ),
                ),
              ),

            // ── Sticky bottom action bar ───────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(p, bottomInset),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 1. HERO IMAGE
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildHero(ProductData p) {
    return SizedBox(
      height: _heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDE5F5), Color(0xFFD8CCF0)],
              ),
            ),
            child: Center(child: Icon(p.icon, size: 130, color: _C.purpleMid)),
          ),
          // Play button
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
          // Bottom-left promo strip
          Positioned(
            left: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: _C.purpleDark,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  color: _C.orange,
                  child: const Text(
                    'PAY WHEN IT ARRIVES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Discount badge
          if (p.discount != null)
            Positioned(
              right: 0,
              bottom: 44,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: const BoxDecoration(
                  color: _C.orange,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: Text(
                  p.discount!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Image counter
          Positioned(
            right: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '1/19',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 2. VARIATION THUMBNAILS
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildVariations(ProductData p) {
    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_variations.length} Variations Available',
            style: const TextStyle(color: _C.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _variations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = _selectedVar == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedVar = i),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _variations[i].color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: on ? _C.orange : _C.border,
                        width: on ? 2 : 1,
                      ),
                    ),
                    child: Icon(p.icon, size: 26, color: _C.purpleMid),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 3. PRICE + DEAL TAG + TITLE
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildPriceAndTitle(ProductData p) {
    return Container(
      color: _C.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: _C.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _PriceText(price: p.price, big: 24),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    p.promo != null ? 'After Voucher' : 'Free Shipping',
                    style: const TextStyle(
                      color: _C.purpleMid,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    p.sold.replaceAll(' sold', ' Sold'),
                    style: const TextStyle(color: _C.muted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _saved = !_saved),
                  child: Icon(
                    _saved ? Icons.favorite : Icons.favorite_border,
                    size: 22,
                    color: _saved ? Colors.red : _C.muted,
                  ),
                ),
              ],
            ),
          ),
          // Deal tag row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _C.purpleMid,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.thumb_up_alt, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Vendo Deal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: _C.muted, size: 20),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _C.purpleDark,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'Vendo Verified',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (p.isLive)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _C.orange,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  TextSpan(text: p.title),
                ],
              ),
              style: const TextStyle(
                color: _C.ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 4. DELIVERY / RETURNS / PAYMENT ROWS
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildInfoRows(ProductData p) {
    return Container(
      color: _C.white,
      child: Column(
        children: [
          _NavRow(
            icon: Icons.local_shipping_outlined,
            iconColor: _C.green,
            title: p.delivery,
            subtitle: 'Get up to ₱40 if order arrives late',
          ),
          const Divider(height: 1, color: _C.border),
          _NavRow(
            icon: Icons.location_on_outlined,
            title: 'Ships from ${p.location}',
          ),
          const Divider(height: 1, color: _C.border),
          const _NavRow(
            icon: Icons.verified_user_outlined,
            title: 'Free & Easy Returns',
          ),
          const Divider(height: 1, color: _C.border),
          const _NavRow(
            icon: Icons.payments_outlined,
            title: 'Cash on Delivery: Pay when your order arrives!',
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 5. RATINGS + AI SUMMARY + REVIEW
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildRatings() {
    return Container(
      color: _C.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Best-selling banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF3EAFB), Color(0xFFFFF1E6)],
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 18,
                  color: _C.purpleMid,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No. 1 Best Selling in this category',
                    style: TextStyle(
                      color: _C.purpleMid,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rating header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '4.5',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Icon(Icons.star, size: 17, color: _C.star),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    'Product Ratings (2.8K)',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Icon(Icons.chevron_right, color: _C.muted, size: 20),
                ),
              ],
            ),
          ),
          // AI summary box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'AI-Powered Review Summary',
                        style: TextStyle(
                          color: _C.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.auto_awesome, size: 14, color: _C.muted),
                      SizedBox(width: 4),
                      Icon(Icons.info_outline, size: 14, color: _C.muted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _bullet('Softness', 'Feels gentle on skin even after use.'),
                  const SizedBox(height: 4),
                  _bullet(
                    'Quality',
                    'Looks just like the photos and lasts long.',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _mediaTile(Icons.videocam_outlined, video: true),
                      const SizedBox(width: 6),
                      _mediaTile(Icons.image_outlined, video: true),
                      const SizedBox(width: 6),
                      _mediaTile(Icons.image_outlined, more: '+218'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 20, color: _C.muted),
                  SizedBox(width: 8),
                  Text(
                    'Search What Others Said',
                    style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _C.border),
          // One review
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 11,
                      backgroundColor: _C.lilac,
                      child: Icon(Icons.person, size: 14, color: _C.purpleMid),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _review.author,
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Helpful (${_review.helpful})',
                      style: const TextStyle(color: _C.muted, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.thumb_up_alt_outlined,
                      size: 14,
                      color: _C.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    _review.stars,
                    (_) => const Icon(Icons.star, size: 15, color: _C.star),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Variation: ${_review.variation}',
                  style: const TextStyle(color: _C.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  _review.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _reviewMedia(Icons.videocam_outlined, '0:05'),
                    const SizedBox(width: 6),
                    _reviewMedia(Icons.videocam_outlined, '0:18'),
                    const SizedBox(width: 6),
                    _reviewMedia(Icons.image_outlined, null, extra: '+4'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          InkWell(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(color: _C.ink, fontSize: 13.5),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: _C.muted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String label, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: _C.ink, fontSize: 13)),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
            style: const TextStyle(color: _C.ink, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _mediaTile(IconData icon, {bool video = false, String? more}) {
    return Expanded(
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: _C.lilac,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 30, color: _C.purpleMid),
            if (video)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            if (more != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  more,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewMedia(IconData icon, String? duration, {String? extra}) {
    return Expanded(
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: _C.lilac,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, size: 30, color: _C.purpleMid)),
            Positioned(
              left: 6,
              bottom: 6,
              right: 6,
              child: Row(
                children: [
                  Icon(icon, size: 13, color: _C.ink),
                  const Spacer(),
                  if (duration != null)
                    Text(
                      duration,
                      style: const TextStyle(color: _C.ink, fontSize: 11),
                    ),
                  if (extra != null)
                    Text(
                      extra,
                      style: const TextStyle(color: _C.ink, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 6. OTHER PRODUCT REVIEWS IN SHOP (chips)
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildShopReviews() {
    const chips = [
      'Nice appearance (82)',
      'High quality (60)',
      'Nice suitability (66)',
      'Arrived early (18)',
      'Nice item (25)',
      'Packed well (8)',
    ];
    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Other Product Reviews in Shop',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: _C.muted, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F3FA),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.border),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(color: _C.muted, fontSize: 12.5),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 7. FEATURED VIDEOS
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildFeaturedVideos() {
    const videos = [
      ('Product review and unboxing', Color(0xFFD9C6F2)),
      ('#bestseller #musthave #vendo', Color(0xFFF5C6C0)),
      ('Top quality for a low price', Color(0xFFBFE6E0)),
    ];
    return Container(
      color: _C.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Featured Video',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: _C.muted, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final v = videos[i];
                return Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: v.$2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Text(
                          v.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 8. SHOP CARD + FROM THE SAME SHOP
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildShopCard() {
    final shopItems = <(String, String, IconData)>[
      ('Bath towel cotton thick', '38', Icons.bathtub_outlined),
      ('70x140cm Microfiber', '10', Icons.layers_outlined),
      ('50X100CM Cotton Towel', '32', Icons.dry_cleaning_outlined),
      ('Hand towel soft', '15', Icons.cleaning_services_outlined),
    ];

    return Container(
      color: _C.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _C.lilac,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.border),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: _C.purpleMid,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFFICIAL VENDO STORE',
                        style: TextStyle(
                          color: _C.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Active 2 minutes ago',
                        style: TextStyle(color: _C.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SellerPageScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.purpleDark),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Visit',
                    style: TextStyle(
                      color: _C.purpleDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          // Stats
          IntrinsicHeight(
            child: Row(
              children: [
                _shopStat('4.6', 'Rating'),
                const VerticalDivider(width: 1, color: _C.border),
                _shopStat('185', 'Products'),
                const VerticalDivider(width: 1, color: _C.border),
                _shopStat('100%', 'Chat Response'),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'From The Same Shop',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: _C.muted, size: 20),
              ],
            ),
          ),
          SizedBox(
            height: 175,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              itemCount: shopItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final it = shopItems[i];
                return Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: _C.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _C.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: _C.lilac,
                          child: Icon(it.$3, size: 40, color: _C.purpleMid),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _C.ink,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _PriceText(price: it.$2, big: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopStat(String value, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: _C.muted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 9. SPECIFICATION + DESCRIPTION
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildDescription(ProductData p) {
    final text =
        'Perfect for daily use at home, in the office, or on the go.\n'
        'Item: ${p.title}\n'
        'Ships from: ${p.location}\n'
        'Delivery: ${p.delivery}\n'
        'Affordable but quality.\n'
        'Cash on Delivery available.\n'
        '7-day return policy.\n'
        'Verified Vendo seller.';

    return Container(
      color: _C.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Text(
                  'Specification',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Stock, Pack Type, Size',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _C.muted, fontSize: 13),
                  ),
                ),
                Icon(Icons.chevron_right, color: _C.muted, size: 20),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              'Description',
              style: TextStyle(
                color: _C.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              text,
              maxLines: _descExpanded ? null : 5,
              overflow: _descExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.muted,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
          const Divider(height: 1, color: _C.border),
          InkWell(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _descExpanded ? 'See Less' : 'See More',
                      style: const TextStyle(color: _C.ink, fontSize: 13.5),
                    ),
                    Icon(
                      _descExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: _C.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // 10. YOU MAY ALSO LIKE
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildYouMayAlsoLike() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          child: Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFCCC5D2))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'You May Also Like',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFFCCC5D2))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _related.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.56,
            ),
            itemBuilder: (_, i) => _RelatedCard(
              product: _related[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: _related[i]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // BOTTOM ACTION BAR
  // ───────────────────────────────────────────────────────────────────────
  Widget _buildBottomBar(ProductData p, double bottomInset) {
    return Container(
      decoration: const BoxDecoration(
        color: _C.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            _BarIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat Now',
              onTap: () {},
            ),
            Container(width: 1, height: 30, color: _C.border),
            _BarIconButton(
              icon: Icons.add_shopping_cart_rounded,
              label: 'Add to Cart',
              onTap: () => _openSheet(buyNow: false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _openSheet(buyNow: true),
                child: Container(
                  height: double.infinity,
                  color: _C.orange,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Buy Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '₱${p.price}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Price text  (small ₱ + big number, orange)
// ─────────────────────────────────────────────────────────────────────────────
class _PriceText extends StatelessWidget {
  final String price;
  final double big;
  const _PriceText({required this.price, required this.big});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '₱',
            style: TextStyle(fontSize: big * 0.6),
          ),
          TextSpan(
            text: price,
            style: TextStyle(fontSize: big),
          ),
        ],
      ),
      style: const TextStyle(color: _C.orange, fontWeight: FontWeight.bold),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circle button (top bar)
// ─────────────────────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  const _CircleBtn({required this.icon, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _C.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    badge!,
                    style: const TextStyle(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row with chevron  (delivery, returns, payment)
// ─────────────────────────────────────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor = _C.purpleMid,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
            const Icon(Icons.chevron_right, size: 20, color: _C.muted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar icon button  (Chat Now / Add to Cart)
// ─────────────────────────────────────────────────────────────────────────────
class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BarIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: _C.purpleMid),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity button
// ─────────────────────────────────────────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(
            color: onTap != null ? _C.purpleDark : _C.border,
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? _C.purpleDark : _C.border,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "You may also like" card  (same style as the home product card)
// ─────────────────────────────────────────────────────────────────────────────
class _RelatedCard extends StatelessWidget {
  final ProductData product;
  final VoidCallback onTap;

  const _RelatedCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
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
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: _C.lilac,
                    child: Center(
                      child: Icon(p.icon, size: 56, color: _C.purpleMid),
                    ),
                  ),
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
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PriceText(price: p.price, big: 16),
                      Text(
                        p.sold,
                        style: const TextStyle(color: _C.muted, fontSize: 10.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 13,
                        color: _C.green,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        p.delivery,
                        style: const TextStyle(
                          color: _C.green,
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
