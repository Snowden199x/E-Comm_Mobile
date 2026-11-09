import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette — from the Vendo shop page redesign
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const plum900 = Color(0xFF2E1535);
  static const plum800 = Color(0xFF431F4D);
  static const plum700 = Color(0xFF5A2A67);
  static const plum600 = Color(0xFF753786);
  static const plum100 = Color(0xFFF4EAF7);
  static const plum50 = Color(0xFFFBF5FC);
  static const surface = Color(0xFFFFF7FF);
  static const dim = Color(0xFFE2D5EA);
  static const dimSoft = Color(0xFFECDFF2);
  static const thumb = Color(0xFFECE5EF);
  static const white = Color(0xFFFFFFFF);
}

/// Shop page backed by `GET /api/v1/buyer/sellers/{id}`: the approved products of one Seller.
class ApiSellerScreen extends StatefulWidget {
  final int sellerId;
  final String? name;

  const ApiSellerScreen({super.key, required this.sellerId, this.name});

  @override
  State<ApiSellerScreen> createState() => _ApiSellerScreenState();
}

class _ApiSellerScreenState extends State<ApiSellerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  ApiSeller? _seller;
  List<ApiProduct> _products = const [];
  bool _loading = true;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await BuyerApi.instance.seller(widget.sellerId);
      if (!mounted) return;
      setState(() {
        _seller = data['seller'] is Map
            ? ApiSeller.fromJson(Map<String, dynamic>.from(data['seller'] as Map))
            : null;
        _products = (data['data'] as List? ?? [])
            .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
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

  List<ApiProduct> get _visible {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  void _openProduct(ApiProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiProductScreen(
          productId: product.id,
          title: product.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.surface,
        body: Column(
          children: [
            _buildHeader(MediaQuery.of(context).padding.top),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.plum900),
                    )
                  : _error != null
                      ? _errorState()
                      : _content(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gradient header: back, search in shop, seller profile ─────────────────
  Widget _buildHeader(double topPad) {
    final seller = _seller;
    final name = seller?.name ?? widget.name ?? 'Shop';
    final location = [
      if ((seller?.municipality ?? '').isNotEmpty) seller!.municipality!,
      if ((seller?.province ?? '').isNotEmpty) seller!.province!,
    ].join(', ');
    final count = seller?.productsCount ?? _products.length;
    final canSearch = !_loading && _error == null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_C.dim, _C.dimSoft, _C.surface],
        ),
        border: Border(bottom: BorderSide(color: _C.plum100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: _C.plum900,
                  size: 26,
                ),
              ),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _C.plum900.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: _C.plum700.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          enabled: canSearch,
                          textInputAction: TextInputAction.search,
                          onChanged: (v) => setState(() => _filter = v),
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.plum900,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search in shop',
                            hintStyle: TextStyle(
                              color: _C.plum700.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_filter.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _filter = '');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _C.plum700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _C.plum900.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _C.plum900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _C.plum900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (seller?.rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: _C.plum600,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              seller!.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _C.plum700,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '|',
                                style: TextStyle(
                                  color: _C.plum900.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ],
                          Text(
                            '$count product${count == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _C.plum800,
                            ),
                          ),
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: _C.plum700.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _C.plum700.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────
  Widget _content() {
    final visible = _visible;
    final searching = _filter.trim().isNotEmpty;

    return RefreshIndicator(
      color: _C.plum900,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          if (_products.isNotEmpty && !searching) _banner(),
          if (_products.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(2, searching ? 0 : 18, 2, 12),
              child: Text(
                searching
                    ? '${visible.length} result${visible.length == 1 ? '' : 's'} for “${_filter.trim()}”'
                    : 'Just For You',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.plum900,
                ),
              ),
            ),
          ],
          if (_products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'This shop has no available products yet.',
                  style: TextStyle(color: _C.plum700),
                ),
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No products in this shop match “${_filter.trim()}”.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _C.plum700),
                ),
              ),
            )
          else
            _ProductColumns(
              products: visible,
              shopName: _seller?.name ?? widget.name ?? '',
              onTap: _openProduct,
            ),
        ],
      ),
    );
  }

  /// Banner built from the shop's own first product.
  Widget _banner() {
    final first = _products.first;
    final shopName = _seller?.name ?? widget.name ?? 'Shop';

    return GestureDetector(
      onTap: () => _openProduct(first),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_C.plum50, _C.white, _C.plum100],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.plum100),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Container(
                color: _C.plum100.withValues(alpha: 0.4),
                padding: const EdgeInsets.all(8),
                child: Transform.rotate(
                  angle: -0.035,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.expand(
                      child: Image.network(
                        first.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _C.thumb,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: _C.plum700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.plum900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_products.length} product${_products.length == 1 ? '' : 's'} available',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _C.plum700.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 24,
                      height: 2,
                      decoration: BoxDecoration(
                        color: _C.plum900,
                        borderRadius: BorderRadius.circular(2),
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

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 44, color: _C.plum700),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.plum900),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _C.plum900),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product cards
//
// Same card format as the buyer home screen's product grid: a square photo
// with the discount badge, save heart and photo dots, then the title, purple
// price with the crossed-out original, sold count, and the shop/location line.
// ─────────────────────────────────────────────────────────────────────────────
const Color _kCardBorder = Color(0xFFECE7F0);
const Color _kCardInk = Color(0xFF1F1724);
const Color _kCardMuted = Color(0xFF6D6475);
const Color _kCardPrice = Color(0xFF43214D);
const Color _kDiscountBg = Color(0xFFEADCF2);
const Color _kStrikeGray = Color(0xFF9CA3AF);
const Color _kPhotoPlaceholderBg = Color(0xFFF4EFF7);
const Color _kPhotoPlaceholderIcon = Color(0xFF9B8EA6);

/// Two staggered columns of cards (the left column starts a little lower),
/// the same layout the home screen uses for its recommendations.
class _ProductColumns extends StatelessWidget {
  final List<ApiProduct> products;
  final String shopName;
  final ValueChanged<ApiProduct> onTap;

  const _ProductColumns({
    required this.products,
    required this.shopName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 6.0; // space between the two columns and between cards
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < products.length; i++) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: _ShopProductCard(
          product: products[i],
          shopName: shopName,
          onTap: () => onTap(products[i]),
        ),
      );
      (i.isEven ? left : right).add(card);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(children: [const SizedBox(height: 24), ...left]),
        ),
        const SizedBox(width: gap),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}

class _ShopProductCard extends StatefulWidget {
  final ApiProduct product;
  final String shopName;
  final VoidCallback onTap;

  const _ShopProductCard({
    required this.product,
    required this.shopName,
    required this.onTap,
  });

  @override
  State<_ShopProductCard> createState() => _ShopProductCardState();
}

class _ShopProductCardState extends State<_ShopProductCard> {
  /// A card with several photos cycles through them on its own.
  static const _autoSlideInterval = Duration(milliseconds: 4500);
  static const _slideDuration = Duration(milliseconds: 450);

  bool _liked = false;
  int _imageIndex = 0;
  bool _autoSliding = false;
  Timer? _slideTimer;
  final PageController _pageCtrl = PageController();

  ApiProduct get _p => widget.product;

  /// Photos shown on the card: every product photo, or the single cover image.
  List<String> get _photos {
    final photos = _p.images.where((url) => url.trim().isNotEmpty).toList();
    return photos.isNotEmpty ? photos : [_p.image];
  }

  @override
  void initState() {
    super.initState();
    _syncAutoSlide();
  }

  @override
  void didUpdateWidget(covariant _ShopProductCard oldWidget) {
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
      color: _kPhotoPlaceholderBg,
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 40,
          color: _kPhotoPlaceholderIcon,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Price before the discount, without the currency sign; null when the
  /// product is not discounted.
  String? get _originalPrice {
    final real = _p.compareAtPrice?.replaceFirst('₱', '');
    if (real != null && real.isNotEmpty) return real;
    return _originalPriceOf(
      _p.price.replaceFirst('₱', ''),
      _p.discountPercent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final price = p.price.replaceFirst('₱', '');
    final originalPrice = _originalPrice;
    final discount = p.discountPercent > 0 ? '-${p.discountPercent}%' : null;
    final sold = p.sold > 0 ? '${p.sold} sold' : 'New arrival';
    final shop = (p.shop.isNotEmpty ? p.shop : widget.shopName).toUpperCase();
    final location = [p.province, p.municipality]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kCardBorder),
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
                    if (discount != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: const BoxDecoration(
                            color: _kDiscountBg,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Text(
                            discount,
                            style: const TextStyle(
                              color: _C.plum800,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    // Out of stock (bottom-left, over the photo)
                    if (p.soldOut)
                      Positioned(
                        left: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _C.plum900,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'Out of stock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
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
                                    ? _C.plum900
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
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kCardInk,
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
                                text: '₱$price',
                                style: const TextStyle(
                                  color: _kCardPrice,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              if (originalPrice != null)
                                TextSpan(
                                  text: '  ₱$originalPrice',
                                  style: const TextStyle(
                                    color: _kStrikeGray,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: _kStrikeGray,
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
                        sold,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _kCardMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Store name on the left, location flush right on the same line.
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 12,
                          color: _C.plum900.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            shop,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kCardMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.5,
                            ),
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: _kCardMuted,
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
      ),
    );
  }
}

/// Works backwards from the discounted price and the discount % to get the
/// original price, keeping the same comma/decimal formatting.
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
