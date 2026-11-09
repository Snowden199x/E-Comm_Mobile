import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/home/widgets/buyer_nav_bar.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';

// Same plum + gold palette as the home screen.
class _C {
  static const plum = Color(0xFF2E1535);
  static const plumLight = Color(0xFF43214D);
  static const bg = Color(0xFFF8F6FA);
  static const white = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFECE7F0);
  static const lavenderBg = Color(0xFFF4EFF7);
  static const lavenderMuted = Color(0xFF9B8EA6);
  static const ink = Color(0xFF1F1724);
  static const muted = Color(0xFF6D6475);
  static const price = Color(0xFF43214D);
  static const discountBg = Color(0xFFEADCF2);
  static const strikeGray = Color(0xFF9CA3AF);
}

/// Saved items from `GET /api/v1/buyer/saved-items` (the same list the web heart buttons use).
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<ApiProduct> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await BuyerApi.instance.savedItems();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _remove(ApiProduct product) async {
    final previous = _items;
    setState(
      () => _items = _items.where((item) => item.id != product.id).toList(),
    );
    try {
      await BuyerApi.instance.removeSavedItem(product.id);
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() => _items = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update saved items. Check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // As a bottom-nav tab this screen sits under the floating bar, so the list
    // leaves room at the bottom; the pushed copy has no bar over it.
    final bottomClearance = Navigator.of(context).canPop()
        ? 24.0
        : 24.0 + kBuyerNavBarClearance + MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status bar icons because the header is light
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.plum),
                    )
                  : _error != null
                  ? _errorState()
                  : _items.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      color: _C.plum,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(8, 14, 8, bottomClearance),
                        child: _grid(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Light header, same look as the home screen header ──────────────────
  Widget _header() {
    // The screen is both a bottom-nav tab and a pushed route; only the pushed copy can go back.
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        border: const Border(bottom: BorderSide(color: _C.cardBorder)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(canPop ? 4 : 16, 12, 16, 12),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _C.plum,
                      size: 22,
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saved Items',
                        style: TextStyle(
                          color: _C.plum,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_items.length} item${_items.length == 1 ? '' : 's'} saved',
                        style: const TextStyle(color: _C.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: _C.lavenderBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: _C.plum,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Two-column grid, same layout as the home screen ────────────────────
  Widget _grid() {
    const gap = 6.0;
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < _items.length; i++) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: _card(_items[i]),
      );
      (i.isEven ? left : right).add(card);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: gap),
        Expanded(child: Column(children: right)),
      ],
    );
  }

  Widget _card(ApiProduct product) {
    final hasDiscount = product.discountPercent > 0;
    final location = [
      product.province,
      product.municipality,
    ].where((s) => s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ApiProductScreen(productId: product.id, title: product.name),
          ),
        );
        if (mounted) _load();
      },
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
            // ── Square image ───────────────────────────────────────
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _C.lavenderBg,
                          child: const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              size: 40,
                              color: _C.lavenderMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Discount badge (top-left, flush to the corner)
                    if (hasDiscount)
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
                            '-${product.discountPercent}%',
                            style: const TextStyle(
                              color: _C.plumLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    // Heart (top-right): tap to remove from saved
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _remove(product),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Details ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
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
                  // Price + crossed-out original price, sold count on the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: product.price,
                                style: const TextStyle(
                                  color: _C.price,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              if (product.compareAtPrice != null)
                                TextSpan(
                                  text: '  ${product.compareAtPrice}',
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
                        product.sold > 0 ? '${product.sold} sold' : 'New',
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _C.muted, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Store name on the left, location on the right
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
                            product.shop.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
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
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _C.lavenderBg,
              shape: BoxShape.circle,
              border: Border.all(color: _C.cardBorder),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 32,
              color: _C.lavenderMuted,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nothing saved yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _C.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap the heart on a product to save it for later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _C.muted),
          ),
        ],
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
            const Icon(Icons.cloud_off_rounded, size: 40, color: _C.muted),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.plum,
                side: const BorderSide(color: _C.plum),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}