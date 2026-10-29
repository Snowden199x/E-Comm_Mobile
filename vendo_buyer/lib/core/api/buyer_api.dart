import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:vendo_buyer/core/api/api_models.dart';

class BuyerApiException implements Exception {
  const BuyerApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BuyerApi {
  BuyerApi._();

  static final BuyerApi instance = BuyerApi._();

  static String get baseUrl {
    const configured = String.fromEnvironment('VENDO_BUYER_API_BASE_URL');
    if (configured.isNotEmpty)
      return configured.replaceFirst(RegExp(r'/+$'), '');
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.linux) {
      return 'http://127.0.0.1:8000/api/v1/buyer';
    }
    return 'https://vendo-ph.app/api/v1/buyer';
  }

  static const _storage = FlutterSecureStorage();

  // ── Token helpers ──────────────────────────────────────────────────────────
  Future<bool> hasToken() async =>
      (await _storage.read(key: 'buyer_token')) != null;
  Future<String?> buyerName() => _storage.read(key: 'buyer_name');
  Future<String?> buyerEmail() => _storage.read(key: 'buyer_email');

  Future<void> clearSession() => _storage.deleteAll();

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

  Future<List<ApiProduct>> products({
    int? categoryId,
    String? search,
    int page = 1,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (categoryId != null) query['category_id'] = '$categoryId';
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
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
    final uri = Uri.parse('$baseUrl/sellers').replace(queryParameters: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    });
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map((e) => ApiSeller.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> seller(int id, {String? search, String sort = 'latest'}) async {
    final query = <String, String>{'sort': sort};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    final uri = Uri.parse('$baseUrl/sellers/$id').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _check(response);
  }

  // ── Saved items ────────────────────────────────────────────────────────────
  Future<List<ApiProduct>> savedItems() async {
    final response = await http
        .get(Uri.parse('$baseUrl/saved-items'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _products(_check(response));
  }

  Future<List<ApiProduct>> saveItem(int productId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/saved-items/$productId'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _products(_check(response));
  }

  Future<List<ApiProduct>> removeSavedItem(int productId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/saved-items/$productId'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return _products(_check(response));
  }

  // ── Cart ───────────────────────────────────────────────────────────────────
  Future<ApiCart> cart() async {
    final response = await http
        .get(Uri.parse('$baseUrl/cart'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiCart.fromJson(_check(response));
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
    return ApiCart.fromJson(_check(response));
  }

  Future<ApiCart> updateCartLine(int itemId, int quantity) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl/cart/$itemId'),
          headers: await _authHeaders(),
          body: jsonEncode({'quantity': quantity}),
        )
        .timeout(const Duration(seconds: 25));
    return ApiCart.fromJson(_check(response));
  }

  Future<ApiCart> removeCartLine(int itemId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/cart/$itemId'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiCart.fromJson(_check(response));
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
    final quotes = Map<String, dynamic>.from((data['quotes'] as Map?) ?? const {});
    final perSeller = <int, double>{};
    final perSellerLabel = <int, String>{};
    quotes.forEach((key, value) {
      final row = Map<String, dynamic>.from(value as Map);
      perSeller[int.parse(key)] =
          double.tryParse(row['shipping_fee']?.toString() ?? '') ?? 0;
      perSellerLabel[int.parse(key)] = row['shipping_fee_label']?.toString() ?? '';
    });
    return ApiShippingQuote(
      total: double.tryParse(data['shipping_total']?.toString() ?? '') ?? 0,
      totalLabel: data['shipping_total_label']?.toString() ?? '',
      perSeller: perSeller,
      perSellerLabel: perSellerLabel,
    );
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

  Future<List<ApiOrder>> placeOrder({
    required List<int> itemIds,
    required String shippingAddress,
    required String provinceCode,
    required String cityCode,
    required String checkoutRevision,
    Map<String, String> sellerNotes = const {},
    Map<String, String> voucherCodes = const {},
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
            if (sellerNotes.isNotEmpty) 'seller_notes': sellerNotes,
            if (voucherCodes.isNotEmpty) 'voucher_codes': voucherCodes,
          }),
        )
        .timeout(const Duration(seconds: 45));
    final data = _check(response);
    return (data['orders'] as List? ?? [])
        .map((e) => ApiOrder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────
  Future<List<ApiOrder>> orders({String? status}) async {
    final uri = Uri.parse('$baseUrl/orders').replace(queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map((e) => ApiOrder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ApiOrderDetail> order(int id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/orders/$id'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(_check(response)['order'] as Map),
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
            if (details != null && details.isNotEmpty) 'reason_details': details,
          }),
        )
        .timeout(const Duration(seconds: 30));
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(_check(response)['order'] as Map),
    );
  }

  Future<ApiOrderDetail> completeOrder(int id) async {
    final response = await http
        .post(Uri.parse('$baseUrl/orders/$id/complete'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 30));
    return ApiOrderDetail.fromJson(
      Map<String, dynamic>.from(_check(response)['order'] as Map),
    );
  }

  Future<void> reviewOrderItem(int orderItemId, int rating, String comment) async {
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
  Future<List<ApiNotification>> notifications() async {
    final response = await http
        .get(Uri.parse('$baseUrl/notifications'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    final data = _check(response);
    return (data['data'] as List? ?? [])
        .map((e) => ApiNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markAllNotificationsRead() async {
    final response = await http
        .post(Uri.parse('$baseUrl/notifications/read-all'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    _check(response);
  }

  Future<ApiBuyer> account() async {
    final response = await http
        .get(Uri.parse('$baseUrl/account'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 25));
    return ApiBuyer.fromJson(
      Map<String, dynamic>.from(_check(response)['buyer'] as Map),
    );
  }

  List<ApiProduct> _products(Map<String, dynamic> data) =>
      (data['items'] as List? ?? [])
          .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  // ── Internal ───────────────────────────────────────────────────────────────
  Future<void> _saveLogin(Map<String, dynamic> data) async {
    await _storage.write(key: 'buyer_token', value: data['token'] as String);
    final buyer = data['buyer'] as Map<String, dynamic>;
    await _storage.write(key: 'buyer_name', value: buyer['name']?.toString());
    await _storage.write(key: 'buyer_email', value: buyer['email']?.toString());
  }

  Map<String, String> _jsonHeaders() => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: 'buyer_token');
    if (token == null)
      throw const BuyerApiException('Please sign in again.', 401);
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
