import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/cart/screens/cart_screen.dart';
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

  void _share() {
    final name = _detail?.product.name ?? widget.title;
    if (name == null || name.isEmpty) return;
    Clipboard.setData(ClipboardData(text: name));
    _toast('Product name copied.');
  }

  void _openShop(ApiProduct product) {
    if (product.shopId == 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiSellerScreen(
          sellerId: product.shopId,
          name: product.shop,
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.white,
        foregroundColor: _C.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          widget.title ?? _detail?.product.name ?? 'Product',
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _C.ink,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _share,
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined, size: 22),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            tooltip: 'Cart',
            icon: const Icon(Icons.shopping_cart_outlined, size: 22),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.line),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.rich))
          : _error != null
              ? _errorState()
              : _content(),
      bottomNavigationBar: _detail == null || _loading || _error != null
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
                        fontSize: 11,
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
                  Flexible(
                    child: Text(
                      _price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: _C.rich,
                      ),
                    ),
                  ),
                  if (product.compareAtPrice != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      product.compareAtPrice!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _C.hint,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: _C.hint,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${product.sold} sold',
                    style: const TextStyle(fontSize: 12, color: _C.muted),
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
                            fontSize: 11,
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
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
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: _C.ink,
                  height: 1.4,
                ),
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 12.5,
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
                            fontSize: 12.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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
                      fontSize: 12.5,
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
                      fontSize: 12.5,
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

        // ── Share strip ─────────────────────────────────────────────
        Container(
          color: const Color(0xFF1F2937),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Do you want to share this product?',
                  style: TextStyle(color: Color(0xFFE5E7EB), fontSize: 12),
                ),
              ),
              OutlinedButton(
                onPressed: _share,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x99FFFFFF)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Share',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // ── Description + specifications (expandable) ───────────────
        Container(
          color: _C.white,
          child: Column(
            children: [
              _AccordionRow(
                title: 'Description',
                initiallyOpen: true,
                child: Text(
                  hasDescription
                      ? detail.description!
                      : 'No description was provided for this product.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: _C.muted,
                  ),
                ),
              ),
              if (detail.specifications.isNotEmpty) ...[
                const Divider(height: 1, color: _C.line),
                _AccordionRow(
                  title: 'Specifications',
                  child: Column(
                    children: detail.specifications
                        .map(
                          (spec) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    spec.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _C.hint,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    spec.value,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: _C.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Shop card ───────────────────────────────────────────────
        _card(
          margin: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _C.soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: _C.rich,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  product.shop,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (product.shopId != 0)
                OutlinedButton(
                  onPressed: () => _openShop(product),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _C.rich),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Visit',
                    style: TextStyle(
                      color: _C.rich,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),

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
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
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
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
                      fontSize: 12.5,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.rich,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w700,
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