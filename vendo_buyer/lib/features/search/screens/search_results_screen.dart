import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';
import 'package:vendo_buyer/features/seller_page/screens/api_seller_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette — from the Vendo search redesign
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const plum = Color(0xFF2E1535);
  static const plumLight = Color(0xFF4A2356);
  static const lilac = Color(0xFFF4EEF7);
  static const lilacSurface = Color(0xFFFAF6FC);
  static const border = Color(0xFFE8DDF0);
  static const accent = Color(0xFF8338EC);
  static const muted = Color(0xFF6E6277);
  static const ink = Color(0xFF1F1A24);
  static const gold = Color(0xFFE5A93B);
  static const hint = Color(0xFF9CA3AF);
  // Card colours shared with the home screen product grid.
  static const cardBorder = Color(0xFFECE7F0);
  static const lavenderBg = Color(0xFFF4EFF7);
  static const lavenderMuted = Color(0xFF9B8EA6);
  static const price = Color(0xFF43214D);
  static const discountBg = Color(0xFFEADCF2);
  static const strikeGray = Color(0xFF9CA3AF);
}

const _cardShadow = [
  BoxShadow(
    color: Color(0x0F2E1535),
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
];

/// Search across products and shops.
///
/// Typing calls the same buyer endpoints as the web storefront
/// (`GET /products?search=` and `GET /sellers?search=`) after a short debounce,
/// so products and shops appear together while the Buyer types. An empty query
/// shows recent searches, popular categories and suggested products from
/// `GET /home`.
class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, this.query = ''});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  /// Recent searches live for as long as the app is open.
  static final List<String> _recentStore = [];

  late final TextEditingController _searchCtrl;
  late final FocusNode _searchFocus;
  Timer? _debounce;
  int _request = 0;
  late String _query;
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeStatusListener;

  bool _searching = false;
  String? _error;
  List<ApiProduct> _products = const [];
  List<ApiSeller> _sellers = const [];

  List<ApiProduct> _recommended = const [];
  List<String> _popular = const [];
  bool _loadingRecommended = true;
  String? _recommendedError;

  @override
  void initState() {
    super.initState();
    _query = widget.query.trim();
    _searchCtrl = TextEditingController(text: _query);
    _searchFocus = FocusNode();
    _loadRecommended();
    if (_query.isNotEmpty) {
      _remember(_query);
      _search(_query);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wait for the route transition to finish before opening the keyboard.
    if (_query.isNotEmpty || _routeStatusListener != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return;
    if (animation.status == AnimationStatus.completed) {
      _focusSearchField();
      return;
    }

    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(onStatus);
      _routeStatusListener = null;
      _focusSearchField();
    }

    _routeAnimation = animation;
    _routeStatusListener = onStatus;
    animation.addStatusListener(onStatus);
  }

  void _focusSearchField() {
    if (mounted) _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_routeAnimation != null && _routeStatusListener != null) {
      _routeAnimation!.removeStatusListener(_routeStatusListener!);
    }
    _searchFocus.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Recent searches ───────────────────────────────────────────────────────
  void _remember(String term) {
    final clean = term.trim();
    if (clean.isEmpty) return;
    _recentStore.removeWhere((t) => t.toLowerCase() == clean.toLowerCase());
    _recentStore.insert(0, clean);
    if (_recentStore.length > 8) _recentStore.removeRange(8, _recentStore.length);
  }

  void _clearRecent() {
    HapticFeedback.selectionClick();
    setState(_recentStore.clear);
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadRecommended() async {
    setState(() {
      _loadingRecommended = true;
      _recommendedError = null;
    });
    try {
      final data = await BuyerApi.instance.home();
      if (!mounted) return;
      final products = (data['products'] as List? ?? [])
          .map(
            (e) => ApiProduct.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
      final categories = (data['categories'] as List? ?? [])
          .map((e) => e is Map ? '${e['name'] ?? ''}'.trim() : '')
          .where((name) => name.isNotEmpty)
          .take(8)
          .toList();
      setState(() {
        _recommended = products.take(8).toList();
        _popular = categories;
        _loadingRecommended = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _recommendedError = e.message;
        _loadingRecommended = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendedError =
            'Could not load recommendations. Check your connection.';
        _loadingRecommended = false;
      });
    }
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _clearResults();
      return;
    }

    final request = ++_request;
    setState(() {
      _query = query;
      _searching = true;
      _error = null;
      _products = const [];
      _sellers = const [];
    });

    try {
      // Both requests start together; the API searches product names and seller
      // business/owner names, matching the web search.
      final results = await Future.wait<dynamic>([
        BuyerApi.instance.products(search: query),
        BuyerApi.instance.sellers(search: query),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _products = results[0] as List<ApiProduct>;
        _sellers = results[1] as List<ApiSeller>;
        _searching = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.message;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = 'Could not reach Vendo. Check your connection and try again.';
        _searching = false;
      });
    }
  }

  void _clearResults() {
    _request++;
    setState(() {
      _query = '';
      _searching = false;
      _error = null;
      _products = const [];
      _sellers = const [];
    });
  }

  void _onChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    if (query.isEmpty) {
      _clearResults();
      return;
    }

    // Show the new query and clear the old hits immediately, then wait so a
    // fast typist does not fire one request per letter.
    setState(() {
      _query = query;
      _searching = true;
      _error = null;
      _products = const [];
      _sellers = const [];
    });
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  void _submit() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      _clearResults();
      return;
    }
    FocusScope.of(context).unfocus();
    _remember(query);
    _search(query);
  }

  void _choose(String term) {
    _searchCtrl.text = term;
    _searchCtrl.selection = TextSelection.collapsed(offset: term.length);
    FocusScope.of(context).unfocus();
    _remember(term);
    _search(term);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        color: _C.plum,
        onRefresh: () => _query.isEmpty ? _loadRecommended() : _search(_query),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: _query.isEmpty ? _discoverSlivers() : _resultSlivers(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 66,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leadingWidth: 48,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: _C.plum, size: 26),
      ),
      title: _searchField(),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }

  Widget _searchField() {
    final hasText = _searchCtrl.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(12, 0, 5, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.plum, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: _C.muted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) => _submit(),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _C.ink,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search products or shops...',
                  hintStyle: TextStyle(color: _C.hint, fontSize: 13.5),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (hasText)
              _FieldIcon(
                icon: Icons.close_rounded,
                tooltip: 'Clear search',
                onTap: () {
                  _searchCtrl.clear();
                  _onChanged('');
                },
              )
            else ...[
              _FieldIcon(
                icon: Icons.photo_camera_outlined,
                tooltip: 'Search by photo',
                onTap: () => _comingSoon('Photo search'),
              ),
              _FieldIcon(
                icon: Icons.mic_none_rounded,
                tooltip: 'Voice search',
                onTap: () => _comingSoon('Voice search'),
              ),
            ],
            const SizedBox(width: 4),
            Material(
              color: _C.plum,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _submit,
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.search_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty-query view: recent, popular, suggestions ────────────────────────
  List<Widget> _discoverSlivers() {
    return [
      if (_recentStore.isNotEmpty) SliverToBoxAdapter(child: _recentSearches()),
      if (_popular.isNotEmpty) SliverToBoxAdapter(child: _popularSearches()),
      SliverToBoxAdapter(
        child: _sectionTitle(
          'Search Suggestions',
          subtitle: 'Verified picks from approved sellers',
        ),
      ),
      if (_loadingRecommended)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator(color: _C.plum)),
          ),
        )
      else if (_recommendedError != null)
        SliverToBoxAdapter(
          child: _retryBox(_recommendedError!, _loadRecommended),
        )
      else if (_recommended.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No suggestions yet. Try searching for a product.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.muted, fontSize: 12.5),
              ),
            ),
          ),
        )
      else
        _productGrid(_recommended),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ];
  }

  Widget _recentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'RECENT SEARCHES',
                style: TextStyle(
                  color: _C.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _clearRecent,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Clear',
                        style: TextStyle(color: _C.muted, fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.delete_outline_rounded,
                          color: _C.muted, size: 15),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentStore
                .map((term) => _TermChip(label: term, onTap: () => _choose(term)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _popularSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POPULAR SEARCHES',
            style: TextStyle(
              color: _C.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popular
                .map((term) => _TermChip(label: term, onTap: () => _choose(term)))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Results view ──────────────────────────────────────────────────────────
  List<Widget> _resultSlivers() {
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _resultSummary()),
    ];

    if (_searching) {
      return [
        ...slivers,
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: 80),
            child: Center(child: CircularProgressIndicator(color: _C.plum)),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        ...slivers,
        SliverToBoxAdapter(child: _retryBox(_error!, () => _search(_query))),
      ];
    }

    if (_sellers.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Shops',
            subtitle:
                '${_sellers.length} match${_sellers.length == 1 ? '' : 'es'} for “$_query”',
          ),
        ),
      );
      slivers.add(SliverToBoxAdapter(child: _shopRow(_sellers)));
    }

    if (_products.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Products',
            subtitle:
                '${_products.length} match${_products.length == 1 ? '' : 'es'} for “$_query”',
          ),
        ),
      );
      slivers.add(_productGrid(_products));
    }

    if (_sellers.isEmpty && _products.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _noResults()));
    }

    if (_recommended.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _sectionTitle(
            'Search Suggestions',
            subtitle: 'More picks while you search',
          ),
        ),
      );
      slivers.add(SliverToBoxAdapter(child: _recommendedRow(_recommended)));
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 28)));
    return slivers;
  }

  Widget _resultSummary() {
    final shops = _sellers.length;
    final products = _products.length;
    final text = _searching
        ? 'Searching for “$_query”…'
        : '$shops shop${shops == 1 ? '' : 's'} · '
              '$products product${products == 1 ? '' : 's'} '
              'for “$_query”';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _C.plum,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: _C.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  /// Staggered 2-column grid, same layout as the home screen product grid.
  Widget _productGrid(List<ApiProduct> products) {
    const gap = 6.0;
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < products.length; i++) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: gap),
        child: _ProductCard(product: products[i]),
      );
      (i.isEven ? left : right).add(card);
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(children: [const SizedBox(height: 24), ...left]),
            ),
            const SizedBox(width: gap),
            Expanded(child: Column(children: right)),
          ],
        ),
      ),
    );
  }

  Widget _shopRow(List<ApiSeller> sellers) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: sellers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _ShopCard(seller: sellers[index]),
      ),
    );
  }

  Widget _recommendedRow(List<ApiProduct> products) {
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => SizedBox(
          width: 164,
          child: _ProductCard(product: products[index]),
        ),
      ),
    );
  }

  Widget _noResults() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 8),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: _C.lilac,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _C.plum,
              size: 27,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No products or shops found for “$_query”',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _C.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a shorter word, a product name, a shop name, or a different spelling.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _retryBox(String message, VoidCallback retry) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: _C.muted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.ink, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.plum),
            onPressed: retry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon button used inside the search field
// ─────────────────────────────────────────────────────────────────────────────
class _FieldIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FieldIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: _C.muted, size: 19),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill chip for recent / popular searches
// ─────────────────────────────────────────────────────────────────────────────
class _TermChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TermChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: _C.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: _C.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop card
// ─────────────────────────────────────────────────────────────────────────────
class _ShopCard extends StatelessWidget {
  final ApiSeller seller;

  const _ShopCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    final location = [seller.province, seller.municipality]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(', ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApiSellerScreen(
            sellerId: seller.id,
            name: seller.name,
          ),
        ),
      ),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: _cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: _C.lilac,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: _C.plum,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    seller.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.plum,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _C.muted, fontSize: 10.5),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: _C.gold),
                      const SizedBox(width: 2),
                      Text(
                        seller.rating == null
                            ? 'New'
                            : seller.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${seller.productsCount} products',
                        style: const TextStyle(color: _C.muted, fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _C.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card — same design as the home screen product card
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final ApiProduct product;

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
    errorBuilder: (_, _, _) => Container(
      color: _C.lavenderBg,
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 40,
          color: _C.lavenderMuted,
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

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final discount = p.discountPercent > 0 ? '-${p.discountPercent}%' : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ApiProductScreen(productId: p.id, title: p.name),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                            color: _C.discountBg,
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Text(
                            discount,
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
                    p.name,
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
                                text: p.price,
                                style: const TextStyle(
                                  color: _C.price,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              if (p.compareAtPrice != null)
                                TextSpan(
                                  text: '  ${p.compareAtPrice}',
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
                        p.sold > 0 ? '${p.sold} sold' : 'New arrival',
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _C.muted, fontSize: 10),
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
                          color: _C.plum.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.shop.toUpperCase(),
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
      ),
    );
  }
}