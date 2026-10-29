import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/cart/screens/cart_screen.dart';
import 'package:vendo_buyer/features/seller_page/screens/api_seller_screen.dart';

/// Product page backed by `GET /api/v1/buyer/products/{id}`.
///
/// Replaces the earlier hard-coded detail screen for anything opened from the live storefront:
/// real photos, variants, stock, shop and a working Saved heart and Add to Cart.
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

  static const _purple = Color(0xFF3B1F52);
  static const _purpleMid = Color(0xFF7B2FBE);
  static const _bg = Color(0xFFF4F1F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF888888);
  static const _border = Color(0xFFECE6EA);
  static const _green = Color(0xFF1A9B5A);

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

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title ?? _detail?.product.name ?? 'Product',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _toggleSaved,
            tooltip: _saved ? 'Remove from saved items' : 'Save for later',
            icon: Icon(
              _saved ? Icons.favorite : Icons.favorite_border,
              color: _saved ? const Color(0xFFF5A7B8) : Colors.white,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
            const Icon(Icons.cloud_off_rounded, size: 44, color: _muted),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _ink),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purpleMid),
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

    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (index) => setState(() => _imageIndex = index),
                itemBuilder: (_, index) => Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _border,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (index) => Container(
                        width: index == _imageIndex ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _imageIndex ? _purpleMid : Colors.white70,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _price,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _purple,
                    ),
                  ),
                  if (product.compareAtPrice != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      product.compareAtPrice!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (product.stock > 0)
                    Text(
                      '${product.stock} in stock',
                      style: const TextStyle(fontSize: 12, color: _green),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (product.rating != null) ...[
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
                    Text(' ${product.rating}'),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${product.sold} sold',
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: product.shopId == 0
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApiSellerScreen(
                            sellerId: product.shopId,
                            name: product.shop,
                          ),
                        ),
                      ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 18, color: _purpleMid),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        product.shop,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _purpleMid,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _muted, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (detail.variants.isNotEmpty) ...[
          const SizedBox(height: 10),
          _section(
            title: 'Variation',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.variants.map((variant) {
                final selected = variant.id == _variantId;
                return ChoiceChip(
                  label: Text('${variant.label} · ${variant.price}'),
                  selected: selected,
                  selectedColor: const Color(0xFFEDE5F5),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: variant.stock <= 0 ? _muted : _ink,
                  ),
                  onSelected: variant.stock <= 0
                      ? null
                      : (_) => setState(() => _variantId = variant.id),
                );
              }).toList(),
            ),
          ),
        ],
        if (product.colors.isNotEmpty || product.sizes.isNotEmpty) ...[
          const SizedBox(height: 10),
          _section(
            title: 'Options',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...product.colors.map((color) => Chip(label: Text(color))),
                ...product.sizes.map((size) => Chip(label: Text('Size $size'))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        _section(
          title: 'Description',
          child: Text(
            (detail.description == null || detail.description!.trim().isEmpty)
                ? 'No description was provided for this product.'
                : detail.description!,
            style: const TextStyle(fontSize: 13, height: 1.55, color: _ink),
          ),
        ),
        if (detail.specifications.isNotEmpty) ...[
          const SizedBox(height: 10),
          _section(
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
                              style: const TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              spec.value,
                              style: const TextStyle(fontSize: 12.5, color: _ink),
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
        if (detail.recommended.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You may also like',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: detail.recommended.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final item = detail.recommended[index];
                      return GestureDetector(
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ApiProductScreen(
                              productId: item.id,
                              title: item.name,
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.image,
                                  height: 120,
                                  width: 130,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 120,
                                    width: 130,
                                    color: _border,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: _ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.price,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final product = _detail!.product;
    final maxStock = _variant?.stock ?? product.stock;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
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
                  style: FilledButton.styleFrom(backgroundColor: _purpleMid),
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

class _QtyStepper extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtyStepper({required this.value, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFECE6EA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
