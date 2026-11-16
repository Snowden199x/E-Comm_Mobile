import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/messages/screens/seller_chat_screen.dart';
import 'package:vendo_buyer/features/product/screens/api_product_screen.dart';

// Same colours as the web shop page (buyer/sellers/show.blade.php).
class _C {
  static const bg = Color(0xFFF7F3F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B1730);
  static const plum = Color(0xFF402143);
  static const plumMid = Color(0xFF52245B);
  static const plumSoft = Color(0xFF805487);
  static const pillBg = Color(0xFFF5ECF6);
  static const muted = Color(0xFF6F5F73);
  static const border = Color(0xFFEEE6EF);
  static const statsBorder = Color(0xFFF1E8F2);
  static const statsBg = Color(0xFFFAF7FB);
  static const banner = Color(0xFF4B2452);
  static const gold = Color(0xFFE0B84A);
  static const mutedGray = Color(0xFF9A8A9D);
  static const outBg = Color(0xFFEFE8F0);
  static const outInk = Color(0xFF7A6A7E);
  static const heart = Color(0xFFA32B43);

  // Header (top part of the shop page)
  static const headerDeep = Color(0xFF2E1535);
  static const headerRich = Color(0xFF5A2D68);
  static const headerGold = Color(0xFFE9C46A);
}

/// Shop page backed by `GET /api/v1/buyer/sellers/{id}`: the shop header the web shows
/// (banner, photo, approved badge, location, stats), its in-shop search and sort, and the
/// approved products of that Seller.
class ApiSellerScreen extends StatefulWidget {
  final int sellerId;
  final String? name;

  const ApiSellerScreen({super.key, required this.sellerId, this.name});

  @override
  State<ApiSellerScreen> createState() => _ApiSellerScreenState();
}

class _ApiSellerScreenState extends State<ApiSellerScreen> {
  static const _sortLabels = <String, String>{
    'latest': 'Latest',
    'price_asc': 'Price, low to high',
    'price_desc': 'Price, high to low',
  };

  final TextEditingController _searchCtrl = TextEditingController();

  ApiSeller? _seller;
  List<ApiProduct> _products = const [];
  final Set<int> _saved = <int>{};

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;

  String _search = '';
  String _sort = 'latest';
  int _page = 1;
  int _lastPage = 1;
  int _perPage = 12;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadSaved();
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
      _moreError = null;
    });
    try {
      final data = await BuyerApi.instance.seller(
        widget.sellerId,
        search: _search,
        sort: _sort,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _applyResponse(data, append: false);
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

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final data = await BuyerApi.instance.seller(
        widget.sellerId,
        search: _search,
        sort: _sort,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _applyResponse(data, append: true);
        _loadingMore = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _moreError = e.message;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moreError = 'Could not load more products. Check your connection.';
        _loadingMore = false;
      });
    }
  }

  /// Reads one page payload: the shop header and the page's products.
  void _applyResponse(Map<String, dynamic> data, {required bool append}) {
    final rawSeller = data['seller'];
    if (rawSeller is Map) {
      _seller = ApiSeller.fromJson(Map<String, dynamic>.from(rawSeller));
    }

    final items = (data['data'] as List? ?? [])
        .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    _products = append ? [..._products, ...items] : items;

    final meta = data['meta'] is Map
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : const <String, dynamic>{};
    _page = (meta['current_page'] as num?)?.toInt() ?? 1;
    _lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
    _perPage = (meta['per_page'] as num?)?.toInt() ?? _perPage;
    _total = (meta['total'] as num?)?.toInt() ?? items.length;
  }

  Future<void> _loadSaved() async {
    try {
      final items = await BuyerApi.instance.savedItems();
      if (!mounted) return;
      setState(() {
        _saved
          ..clear()
          ..addAll(items.map((item) => item.id));
      });
    } catch (_) {
      // Favourites need a session; the hearts stay unsaved while it is unavailable.
    }
  }

  Future<void> _toggleSaved(ApiProduct product) async {
    final wasSaved = _saved.contains(product.id);
    setState(() {
      if (wasSaved) {
        _saved.remove(product.id);
      } else {
        _saved.add(product.id);
      }
    });
    try {
      if (wasSaved) {
        await BuyerApi.instance.removeSavedItem(product.id);
      } else {
        await BuyerApi.instance.saveItem(product.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _saved.add(product.id);
        } else {
          _saved.remove(product.id);
        }
      });
      _toast('Could not update saved items. Check your connection.');
    }
  }

  /// Runs the shop's search/sort exactly like the web form (it reloads page 1).
  void _applyFilters({String? search, String? sort}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _search = (search ?? _search).trim();
      _sort = sort ?? _sort;
    });
    _load();
  }

  void _openProduct(ApiProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ApiProductScreen(productId: product.id, title: product.name),
      ),
    );
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerChatScreen(
          sellerId: widget.sellerId,
          sellerName: _seller?.name ?? widget.name,
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _C.plum,
        ),
      );
  }

  Future<void> _copyShopLink() async {
    final url = _seller?.url;
    if (url == null || url.trim().isEmpty) {
      _toast('Copying is not available right now');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    _toast('Shop link copied');
  }

  @override
  Widget build(BuildContext context) {
    // While the shop is loading (or failed with nothing to show) there is no
    // dark header yet, so the status bar keeps dark icons and a plain back bar.
    final showingHeader =
        !((_loading && _seller == null) || (_error != null && _seller == null));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: showingHeader
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: showingHeader
            ? _content()
            : SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _backBar(),
                    Expanded(
                      child: _loading && _seller == null
                          ? const Center(
                              child: CircularProgressIndicator(color: _C.plum),
                            )
                          : _errorState(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _backBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => Navigator.of(context).maybePop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, size: 18, color: _C.plumSoft),
                SizedBox(width: 2),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _C.plumSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shop header (top part) ────────────────────────────────────────────────
  //
  //   <-
  //   [photo]  Shop name  ✓
  //            ★ 4.8  |  Joined Jan 2025                 [ Share ]
  //            📍 Santa Cruz, Laguna
  //   ┌────────────────────────────────────────────────────────┐
  //   │ 💬 Chat with seller                                  >  │
  //   └────────────────────────────────────────────────────────┘
  Widget _shopHeader() {
    final seller = _seller;
    final shopName = (seller?.name ?? widget.name ?? '').trim();
    final displayName = shopName.isEmpty ? 'Shop' : shopName;
    final location = (seller?.location ?? '').trim();
    final joined = (seller?.joined ?? '').trim();
    final ratingsCount = seller?.ratingsCount ?? 0;
    final average = seller?.averageRating;
    final hasRating = ratingsCount > 0 && average != null;
    final banner = seller?.banner;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Stack(
      children: [
        // Solid plum underneath, then the shop's banner photo (if any),
        // then a plum overlay so the white text stays readable.
        const Positioned.fill(child: ColoredBox(color: _C.headerDeep)),
        if (banner != null)
          Positioned.fill(
            child: Image.network(
              banner,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: banner != null
                    ? const [Color(0xD92E1535), Color(0xE65A2D68)]
                    : const [_C.headerDeep, _C.headerRich],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back arrow + search box (search runs from the keyboard)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _C.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) => _applyFilters(search: value),
                          cursorColor: _C.white,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _C.white,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search in this shop',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xB3FFFFFF),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Color(0xCCFFFFFF),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 38,
                              minHeight: 38,
                            ),
                            filled: true,
                            fillColor: const Color(0x29FFFFFF),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            border: _fieldBorder(),
                            enabledBorder: _fieldBorder(),
                            focusedBorder: _fieldBorder(focused: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Photo + name / rating / joined + Share
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(url: seller?.avatar, initial: displayName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _C.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_outlined,
                                color: Color(0xCCFFFFFF),
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: _C.headerGold,
                                size: 16,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                hasRating
                                    ? average.toStringAsFixed(1)
                                    : 'No ratings',
                                style: const TextStyle(
                                  color: _C.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (joined.isNotEmpty) ...[
                                Container(
                                  width: 1,
                                  height: 12,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  color: const Color(0x66FFFFFF),
                                ),
                                Flexible(
                                  child: Text(
                                    'Joined $joined',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xCCFFFFFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  color: Color(0xB3FFFFFF),
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xB3FFFFFF),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Share = copy the shop link
                    FilledButton.icon(
                      onPressed: _copyShopLink,
                      icon: const Icon(Icons.share_outlined, size: 15),
                      label: const Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _C.white,
                        foregroundColor: _C.headerDeep,
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chat bar
                InkWell(
                  onTap: _openChat,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x24FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x2EFFFFFF)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: _C.white,
                          size: 17,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chat with seller',
                            style: TextStyle(
                              color: _C.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _C.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  /// Total units sold across the products loaded on this page.
  int get _totalSold => _products.fold<int>(0, (sum, p) => sum + p.sold);

  // ── Stats + about card (below the header) ────────────────────────────────
  Widget _infoCard() {
    final seller = _seller;
    final ratingsCount = seller?.ratingsCount ?? 0;
    final description = (seller?.description ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsCard(
            products: seller?.productsCount ?? _total,
            ratings: ratingsCount,
            sold: _totalSold,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _description(description),
          ],
        ],
      ),
    );
  }

  Widget _statsCard({
    required int products,
    required int ratings,
    required int sold,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.statsBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.statsBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: _stat('Products', '$products')),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: _C.statsBorder,
            ),
            Expanded(child: _stat('Ratings', '$ratings')),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: _C.statsBorder,
            ),
            Expanded(child: _stat('Total sold', '$sold')),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _C.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _C.plumMid,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _description(String text) {
    return _AboutShop(text: text);
  }

  // ── Products ──────────────────────────────────────────────────────────────
  Widget _content() {
    final searching = _search.isNotEmpty;

    return RefreshIndicator(
      color: _C.plum,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        children: [
          _shopHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoCard(),
                const SizedBox(height: 20),
                const Text(
                  'Products from this shop',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.plum,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _showingLine(searching: searching),
                  style: const TextStyle(fontSize: 12, color: _C.muted),
                ),
                const SizedBox(height: 10),
                _filters(),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: _C.plum),
                    ),
                  )
                else if (_total == 0)
                  _emptyState(searching: searching)
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 10.0;
                      final width = (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: _products
                            .map(
                              (product) => SizedBox(
                                width: width,
                                child: _ShopProductCard(
                                  product: product,
                                  saved: _saved.contains(product.id),
                                  onTap: () => _openProduct(product),
                                  onToggleSaved: () => _toggleSaved(product),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                if (!_loading && _total > 0 && _page < _lastPage) ...[
                  const SizedBox(height: 14),
                  if (_moreError != null) ...[
                    Text(
                      _moreError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: _C.muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _C.plumMid,
                        backgroundColor: _C.white,
                        side: const BorderSide(color: _C.plumSoft),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        _loadingMore ? 'Loading…' : 'Load more products',
                        style: const TextStyle(fontSize: 13),
                      ),
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

  String _showingLine({required bool searching}) {
    final suffix = searching ? ' for “$_search”' : '';
    if (_total == 0) {
      return searching ? 'No products$suffix' : 'No products';
    }
    final from = (_page - 1) * _perPage + 1;
    final to = from + _products.length - 1;
    return 'Showing $from–$to of $_total '
        '${_total == 1 ? 'product' : 'products'}$suffix';
  }

  Widget _filters() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 38,
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DCE7)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _sort,
            isExpanded: true,
            isDense: true,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: _C.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: _C.muted,
            ),
            style: const TextStyle(fontSize: 12, color: _C.ink),
            onChanged: (value) {
              if (value == null || value == _sort) return;
              _applyFilters(sort: value);
            },
            items: _sortLabels.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: _C.ink),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// Rounded border for the search box in the header.
  OutlineInputBorder _fieldBorder({bool focused = false}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: BorderSide(
      color: focused ? const Color(0x99FFFFFF) : const Color(0x2EFFFFFF),
    ),
  );

  Widget _emptyState({required bool searching}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: [
          Icon(
            searching ? Icons.search_rounded : Icons.storefront_outlined,
            size: 38,
            color: _C.plumSoft,
          ),
          const SizedBox(height: 10),
          Text(
            searching
                ? 'No products match “$_search”'
                : 'This shop has no products yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _C.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            searching
                ? 'Try a shorter word, or clear the search to see everything this shop sells.'
                : 'Check back later, or browse products from other shops.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: _C.muted,
              height: 1.5,
            ),
          ),
          if (searching) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: FilledButton(
                onPressed: () {
                  _searchCtrl.clear();
                  _applyFilters(search: '');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _C.plum,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Show all products',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
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
            const Icon(Icons.storefront_outlined, size: 44, color: _C.plumSoft),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.ink),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _C.plum),
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
// Shop header pieces
// ─────────────────────────────────────────────────────────────────────────────

/// Round shop photo; falls back to the first letter of the shop name.
class _Avatar extends StatelessWidget {
  final String? url;
  final String initial;

  const _Avatar({required this.url, required this.initial});

  @override
  Widget build(BuildContext context) {
    final letter = initial.isEmpty
        ? 'S'
        : initial.substring(0, 1).toUpperCase();
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _C.plumSoft,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x99FFFFFF), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _letter(letter),
            )
          : _letter(letter),
    );
  }

  Widget _letter(String letter) => Center(
    child: Text(
      letter,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// "About this shop", clamped to three lines until the buyer asks for more.
class _AboutShop extends StatefulWidget {
  final String text;

  const _AboutShop({required this.text});

  @override
  State<_AboutShop> createState() => _AboutShopState();
}

class _AboutShopState extends State<_AboutShop> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About this shop',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _C.plum,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.text,
          maxLines: _open ? null : 3,
          overflow: _open ? TextOverflow.clip : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.6,
            color: Color(0xFF3D2A42),
          ),
        ),
        if (widget.text.length > 220)
          TextButton(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(
              foregroundColor: _C.plumSoft,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _open ? 'Show less' : 'Read more',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product card — the web shop page's card (buyer.partials.product-card)
// ─────────────────────────────────────────────────────────────────────────────

class _ShopProductCard extends StatelessWidget {
  final ApiProduct product;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  const _ShopProductCard({
    required this.product,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final compareAt = p.compareAtPrice;
    final discount = p.discountPercent > 0 && !p.soldOut
        ? p.discountPercent
        : 0;
    final rating = p.rating;
    final sold = p.sold;

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
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      p.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF8F3E6),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF9B8EA6),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _C.plum,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  if (p.soldOut)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.65),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _C.ink.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Sold out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: onToggleSaved,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: saved
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _C.ink.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          saved ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: saved ? _C.heart : _C.plumSoft,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 34),
                    child: Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: _C.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 16,
                    child: Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: _C.gold,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _C.ink,
                            ),
                          ),
                        ],
                        if (sold > 0)
                          Text(
                            rating != null ? ' | $sold sold' : '$sold sold',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _C.mutedGray,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: p.price,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _C.plumMid,
                            height: 1.3,
                          ),
                        ),
                        if (compareAt != null && compareAt.isNotEmpty)
                          TextSpan(
                            text: '  $compareAt',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C7A8E),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Color(0xFF8C7A8E),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: p.soldOut
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _C.outBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Out of stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _C.outInk,
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _C.white,
                              foregroundColor: _C.plumMid,
                              padding: EdgeInsets.zero,
                              side: const BorderSide(color: _C.plumSoft),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: const Text(
                              'View product',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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