import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/offline/offline_store.dart';

class BuyerApiException implements Exception {
  const BuyerApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Orders from the cache, with the time they were saved on the device.
class CachedOrders {
  const CachedOrders({
    required this.items,
    required this.cachedAt,
    this.tabs = const [],
  });

  final List<ApiOrder> items;
  final List<ApiOrderTab> tabs;
  final DateTime cachedAt;
}

/// One order's detail page from the cache.
class CachedOrderDetail {
  const CachedOrderDetail({required this.detail, required this.cachedAt});

  final ApiOrderDetail detail;
  final DateTime cachedAt;
}

/// Notifications from the cache.
class CachedNotifications {
  const CachedNotifications({required this.items, required this.cachedAt});

  final List<ApiNotification> items;
  final DateTime cachedAt;
}

/// One page of the signed-in Buyer's notifications, plus the unread total.
class ApiNotificationFeed {
  const ApiNotificationFeed({required this.items, required this.unreadCount});

  final List<ApiNotification> items;
  final int unreadCount;
}

/// What happened when the offline outbox was flushed back to Vendo.
class OfflineSyncReport {
  const OfflineSyncReport({
    required this.synced,
    required this.failed,
    required this.messages,
  });

  final int synced;
  final int failed;
  final List<String> messages;

  bool get hasFailures => failed > 0;
}

class BuyerApi {
  BuyerApi._();

  static final BuyerApi instance = BuyerApi._();

  /// Units currently in the buyer's cart, kept up to date by every cart call so
  /// badges (like the home header) never have to guess.
  static final ValueNotifier<int> cartItemCount = ValueNotifier<int>(0);

  static String get baseUrl {
    const configured = String.fromEnvironment('VENDO_BUYER_API_BASE_URL');
    if (configured.isNotEmpty)
      return configured.replaceFirst(RegExp(r'/+$'), '');
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000/api/v1/buyer';
    }
    if (kDebugMode) {
      return 'http://192.168.1.41:8000/api/v1/buyer';
    }
    return 'https://vendo-ph.app/api/v1/buyer';
  }

  static const _storage = FlutterSecureStorage();

  /// Shared HTTP client. Tests swap it with [useClient].
  http.Client _client = http.Client();

  /// Test hook: supplies the bearer token without the platform keychain.
  @visibleForTesting
  String? debugToken;

  @visibleForTesting
  void useClient(http.Client client) => _client = client;

  static String _ordersKey(String? tab) =>
      'offline:orders:${tab == null || tab.isEmpty ? 'all' : tab}';
  static String _orderKey(int id) => 'offline:order:$id';
  static const String _notificationsKey = 'offline:notifications';

  // ── Token helpers ──────────────────────────────────────────────────────────
  Future<bool> hasToken() async =>
      (await _storage.read(key: 'buyer_token')) != null;
  Future<String?> buyerName() => _storage.read(key: 'buyer_name');
  Future<String?> buyerEmail() => _storage.read(key: 'buyer_email');
  Future<String?> buyerAvatar() => _storage.read(key: 'buyer_avatar');

  Future<void> clearSession() async {
    await _storage.deleteAll();
    cartItemCount.value = 0;
  }

  // ── OTP ────────────────────────────────────────────────────────────────────
  Future<void> sendOtp(String email) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/send'),
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    _check(response);
  }

  /// Returns the verification_token string on success.
  Future<String> verifyOtp(String email, String code) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/email/otp/verify'),
          headers: _jsonHeaders(),
          body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
        )
        .timeout(const Duration(seconds: 20));
    return _check(response)['verification_token'] as String;
  }

  // ── Registration ───────────────────────────────────────────────────────────
  Future<void> register({
    required Map<String, String> fields,
    required String validIdPath,
    String? validId2Path,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/register'),
    );
    request.headers['Accept'] = 'application/json';
    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath('valid_id', validIdPath),
    );
    if (validId2Path != null) {
      request.files.add(
        await http.MultipartFile.fromPath('valid_id_2', validId2Path),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    _check(await http.Response.fromStream(streamed));
  }

  // ── Login / logout ─────────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'device_name': 'Vendo Buyer mobile',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _check(response);
    await _saveLogin(data);
  }

  /// Signs in with a Google ID token. The API verifies the token and returns
  /// the same session as [login]; a Google email with no Buyer account returns
  /// `registration_required` with the data the registration form needs.
  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/google'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'credential': idToken,
            'device_name': 'Vendo Buyer mobile',
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _check(response);
    if (data['registration_required'] == true) return data;
    await _saveLogin(data);
    return data;
  }

  Future<void> logout() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/logout'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 20));
      _check(response);
    } finally {
      await _storage.deleteAll();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final response = await http
        .get(Uri.parse('$baseUrl/me'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    return _check(response);
  }

  // ── Storefront ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> home() async {
    final response = await http
        .get(Uri.parse('$baseUrl/home'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _check(response);
  }

  /// Every top-level category with its subcategories — the same rows the web
  /// Categories page lists, so both sides show the same catalogue.
  Future<List<ApiCategory>> categories() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/categories'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['categories'] as List? ?? [])
        .map((e) => ApiCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ApiProduct>> products({
    int? categoryId,
    String? search,
    int page = 1,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (categoryId != null) query['category_id'] = '$categoryId';
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ApiProductDetail> product(int id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/products/$id'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiProductDetail.fromJson(_check(response));
  }

  Future<List<ApiSeller>> sellers({String? search}) async {
    final uri = Uri.parse('$baseUrl/sellers').replace(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map((e) => ApiSeller.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> seller(
    int id, {
    String? search,
    String sort = 'latest',
    int page = 1,
  }) async {
    final query = <String, String>{'sort': sort, 'page': '$page'};
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();
    final uri = Uri.parse(
      '$baseUrl/sellers/$id',
    ).replace(queryParameters: query);
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _check(response);
  }

  // ── Seller chat ────────────────────────────────────────────────────────────
  /// One chat thread: a shop chat when only [sellerId] is set, else the chat
  /// pinned to [orderId]. Both are the threads the web chat page reads.
  Future<ApiChatThread> chatThread({int? sellerId, int? orderId}) async {
    final response = await _client
        .get(
          Uri.parse(_chatPath(sellerId: sellerId, orderId: orderId)),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return ApiChatThread.fromJson(_check(response));
  }

  /// Messages that arrived after [after], for the chat's short poll.
  Future<List<ApiChatMessage>> chatNewMessages({
    int? sellerId,
    int? orderId,
    required int after,
  }) async {
    final uri = Uri.parse(
      '${_chatPath(sellerId: sellerId, orderId: orderId)}/fetch',
    ).replace(queryParameters: {'after': '$after'});
    final response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['messages'] as List? ?? [])
        .map(
          (e) => ApiChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Sends a message, a photo, a shared order or any mix of them. The same
  /// request the web chat form posts, so either side sees it.
  Future<void> sendChatMessage({
    int? sellerId,
    int? orderId,
    String body = '',
    String? attachmentPath,
    int? sharedOrderId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_chatPath(sellerId: sellerId, orderId: orderId)),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${await _token()}';
    if (body.trim().isNotEmpty) request.fields['body'] = body.trim();
    if (sharedOrderId != null)
      request.fields['shared_order_id'] = '$sharedOrderId';
    if (attachmentPath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('attachment', attachmentPath),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    _check(await http.Response.fromStream(streamed));
  }

  /// Chat photos and delivery proofs are private, so the app sends its token
  /// when it loads one.
  Future<Map<String, String>> mediaHeaders() async => {
    'Authorization': 'Bearer ${await _token()}',
  };

  /// The rider's delivery photo for this order (bearer token required).
  String orderDeliveryProofUrl(int id) => '$baseUrl/orders/$id/delivery-proof';

  String _chatPath({int? sellerId, int? orderId}) => orderId != null
      ? '$baseUrl/messages/orders/$orderId'
      : '$baseUrl/messages/sellers/$sellerId';

  // ── Saved items ────────────────────────────────────────────────────────────
  Future<List<ApiProduct>> savedItems() async {
    final response = await http
        .get(Uri.parse('$baseUrl/saved-items'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _products(_check(response));
  }

  Future<List<ApiProduct>> saveItem(int productId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/saved-items/$productId'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return _products(_check(response));
  }

  Future<List<ApiProduct>> removeSavedItem(int productId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/saved-items/$productId'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return _products(_check(response));
  }

  // ── Cart ───────────────────────────────────────────────────────────────────
  Future<ApiCart> cart() async {
    final response = await http
        .get(Uri.parse('$baseUrl/cart'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _trackCart(ApiCart.fromJson(_check(response)));
  }

  /// Publishes the cart's unit count before handing the payload back.
  ApiCart _trackCart(ApiCart cart) {
    cartItemCount.value = cart.itemCount;
    return cart;
  }

  Future<ApiCart> addToCart({
    required int productId,
    int quantity = 1,
    String? color,
    String? size,
    int? variantId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/cart'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'product_id': productId,
            'quantity': quantity,
            if (color != null) 'color': color,
            if (size != null) 'size': size,
            if (variantId != null) 'variant_id': variantId,
          }),
        )
        .timeout(const Duration(seconds: 25));
    return _trackCart(ApiCart.fromJson(_check(response)));
  }

  Future<ApiCart> updateCartLine(int itemId, int quantity) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/cart/$itemId'),
          headers: await _authHeaders(),
          body: jsonEncode({'quantity': quantity}),
        )
        .timeout(const Duration(seconds: 25));
    return _trackCart(ApiCart.fromJson(_check(response)));
  }

  Future<ApiCart> removeCartLine(int itemId) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/cart/$itemId'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return _trackCart(ApiCart.fromJson(_check(response)));
  }

  // ── Checkout ───────────────────────────────────────────────────────────────
  Future<ApiCheckoutPreview> checkoutPreview(List<int> itemIds) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/checkout/preview'),
          headers: await _authHeaders(),
          body: jsonEncode({'items': itemIds}),
        )
        .timeout(const Duration(seconds: 30));
    return ApiCheckoutPreview.fromJson(_check(response));
  }

  Future<ApiShippingQuote> shippingQuote(
    List<int> itemIds,
    String provinceCode,
    String cityCode,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/checkout/shipping-quote'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'items': itemIds,
            'shipping_province_code': provinceCode,
            'shipping_city_code': cityCode,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final data = _check(response);
    final quotes = Map<String, dynamic>.from(
      (data['quotes'] as Map?) ?? const {},
    );
    final perSeller = <int, double>{};
    final perSellerLabel = <int, String>{};
    final selected = <int, ApiShippingOption>{};
    final options = <int, List<ApiShippingOption>>{};
    quotes.forEach((key, value) {
      final row = Map<String, dynamic>.from(value as Map);
      final sellerId = int.parse(key);
      perSeller[sellerId] =
          double.tryParse(row['shipping_fee']?.toString() ?? '') ?? 0;
      perSellerLabel[sellerId] = row['shipping_fee_label']?.toString() ?? '';

      final list = (row['options'] as List? ?? [])
          .map(
            (e) =>
                ApiShippingOption.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      if (list.isNotEmpty) options[sellerId] = list;

      // The server picks the Buyer's saved Company (or the cheapest) first.
      final chosenId = int.tryParse('${row['company_id'] ?? ''}') ?? 0;
      ApiShippingOption? pick;
      for (final option in list) {
        if (option.companyId == chosenId) pick = option;
      }
      pick ??= list.isEmpty ? null : list.first;
      if (pick != null) selected[sellerId] = pick;
    });
    return ApiShippingQuote(
      total: double.tryParse(data['shipping_total']?.toString() ?? '') ?? 0,
      totalLabel: data['shipping_total_label']?.toString() ?? '',
      perSeller: perSeller,
      perSellerLabel: perSellerLabel,
      selected: selected,
      options: options,
    );
  }

  /// Checks one shop's voucher codes (up to two stacked) against the same
  /// service the web checkout applies, so the discount matches there.
  Future<ApiVoucherQuote> voucherQuote(
    List<int> itemIds,
    int sellerId,
    List<String> codes,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/checkout/voucher-quote'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'items': itemIds,
            'seller_id': sellerId,
            'codes': codes,
          }),
        )
        .timeout(const Duration(seconds: 25));
    return ApiVoucherQuote.fromJson(_check(response));
  }

  Future<List<ApiProvince>> locations() async {
    final response = await http
        .get(Uri.parse('$baseUrl/locations'), headers: _jsonHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['provinces'] as List? ?? [])
        .map((e) => ApiProvince.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ApiBarangay>> barangays(String cityCode) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/locations/$cityCode/barangays'),
          headers: _jsonHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['barangays'] as List? ?? [])
        .map((e) => ApiBarangay.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ApiGeoMapConfig> geoConfig() async {
    final response = await http
        .get(Uri.parse('$baseUrl/geo/config'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiGeoMapConfig.fromJson(_check(response));
  }

  /// Place search for the pin picker (Philippines only, up to five matches).
  Future<List<ApiGeoPlace>> geoSearch(String query) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/geo/search',
          ).replace(queryParameters: {'q': query}),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['results'] as List? ?? [])
        .map((e) => ApiGeoPlace.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// The address at a pin. Null when Geoapify has no address for the point.
  Future<ApiGeoPlace?> geoReverse(double latitude, double longitude) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/geo/reverse').replace(
            queryParameters: {
              'lat': latitude.toString(),
              'lng': longitude.toString(),
            },
          ),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 422) return null;
    final data = _check(response);
    final result = data['result'];
    if (result is! Map) return null;
    return ApiGeoPlace.fromJson(Map<String, dynamic>.from(result));
  }

  Future<List<ApiOrder>> placeOrder({
    required List<int> itemIds,
    required String shippingAddress,
    required String provinceCode,
    required String cityCode,
    required String checkoutRevision,
    int? shippingAddressId,
    double? shippingLatitude,
    double? shippingLongitude,
    Map<String, String> sellerNotes = const {},
    Map<int, List<String>> voucherCodes = const {},
    Map<int, String> shippingQuotes = const {},
    Map<int, int> logisticsCompanyIds = const {},
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/checkout'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'items': itemIds,
            'shipping_address': shippingAddress,
            'shipping_province_code': provinceCode,
            'shipping_city_code': cityCode,
            'payment_mode': 'cod',
            'checkout_revision': checkoutRevision,
            if (shippingAddressId != null)
              'shipping_address_id': shippingAddressId,
            if (shippingLatitude != null && shippingLongitude != null) ...{
              'shipping_latitude': shippingLatitude,
              'shipping_longitude': shippingLongitude,
            },
            if (shippingQuotes.isNotEmpty)
              'shipping_quotes': {
                for (final entry in shippingQuotes.entries)
                  '${entry.key}': entry.value,
              },
            if (logisticsCompanyIds.isNotEmpty)
              'logistics_company_ids': {
                for (final entry in logisticsCompanyIds.entries)
                  '${entry.key}': entry.value,
              },
            if (sellerNotes.isNotEmpty) 'seller_notes': sellerNotes,
            if (voucherCodes.isNotEmpty)
              'voucher_codes': {
                for (final entry in voucherCodes.entries)
                  '${entry.key}': entry.value,
              },
          }),
        )
        .timeout(const Duration(seconds: 45));
    final data = _check(response);
    return (data['orders'] as List? ?? [])
        .map((e) => ApiOrder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  /// One tab of the Buyer's orders (`all`, `placed`, `to_ship`, `in_transit`,
  /// `delivered`, `returns`, `cancelled`) plus the counts for every tab.
  /// Pages 2+ only fetch; the first page is also the copy kept for offline use.
  Future<ApiOrdersPage> orders({String? tab, int page = 1}) async {
    final uri = Uri.parse('$baseUrl/orders').replace(
      queryParameters: {
        if (tab != null && tab.isNotEmpty) 'tab': tab,
        if (page > 1) 'page': '$page',
      },
    );
    final response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    final meta = data['meta'] is Map
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : const <String, dynamic>{};
    // Keep the newest list on the device so orders survive a bad signal.
    if (page <= 1) {
      await OfflineStore.instance.cacheJson(_ordersKey(tab), data);
    }
    return ApiOrdersPage(
      orders: _orders(data),
      tabs: ApiOrderTab.list(data['tabs']),
      page: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// The last order list this device saw, when the API cannot be reached.
  Future<CachedOrders?> cachedOrders({String? tab}) async {
    final cached = await OfflineStore.instance.readJson(_ordersKey(tab));
    if (cached == null) return null;
    return CachedOrders(
      items: _orders(cached.payload),
      tabs: ApiOrderTab.list(cached.payload['tabs']),
      cachedAt: cached.cachedAt,
    );
  }

  Future<ApiOrderDetail> order(int id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/orders/$id'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    await OfflineStore.instance.cacheJson(_orderKey(id), data);
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(data['order'] as Map),
    );
  }

  /// The last copy of this order saved on the device, for tracking offline.
  Future<CachedOrderDetail?> cachedOrder(int id) async {
    final cached = await OfflineStore.instance.readJson(_orderKey(id));
    if (cached == null) return null;
    final order = cached.payload['order'];
    if (order is! Map) return null;
    return CachedOrderDetail(
      detail: ApiOrderDetail.fromJson(Map<String, dynamic>.from(order)),
      cachedAt: cached.cachedAt,
    );
  }

  Future<ApiOrderDetail> cancelOrder(
    int id,
    String expectedStatus,
    String reason, {
    String? details,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/orders/$id/cancel'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'expected_status': expectedStatus,
            'reason': reason,
            if (details != null && details.isNotEmpty)
              'reason_details': details,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(_check(response)['order'] as Map),
    );
  }

  Future<ApiOrderDetail> completeOrder(int id) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/orders/$id/complete'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 30));
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(_check(response)['order'] as Map),
    );
  }

  /// Asks the seller to take a delivered order back. The web return form posts the
  /// same reason/details to `OrderReturnService`.
  Future<ApiOrderDetail> requestOrderReturn(
    int id,
    String reason, {
    String? details,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/orders/$id/return'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'reason': reason,
            if (details != null && details.isNotEmpty) 'details': details,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(_check(response)['order'] as Map),
    );
  }

  Future<void> reviewOrderItem(
    int orderItemId,
    int rating,
    String comment,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/order-items/$orderItemId/review'),
          headers: await _authHeaders(),
          body: jsonEncode({'rating': rating, 'comment': comment}),
        )
        .timeout(const Duration(seconds: 30));
    _check(response);
  }

  // ── Notifications and account ──────────────────────────────────────────────
  /// The Buyer's newest notifications plus the unread total.
  ///
  /// These are the rows the web buyer page reads, so anything created or read
  /// on either side is visible here after the next refresh. [unreadOnly] maps
  /// to the API's `filter=unread`.
  Future<ApiNotificationFeed> notifications({bool unreadOnly = false}) async {
    final response = await _client
        .get(
          Uri.parse(
            '$baseUrl/notifications${unreadOnly ? '?filter=unread' : ''}',
          ),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    // Only the unfiltered page is worth keeping for offline reading.
    if (!unreadOnly) {
      await OfflineStore.instance.cacheJson(_notificationsKey, data);
    }
    return ApiNotificationFeed(
      items: _notifications(data),
      unreadCount: _unreadCount(data),
    );
  }

  /// Marks one notification read. The web buyer page reads the same row, so it
  /// stops counting as new there too.
  Future<int> markNotificationRead(int id) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/notifications/$id/read'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    return _unreadCount(_check(response));
  }

  /// The last notifications list saved on this device.
  Future<CachedNotifications?> cachedNotifications() async {
    final cached = await OfflineStore.instance.readJson(_notificationsKey);
    if (cached == null) return null;
    return CachedNotifications(
      items: _notifications(cached.payload),
      cachedAt: cached.cachedAt,
    );
  }

  Future<void> markAllNotificationsRead() async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/notifications/read-all'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 25));
    _check(response);
  }

  /// Keeps "mark all read" on the device until Vendo can be reached.
  Future<void> queueMarkAllNotificationsReadOffline() =>
      OfflineStore.instance.enqueue(kind: 'notifications_read_all');

  Future<int> pendingOfflineActions() => OfflineStore.instance.pendingCount();

  /// Uploads everything the Buyer saved while offline.
  ///
  /// Stops early when the connection is still down, keeps the queue for the
  /// next attempt, and drops entries the server can no longer accept so one
  /// stale action never blocks the rest.
  Future<OfflineSyncReport> syncOfflineActions() async {
    final actions = await OfflineStore.instance.pendingActions();
    var synced = 0;
    var failed = 0;
    final messages = <String>[];

    for (final action in actions) {
      final id = '${action['id'] ?? ''}';
      final kind = '${action['kind'] ?? ''}';
      try {
        if (kind != 'notifications_read_all') {
          await OfflineStore.instance.removeAction(id);
          continue;
        }
        await markAllNotificationsRead();
        await OfflineStore.instance.removeAction(id);
        synced++;
      } on BuyerApiException catch (error) {
        final code = error.statusCode ?? 0;
        if (code == 401 || code == 403) {
          messages.add(error.message);
          break;
        }
        if (code >= 400 && code < 500) {
          await OfflineStore.instance.removeAction(id);
          failed++;
          messages.add(error.message);
          continue;
        }
        failed++;
        messages.add(error.message);
      } catch (_) {
        // Still offline: keep this and everything after it queued.
        failed++;
        break;
      }
    }

    return OfflineSyncReport(
      synced: synced,
      failed: failed,
      messages: messages,
    );
  }

  Future<ApiBuyer> account() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/account'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _buyer(_check(response));
  }

  /// Saves the profile fields the app sends. Address fields stay untouched
  /// unless they are part of this call, so the two profile screens never
  /// overwrite each other. The same record is what the web account page reads.
  Future<ApiBuyer> updateAccount({
    required String name,
    String? phone,
    String? province,
    String? municipality,
    String? barangay,
    String? street,
    String? houseNo,
    String? zipCode,
  }) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/account'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'name': name,
            if (phone != null) 'phone_number': phone,
            if (province != null) 'province': province,
            if (municipality != null) 'municipality': municipality,
            if (barangay != null) 'barangay': barangay,
            if (street != null) 'street': street,
            if (houseNo != null) 'house_no': houseNo,
            if (zipCode != null) 'zip_code': zipCode,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return _buyer(_check(response));
  }

  /// Replaces the profile picture shown on both the app and the web account page.
  Future<ApiBuyer> uploadProfilePhoto(String path) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/account/photo'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${await _token()}';
    request.files.add(
      await http.MultipartFile.fromPath('profile_picture', path),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    return _buyer(_check(await http.Response.fromStream(streamed)));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/account/password'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'current_password': currentPassword,
            'password': password,
            'password_confirmation': passwordConfirmation,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _check(response);
  }

  // ── My Vouchers and My Reviews ────────────────────────────────────────────
  Future<List<ApiShopVoucher>> vouchers() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/vouchers'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map(
          (e) => ApiShopVoucher.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<ApiReview>> reviews() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/reviews'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map((e) => ApiReview.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Support and legal ─────────────────────────────────────────────────────
  Future<ApiFaqPage> help() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/help'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiFaqPage.fromJson(_check(response));
  }

  /// [page] is `terms` or `privacy`; the server reads the same docs the web serves.
  Future<ApiContentPage> legal(String page) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/legal/$page'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiContentPage.fromJson(_check(response));
  }

  /// The app rating stays on this device; signing out clears it with the session.
  Future<int?> appRating() async {
    final raw = await _storage.read(key: 'buyer_app_rating');
    return int.tryParse(raw ?? '');
  }

  Future<String?> appRatingComment() =>
      _storage.read(key: 'buyer_app_rating_comment');

  Future<void> saveAppRating(int rating, String comment) async {
    await _storage.write(key: 'buyer_app_rating', value: '$rating');
    await _storage.write(
      key: 'buyer_app_rating_comment',
      value: comment.trim(),
    );
  }

  List<ApiProduct> _products(Map<String, dynamic> data) =>
      (data['items'] as List? ?? [])
          .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  List<ApiOrder> _orders(Map<String, dynamic> data) =>
      (data['data'] as List? ?? [])
          .map((e) => ApiOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  List<ApiNotification> _notifications(Map<String, dynamic> data) =>
      (data['data'] as List? ?? [])
          .map(
            (e) =>
                ApiNotification.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

  int _unreadCount(Map<String, dynamic> data) {
    final value = data['unread_count'];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  Future<void> _saveLogin(Map<String, dynamic> data) async {
    await _storage.write(key: 'buyer_token', value: data['token'] as String);
    final buyer = data['buyer'] as Map<String, dynamic>;
    await _storage.write(key: 'buyer_name', value: buyer['name']?.toString());
    await _storage.write(key: 'buyer_email', value: buyer['email']?.toString());
    await _storage.write(
      key: 'buyer_avatar',
      value: buyer['profile_picture']?.toString(),
    );
  }

  /// Reads a buyer payload, and keeps the locally cached name, email and photo
  /// in step so the profile header is right even before the next request.
  Future<ApiBuyer> _buyer(Map<String, dynamic> data) async {
    final buyer = ApiBuyer.fromJson(
      Map<String, dynamic>.from(data['buyer'] as Map),
    );
    await _storage.write(key: 'buyer_name', value: buyer.name);
    await _storage.write(key: 'buyer_email', value: buyer.email);
    if (buyer.profilePicture != null) {
      await _storage.write(key: 'buyer_avatar', value: buyer.profilePicture);
    }
    return buyer;
  }

  Map<String, String> _jsonHeaders() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<String> _token() async {
    final token = debugToken ?? await _storage.read(key: 'buyer_token');
    if (token == null)
      throw const BuyerApiException('Please sign in again.', 401);
    return token;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _token();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _check(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw BuyerApiException(
        'HTTP ${response.statusCode}. Check that the Vendo API server is running.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 400) {
      final errors = data['errors'];
      final detail = errors is Map && errors.isNotEmpty
          ? (errors.values.first as List).first.toString()
          : (data['message']?.toString() ??
                'Request failed. Please try again.');
      throw BuyerApiException(detail, response.statusCode);
    }
    return data;
  }
}
