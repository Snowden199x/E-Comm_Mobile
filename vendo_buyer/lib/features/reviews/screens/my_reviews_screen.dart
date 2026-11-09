import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// The signed-in Buyer's own product reviews from `GET /api/v1/buyer/reviews`.
/// These are the same rows the web product page shows, including the Seller's reply.
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  List<ApiReview> _reviews = const [];
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
      final reviews = await BuyerApi.instance.reviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
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
        _error = 'Could not reach Vendo. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'My Reviews',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your reviews',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: ProfileColors.header,
              onRefresh: _load,
              child: _reviews.isEmpty ? _empty() : _list(),
            ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 460,
          child: ProfileEmptyState(
            icon: Icons.star_border_rounded,
            title: 'No reviews yet',
            text:
                'After you confirm receipt of an order, you can rate each product. Your reviews appear here.',
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return GestureDetector(
          onTap: review.productId > 0
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApiProductScreen(
                      productId: review.productId,
                      title: review.productName,
                    ),
                  ),
                )
              : null,
          child: ProfileCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        review.image,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 58,
                          height: 58,
                          color: ProfileColors.soft,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 20,
                            color: ProfileColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ProfileColors.ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          if (review.shop.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              review.shop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ProfileColors.muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ProfileStars(rating: review.rating, size: 16),
                              const SizedBox(width: 6),
                              if (review.createdAtLabel != null)
                                Text(
                                  review.createdAtLabel!,
                                  style: const TextStyle(
                                    color: ProfileColors.muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (review.visibility != 'published')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ProfileColors.orangeSoft,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            color: ProfileColors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    review.comment,
                    style: const TextStyle(
                      color: ProfileColors.ink,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                ],
                if (review.reply != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ProfileColors.soft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seller replied${review.reply!.atLabel != null ? ' · ${review.reply!.atLabel}' : ''}',
                          style: const TextStyle(
                            color: ProfileColors.header,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          review.reply!.body,
                          style: const TextStyle(
                            color: ProfileColors.ink,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
