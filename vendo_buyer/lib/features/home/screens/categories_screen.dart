import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/home/screens/category_products_screen.dart';

/// Every category with its subcategories, from `GET /api/v1/buyer/categories`.
///
/// The web Categories page renders the same rows in a three-column grid; a
/// phone is too narrow for that, so each category is one card and its
/// subcategories sit in a wrapping row of chips. A chip opens that
/// subcategory's products, and the card header opens the whole category.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const _plum = Color(0xFF2E1535);
  static const _bg = Color(0xFFF8F6FA);

  List<ApiCategory> _categories = const [];
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
      final categories = await BuyerApi.instance.categories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
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

  /// [category] is the parent for a card header, or a subcategory for a chip.
  /// Both filter the same product feed the web category links use.
  void _open(ApiCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          categoryId: category.id,
          title: category.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _plum,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Categories',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      // Pull to refresh keeps the list in step with the web without a reload.
      body: RefreshIndicator(color: _plum, onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const _CategoriesSkeleton();
    if (_error != null) {
      return _MessageList(
        message: _error!,
        action: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _plum),
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }
    if (_categories.isEmpty) {
      return const _MessageList(message: 'No categories yet.');
    }
    return ListView.builder(
      // Always scrollable so pull-to-refresh works even on a short list.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: _categories.length,
      itemBuilder: (_, index) =>
          _CategoryCard(category: _categories[index], onSelect: _open),
    );
  }
}

/// One category: its name on top, its subcategories as chips below.
class _CategoryCard extends StatelessWidget {
  static const _ink = Color(0xFF1F1724);
  static const _muted = Color(0xFF6D6475);
  static const _plum = Color(0xFF2E1535);
  static const _cardBorder = Color(0xFFECE7F0);
  static const _chipBg = Color(0xFFF4EFF7);
  static const _chipText = Color(0xFF43214D);

  final ApiCategory category;
  final ValueChanged<ApiCategory> onSelect;

  const _CategoryCard({required this.category, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final children = category.children;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _cardBorder),
        ),
        child: InkWell(
          onTap: () => onSelect(category),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          if (children.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${children.length} '
                              '${children.length == 1 ? 'subcategory' : 'subcategories'}',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _plum,
                      size: 20,
                    ),
                  ],
                ),
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  // Wrap never overflows sideways: a chip that does not fit
                  // moves to the next line, and a long name is capped at the
                  // card's width and ellipsised instead of spilling out.
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final child in children)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelect(child),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _chipBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _cardBorder),
                                ),
                                child: Text(
                                  child.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _chipText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered copy for the empty and error states; still a list so the user can
/// pull down to refresh.
class _MessageList extends StatelessWidget {
  final String message;
  final Widget? action;

  const _MessageList({required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          // Fill the viewport so the copy sits in the middle, but let it grow
          // past the viewport (a min height, not a fixed one) when the text is
          // long or the phone is short.
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 56
                  ? constraints.maxHeight - 56
                  : 0.0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6D6475),
                      fontSize: 12.5,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder cards while the first load runs.
class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8F1),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: 6,
      itemBuilder: (_, _) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFECE7F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            block(130, 12),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [block(74, 26), block(96, 26), block(64, 26)],
            ),
          ],
        ),
      ),
    );
  }
}
