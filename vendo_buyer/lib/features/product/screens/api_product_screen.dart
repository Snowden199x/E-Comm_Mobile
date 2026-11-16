import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/seller_page/screens/api_seller_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette — from the Vendo product page redesign
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const deep = Color(0xFF2E1535);
  static const rich = Color(0xFF5A2D68);
  static const vivid = Color(0xFF7E22CE);
  static const soft = Color(0xFFF3E8FF);
  static const light = Color(0xFFFAF5FF);
  static const tag = Color(0xFF6B21A8);
  static const border = Color(0xFFE9D5FF);
  static const bg = Color(0xFFF8F9FA);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const hint = Color(0xFF9CA3AF);
  static const line = Color(0xFFF3F4F6);
  static const outline = Color(0xFFE5E7EB);
  static const green = Color(0xFF1A9B5A);
}

/// How many characters of the description are shown before "See more".
const int _descriptionPreviewChars = 600;

/// Product page backed by `GET /api/v1/buyer/products/{id}`.
///
/// Real photos, variants, stock, shop and a working Saved heart and Add to Cart.
class ApiProductScreen extends StatefulWidget {
  final int productId;
  final String? title;

  const ApiProductScreen({super.key, required this.productId, this.title});

  @override
  State<ApiProductScreen> createState() => _ApiProductScreenState();
}

class _ApiProductScreenState extends State<ApiProductScreen> {
  ApiProductDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _saved = false;
  int? _variantId;
  int _quantity = 1;
  int _imageIndex = 0;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSaved();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await BuyerApi.instance.product(widget.productId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        if (detail.variants.isNotEmpty) _variantId = detail.variants.first.id;
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

  Future<void> _loadSaved() async {
    try {
      final items = await BuyerApi.instance.savedItems();
      if (!mounted) return;
      setState(() => _saved = items.any((item) => item.id == widget.productId));
    } catch (_) {
      // The wishlist needs a session; ignore while it is unavailable.
    }
  }

  ApiVariant? get _variant {
    final variants = _detail?.variants ?? const <ApiVariant>[];
    for (final variant in variants) {
      if (variant.id == _variantId) return variant;
    }
    return null;
  }

  String get _price {
    final variant = _variant;
    if (variant != null) return variant.price;
    return _detail?.product.price ?? '';
  }

  Future<void> _toggleSaved() async {
    final next = !_saved;
    setState(() => _saved = next);
    try {
      if (next) {
        await BuyerApi.instance.saveItem(widget.productId);
      } else {
        await BuyerApi.instance.removeSavedItem(widget.productId);
      }
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() => _saved = !next);
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saved = !next);
      _toast('Could not update saved items. Check your connection.');
    }
  }

  Future<void> _addToCart() async {
    final detail = _detail;
    if (detail == null) return;
    if (detail.product.soldOut) {
      _toast('This product is sold out.');
      return;
    }
    if (detail.variants.isNotEmpty && _variantId == null) {
      _toast('Choose a variant first.');
      return;
    }
    setState(() => _adding = true);
    try {
      await BuyerApi.instance.addToCart(
        productId: widget.productId,
        quantity: _quantity,
        variantId: _variant?.id,
      );
      if (!mounted) return;
      _toast('Added to cart.');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  /// "2024-03-05 14:20:00" -> "Mar 2024". Falls back to the raw text if it
  /// is not a parseable date (e.g. the API already sends "March 2024").
  String _monthYear(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Unknown';
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = parsed.toLocal();
    return '${months[d.month - 1]} ${d.year}';
  }

  void _openShop(int sellerId, String name) {
    if (sellerId == 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiSellerScreen(sellerId: sellerId, name: name),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar with dark time / battery / signal icons.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: _C.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            // Clear white space for the phone's time, battery and signal.
            Container(height: topInset, color: _C.white),
            Expanded(
              child: Stack(
                children: [
                  _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _C.rich),
                        )
                      : _error != null
                          ? _errorState()
                          : _content(),
                  // Back button floating on top of the product photo.
                  Positioned(
                    left: 10,
                    top: 10,
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        weight: 700,
                        shadows: [
                          Shadow(color: Color(0x33FFFFFF), blurRadius: 2),
                        ],
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        foregroundColor: Colors.black,
                        fixedSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _detail == null || _loading || _error != null
            ? null
            : _bottomBar(),
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
            const Icon(Icons.cloud_off_rounded, size: 44, color: _C.hint),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.ink),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _C.rich),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final detail = _detail!;
    final product = detail.product;
    final images = detail.images.isEmpty ? [product.image] : detail.images;
    final hasDescription =
        detail.description != null && detail.description!.trim().isNotEmpty;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Hero gallery ────────────────────────────────────────────
        SizedBox(
          height: 380,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (index) => setState(() => _imageIndex = index),
                itemBuilder: (_, index) => Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
                    color: _C.soft,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: _C.rich,
                    ),
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _C.outline),
                    ),
                    child: Text(
                      '${_imageIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: _C.ink,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Price + title ───────────────────────────────────────────
        Container(
          color: _C.white,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: price (+ old price)
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            _price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _C.rich,
                            ),
                          ),
                        ),
                        if (product.compareAtPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            product.compareAtPrice!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _C.hint,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: _C.hint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Far right: sold count + heart
                  Text(
                    '${product.sold} sold',
                    style: const TextStyle(fontSize: 12.5, color: _C.muted),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _toggleSaved,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      _saved ? Icons.favorite : Icons.favorite_border,
                      size: 22,
                      color: _saved ? _C.vivid : _C.hint,
                    ),
                  ),
                ],
              ),
              if (product.stock > 0 || product.rating != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (product.stock > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _C.soft,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _C.border),
                        ),
                        child: Text(
                          '${product.stock} in stock',
                          style: const TextStyle(
                            color: _C.vivid,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (product.rating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: _C.vivid,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${product.rating}',
                            style: const TextStyle(
                              color: _C.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _C.ink,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // ── Delivery + payment (same facts as the web product page) ─
        if (detail.delivery != null)
          _card(
            margin: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelRow(
                  'Delivery',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.delivery!.shipsFrom.trim().isNotEmpty)
                        Text(
                          'Ships from ${detail.delivery!.shipsFrom}',
                          style: _factValueStyle,
                        ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Shipping fee ',
                              style: TextStyle(fontSize: 13, color: _C.muted),
                            ),
                            TextSpan(
                              text: detail.delivery!.shippingFee,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: _C.rich,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (detail.delivery!.shippingNote.trim().isNotEmpty)
                        ...[
                          const SizedBox(height: 2),
                          Text(
                            detail.delivery!.shippingNote,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _labelRow(
                  'Payment',
                  Text(detail.delivery!.paymentMethod, style: _factValueStyle),
                ),
              ],
            ),
          ),

        // ── Variants (selectable) ───────────────────────────────────
        if (detail.variants.isNotEmpty)
          _card(
            margin: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Variation'),
                      if (_variant != null)
                        TextSpan(
                          text: ': ${_variant!.label}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: detail.variants.map((variant) {
                    final selected = variant.id == _variantId;
                    final out = variant.stock <= 0;
                    return GestureDetector(
                      onTap: out
                          ? null
                          : () => setState(() => _variantId = variant.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? _C.light : _C.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? _C.rich : _C.outline,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${variant.label} · ${variant.price}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: out
                                ? _C.hint
                                : selected
                                    ? _C.deep
                                    : _C.ink,
                            decoration: out ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

        // ── Colors / sizes the seller lists (info only) ─────────────
        if (product.colors.isNotEmpty || product.sizes.isNotEmpty)
          _card(
            margin: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.colors.isNotEmpty) ...[
                  const Text(
                    'Color',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.colors.map(_infoPill).toList(),
                  ),
                ],
                if (product.colors.isNotEmpty && product.sizes.isNotEmpty)
                  const SizedBox(height: 14),
                if (product.sizes.isNotEmpty) ...[
                  const Text(
                    'Size',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: product.sizes.map(_infoPill).toList(),
                  ),
                ],
              ],
            ),
          ),

        // ── Product specifications ─────────────────────────────────
        Container(
          color: _C.white,
          margin: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionBar('Product specifications'),
              if (detail.specifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Text(
                    'The seller has not listed details for this product.',
                    style: TextStyle(fontSize: 13, color: _C.muted),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: Column(
                    children: detail.specifications
                        .map(_specRow)
                        .toList(),
                  ),
                ),
            ],
          ),
        ),

        // ── Description (expandable) ────────────────────────────────
        Container(
          color: _C.white,
          margin: const EdgeInsets.only(top: 8),
          child: _AccordionRow(
            title: 'Description',
            initiallyOpen: true,
            child: _ExpandableText(
              text: hasDescription
                  ? detail.description!
                  : 'No description was provided for this product.',
              previewChars: _descriptionPreviewChars,
            ),
          ),
        ),

        // ── Product ratings ─────────────────────────────────────────
        _ratingsSection(detail),

        // ── Shop card (same facts as the web shop card) ────────────
        _shopCard(detail),

        // ── You may also like ───────────────────────────────────────
        if (detail.recommended.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                Expanded(child: Divider(color: Color(0xFFD1D5DB))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'YOU MAY ALSO LIKE',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFD1D5DB))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: detail.recommended.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (_, index) {
                final item = detail.recommended[index];
                return _RecommendedCard(
                  name: item.name,
                  image: item.image,
                  price: item.price,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApiProductScreen(
                        productId: item.id,
                        title: item.name,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  static const _factLabelStyle = TextStyle(
    fontSize: 13,
    color: _C.muted,
    height: 1.5,
  );
  static const _factValueStyle = TextStyle(
    fontSize: 13.5,
    color: _C.ink,
    height: 1.5,
  );

  /// A fixed-width label column next to a value, like the web page's Delivery/Payment rows.
  Widget _labelRow(String label, Widget child) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 88, child: Text(label, style: _factLabelStyle)),
        Expanded(child: child),
      ],
    );
  }

  Widget _specRow(ApiSpec spec) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 124, child: Text(spec.name, style: _factLabelStyle)),
          Expanded(child: Text(spec.value, style: _factValueStyle)),
        ],
      ),
    );
  }

  // ── Seller card ───────────────────────────────────────────────────────────
  Widget _shopCard(ApiProductDetail detail) {
    final seller = detail.seller;
    final shopName = (seller?.name ?? detail.product.shop).trim();
    final shopId = seller?.id ?? detail.product.shopId;
    final location = seller?.location ?? '';
    final initial = seller?.initial ?? '';

    return _card(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF805487),
                  shape: BoxShape.circle,
                ),
                child: initial.isNotEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: _C.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : const Icon(
                        Icons.storefront_rounded,
                        color: _C.white,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shop name + View shop on the same line
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shopName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.deep,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (shopId != 0) ...[
                          const SizedBox(width: 8),
                          _shopButton(
                            icon: Icons.storefront_outlined,
                            label: 'View shop',
                            onTap: () => _openShop(shopId, shopName),
                          ),
                        ],
                      ],
                    ),
                    if (location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _C.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (seller != null) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: _C.line),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shopStat('Ratings', '${seller.ratingsCount ?? 0}'),
                _shopStat(
                  'Average rating',
                  (seller.ratingsCount ?? 0) > 0 && seller.averageRating != null
                      ? '${seller.averageRating!.toStringAsFixed(1)} / 5'
                      : 'None yet',
                ),
                _shopStat('Products', '${seller.productsCount}'),
                _shopStat('Joined', _monthYear(seller.joined)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shopButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: _C.rich),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: _C.deep,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _C.outline),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  /// One stat column — label on top, value below, both centered.
  Widget _shopStat(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: _C.muted),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _C.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ratings ───────────────────────────────────────────────────────────────
  Widget _ratingsSection(ApiProductDetail detail) {
    final ratings = detail.ratings;
    return Container(
      color: _C.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionBar('Product ratings'),
          if (ratings.total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 116,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _C.light,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: ratings.average.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: _C.rich,
                                  height: 1.1,
                                ),
                              ),
                              const TextSpan(
                                text: ' out of 5',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w400,
                                  color: _C.muted,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        _Stars(rating: ratings.average, size: 17),
                        const SizedBox(height: 5),
                        Text(
                          '${ratings.total} ${ratings.total == 1 ? 'rating' : 'ratings'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: ApiRatingSummary.stars
                          .map((star) => _ratingBar(ratings, star))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          if (ratings.total > 0) const Divider(height: 1, color: _C.line),
          if (detail.reviews.isNotEmpty)
            ...detail.reviews.map(_reviewTile)
          else if (ratings.total == 0)
            const _NoRatingsState(),
        ],
      ),
    );
  }

  Widget _ratingBar(ApiRatingSummary ratings, int star) {
    final count = ratings.countFor(star);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '$star ${star == 1 ? 'star' : 'stars'}',
              style: const TextStyle(fontSize: 11.5, color: _C.muted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratings.total == 0 ? 0.0 : count / ratings.total,
                minHeight: 7,
                backgroundColor: const Color(0xFFF0E9F2),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFE0B84A),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11.5, color: _C.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(ApiProductReview review) {
    final hasComment =
        review.comment != null && review.comment!.trim().isNotEmpty;
    final hasReply =
        review.replyBody != null && review.replyBody!.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.line)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _C.rich,
              shape: BoxShape.circle,
            ),
            child: Text(
              review.initial.trim().isEmpty ? 'B' : review.initial,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.buyer,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Stars(rating: review.rating.toDouble(), size: 13),
                    if (review.date != null && review.date!.isNotEmpty)
                      Text(
                        review.date!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _C.hint,
                        ),
                      ),
                    if (review.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Verified purchase',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF2E6B46),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                if (hasComment) ...[
                  const SizedBox(height: 6),
                  Text(
                    review.comment!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _C.ink,
                      height: 1.55,
                    ),
                  ),
                ],
                if (hasReply) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    decoration: const BoxDecoration(
                      color: _C.light,
                      border: Border(
                        left: BorderSide(color: _C.rich, width: 2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller response',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.deep,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          review.replyBody!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: _C.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? margin}) {
    return Container(
      width: double.infinity,
      margin: margin,
      color: _C.white,
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _infoPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.outline),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _C.ink,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _bottomBar() {
    final product = _detail!.product;
    final maxStock = _variant?.stock ?? product.stock;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: _C.white,
          border: Border(top: BorderSide(color: _C.outline)),
        ),
        child: Row(
          children: [
            _QtyStepper(
              value: _quantity,
              max: maxStock,
              onChanged: (value) => setState(() => _quantity = value),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _C.rich,
                    disabledBackgroundColor: _C.outline,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: (_adding || product.soldOut) ? null : _addToCart,
                  icon: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: Text(
                    product.soldOut
                        ? 'Out of stock'
                        : _adding
                            ? 'Adding…'
                            : 'Add to Cart',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
// Empty state for "No ratings yet"
// ─────────────────────────────────────────────────────────────────────────────
class _NoRatingsState extends StatelessWidget {
  const _NoRatingsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star circle with little decorative dots
            SizedBox(
              width: 96,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1E4F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_outline_rounded,
                      size: 32,
                      color: _C.deep,
                    ),
                  ),
                  // small purple dot, top-left
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: _Dot(size: 6, color: Color(0xFFD3B8DE)),
                  ),
                  // gold dot, top-right
                  const Positioned(
                    right: 10,
                    top: 4,
                    child: _Dot(size: 9, color: Color(0xFFE9C46A)),
                  ),
                  // small purple dot, bottom-left
                  const Positioned(
                    left: 10,
                    bottom: 8,
                    child: _Dot(size: 5, color: Color(0xFFD3B8DE)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No ratings yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _C.deep,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ratings appear here after buyers confirm\nthey received this product.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _C.muted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  final Color color;

  const _Dot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text that shows only the first N characters with a white fade and
// a "See more" / "See less" button
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandableText extends StatefulWidget {
  final String text;
  final int previewChars;

  const _ExpandableText({required this.text, required this.previewChars});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  static const _style = TextStyle(
    fontSize: 13.5,
    height: 1.6,
    color: _C.muted,
  );

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final isLong = text.length > widget.previewChars;

    // Short text: show everything, no fade, no button.
    if (!isLong) {
      return Text(text, style: _style);
    }

    final preview = '${text.substring(0, widget.previewChars).trimRight()}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Text(_expanded ? text : preview, style: _style),
            // White fade at the bottom while collapsed
            if (!_expanded)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 64,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0xCCFFFFFF),
                          Color(0xFFFFFFFF),
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? 'See less' : 'See more',
                  style: const TextStyle(
                    color: _C.rich,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.rich,
                  size: 18,
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
// Expandable row (Description, Specifications)
// ─────────────────────────────────────────────────────────────────────────────
class _AccordionRow extends StatefulWidget {
  final String title;
  final Widget child;
  final bool initiallyOpen;

  const _AccordionRow({
    required this.title,
    required this.child,
    this.initiallyOpen = false,
  });

  @override
  State<_AccordionRow> createState() => _AccordionRowState();
}

class _AccordionRowState extends State<_AccordionRow> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.hint,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: widget.child,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "You may also like" card
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendedCard extends StatelessWidget {
  final String name;
  final String image;
  final String price;
  final VoidCallback onTap;

  const _RecommendedCard({
    required this.name,
    required this.image,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _C.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _C.soft,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: _C.rich,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.rich,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// Quantity stepper
// ─────────────────────────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: _C.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove, size: 18),
            color: _C.rich,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _C.ink,
            ),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 18),
            color: _C.rich,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section bar + stars used by the specifications and ratings sections
// ─────────────────────────────────────────────────────────────────────────────
class _SectionBar extends StatelessWidget {
  final String title;

  const _SectionBar(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _C.light,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _C.deep,
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  final double size;

  const _Stars({required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = rating >= index + 1;
        final half = !filled && rating > index + 0.25;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          size: size,
          color: const Color(0xFFE0B84A),
        );
      }),
    );
  }
}