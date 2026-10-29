import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';

/// Shop page backed by `GET /api/v1/buyer/sellers/{id}`: the approved products of one Seller.
class ApiSellerScreen extends StatefulWidget {
  final int sellerId;
  final String? name;

  const ApiSellerScreen({super.key, required this.sellerId, this.name});

  @override
  State<ApiSellerScreen> createState() => _ApiSellerScreenState();
}

class _ApiSellerScreenState extends State<ApiSellerScreen> {
  static const _purple = Color(0xFF3B1F52);
  static const _purpleMid = Color(0xFF7B2FBE);
  static const _bg = Color(0xFFF4F1F8);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF888888);

  ApiSeller? _seller;
  List<ApiProduct> _products = const [];
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

  @override
  Widget build(BuildContext context) {
    final seller = _seller;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          seller?.name ?? widget.name ?? 'Shop',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFFEDE5F5),
                              child: Text(
                                (seller?.name.isNotEmpty ?? false)
                                    ? seller!.name.substring(0, 1).toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _purpleMid,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    seller?.name ?? 'Shop',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if ((seller?.municipality ?? '').isNotEmpty)
                                        seller!.municipality!,
                                      if ((seller?.province ?? '').isNotEmpty)
                                        seller!.province!,
                                    ].join(', '),
                                    style: const TextStyle(fontSize: 12, color: _muted),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${seller?.productsCount ?? _products.length} products',
                                    style: const TextStyle(fontSize: 12, color: _muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_products.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'This shop has no available products yet.',
                              style: TextStyle(color: _muted),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.62,
                            ),
                            itemBuilder: (_, index) {
                              final product = _products[index];
                              return _ShopProductCard(
                                product: product,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ApiProductScreen(
                                      productId: product.id,
                                      title: product.name,
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

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 44, color: _muted),
            const SizedBox(height: 12),
            Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
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
}

class _ShopProductCard extends StatelessWidget {
  final ApiProduct product;
  final VoidCallback onTap;

  const _ShopProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFECE6EA)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                product.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFECE6EA),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF52245B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.soldOut
                        ? 'Out of stock'
                        : '${product.stock} available',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888)),
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
