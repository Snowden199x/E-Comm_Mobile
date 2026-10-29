/// Typed views over the `/api/v1/buyer` JSON. Every field is optional-safe: the API always
/// sends the keys, but an older server build must not crash the app.
library;

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

bool _bool(dynamic value) => value == true || value == 1 || value == '1';

class ApiProduct {
  final int id;
  final String name;
  final String price;
  final double priceValue;
  final String? compareAtPrice;
  final int discountPercent;
  final String image;
  final String shop;
  final int shopId;
  final double? rating;
  final int sold;
  final int stock;
  final bool hasVariations;
  final List<String> colors;
  final List<String> sizes;
  final bool soldOut;

  const ApiProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.priceValue,
    required this.image,
    required this.shop,
    required this.shopId,
    required this.stock,
    this.compareAtPrice,
    this.discountPercent = 0,
    this.rating,
    this.sold = 0,
    this.hasVariations = false,
    this.colors = const [],
    this.sizes = const [],
    this.soldOut = false,
  });

  factory ApiProduct.fromJson(Map<String, dynamic> json) => ApiProduct(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    price: json['price']?.toString() ?? '',
    priceValue: _num(json['price_value']),
    compareAtPrice: json['compare_at_price']?.toString(),
    discountPercent: _int(json['discount_percent']),
    image: json['image']?.toString() ?? '',
    shop: json['shop']?.toString() ?? '',
    shopId: _int(json['shop_id']),
    rating: json['rating'] == null ? null : _num(json['rating']),
    sold: _int(json['sold']),
    stock: _int(json['stock']),
    hasVariations: _bool(json['has_variations']),
    colors: (json['colors'] as List?)?.map((e) => '$e').toList() ?? const [],
    sizes: (json['sizes'] as List?)?.map((e) => '$e').toList() ?? const [],
    soldOut: _bool(json['sold_out']),
  );
}

class ApiVariant {
  final int id;
  final String label;
  final String price;
  final double priceValue;
  final int stock;

  const ApiVariant({
    required this.id,
    required this.label,
    required this.price,
    required this.priceValue,
    required this.stock,
  });

  factory ApiVariant.fromJson(Map<String, dynamic> json) => ApiVariant(
    id: _int(json['id']),
    label: json['label']?.toString() ?? '',
    price: json['price']?.toString() ?? '',
    priceValue: _num(json['price_value']),
    stock: _int(json['stock']),
  );
}

class ApiSpec {
  final String name;
  final String value;
  const ApiSpec(this.name, this.value);
}

class ApiSeller {
  final int id;
  final String name;
  final String owner;
  final String? description;
  final String? province;
  final String? municipality;
  final double? rating;
  final int productsCount;

  const ApiSeller({
    required this.id,
    required this.name,
    required this.owner,
    this.description,
    this.province,
    this.municipality,
    this.rating,
    this.productsCount = 0,
  });

  factory ApiSeller.fromJson(Map<String, dynamic> json) => ApiSeller(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    owner: json['owner']?.toString() ?? '',
    description: json['description']?.toString(),
    province: json['province']?.toString(),
    municipality: json['municipality']?.toString(),
    rating: json['rating'] == null ? null : _num(json['rating']),
    productsCount: _int(json['products_count']),
  );
}

class ApiProductDetail {
  final ApiProduct product;
  final String? description;
  final String? category;
  final List<String> images;
  final List<ApiVariant> variants;
  final List<ApiSpec> specifications;
  final ApiSeller? seller;
  final List<ApiProduct> recommended;

  const ApiProductDetail({
    required this.product,
    required this.images,
    required this.variants,
    required this.specifications,
    this.description,
    this.category,
    this.seller,
    this.recommended = const [],
  });

  factory ApiProductDetail.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    return ApiProductDetail(
      product: ApiProduct.fromJson(product),
      description: product['description']?.toString(),
      category: product['category']?.toString(),
      images: (product['images'] as List?)?.map((e) => '$e').toList() ?? const [],
      variants: (product['variants'] as List? ?? [])
          .map((e) => ApiVariant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      specifications: (product['specifications'] as List? ?? [])
          .map((e) => ApiSpec('${e['name']}', '${e['value']}'))
          .toList(),
      seller: product['seller'] is Map
          ? ApiSeller.fromJson(Map<String, dynamic>.from(product['seller'] as Map))
          : null,
      recommended: (json['recommended'] as List? ?? [])
          .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class ApiCartLine {
  final int id;
  final int productId;
  final String name;
  final String image;
  final String unitPrice;
  final double unitPriceValue;
  final int quantity;
  final int stock;
  final String? color;
  final String? size;
  final int? variantId;
  final String? variantLabel;
  final String subtotal;
  final double subtotalValue;
  final int shopId;
  final String shop;

  const ApiCartLine({
    required this.id,
    required this.productId,
    required this.name,
    required this.image,
    required this.unitPrice,
    required this.unitPriceValue,
    required this.quantity,
    required this.stock,
    required this.subtotal,
    required this.subtotalValue,
    required this.shopId,
    required this.shop,
    this.color,
    this.size,
    this.variantId,
    this.variantLabel,
  });

  factory ApiCartLine.fromJson(Map<String, dynamic> json) => ApiCartLine(
    id: _int(json['id']),
    productId: _int(json['product_id']),
    name: json['name']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    unitPrice: json['unit_price']?.toString() ?? '',
    unitPriceValue: _num(json['unit_price_value']),
    quantity: _int(json['quantity']),
    stock: _int(json['stock']),
    color: json['color']?.toString(),
    size: json['size']?.toString(),
    variantId: json['variant_id'] == null ? null : _int(json['variant_id']),
    variantLabel: json['variant_label']?.toString(),
    subtotal: json['subtotal']?.toString() ?? '',
    subtotalValue: _num(json['subtotal_value']),
    shopId: _int(json['shop_id']),
    shop: json['shop']?.toString() ?? '',
  );

  String get variantText {
    final parts = [variantLabel, color, size]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .toList();
    return parts.join(' / ');
  }
}

class ApiCartShop {
  final int sellerId;
  final String shop;
  final List<ApiCartLine> items;
  final String subtotal;
  final double subtotalValue;

  const ApiCartShop({
    required this.sellerId,
    required this.shop,
    required this.items,
    required this.subtotal,
    required this.subtotalValue,
  });

  factory ApiCartShop.fromJson(Map<String, dynamic> json) => ApiCartShop(
    sellerId: _int(json['shop_id']),
    shop: json['shop']?.toString() ?? '',
    items: (json['items'] as List? ?? [])
        .map((e) => ApiCartLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    subtotal: json['subtotal']?.toString() ?? '',
    subtotalValue: _num(json['subtotal_value']),
  );
}

class ApiCart {
  final List<ApiCartLine> items;
  final List<ApiCartShop> shops;
  final List<ApiProduct> alsoLike;
  final int itemCount;
  final String subtotal;
  final double subtotalValue;

  const ApiCart({
    required this.items,
    required this.shops,
    required this.itemCount,
    required this.subtotal,
    required this.subtotalValue,
    this.alsoLike = const [],
  });

  factory ApiCart.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map?) ?? const {};
    return ApiCart(
      items: (json['items'] as List? ?? [])
          .map((e) => ApiCartLine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      shops: (json['groups'] as List? ?? [])
          .map((e) => ApiCartShop.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      alsoLike: (json['also_like'] as List? ?? [])
          .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      itemCount: _int(totals['items']),
      subtotal: totals['subtotal']?.toString() ?? '',
      subtotalValue: _num(totals['subtotal_value']),
    );
  }
}

class ApiOrder {
  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String shop;
  final int itemsCount;
  final String total;
  final String codAmount;
  final String shippingFee;
  final String image;
  final String? placedAtLabel;
  final bool canCancel;

  const ApiOrder({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.shop,
    required this.itemsCount,
    required this.total,
    required this.codAmount,
    required this.shippingFee,
    required this.image,
    this.placedAtLabel,
    this.canCancel = false,
  });

  factory ApiOrder.fromJson(Map<String, dynamic> json) => ApiOrder(
    id: _int(json['id']),
    number: json['number']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    statusLabel: json['status_label']?.toString() ?? '',
    shop: json['shop']?.toString() ?? '',
    itemsCount: _int(json['items_count']),
    total: json['total']?.toString() ?? '',
    codAmount: json['cod_amount']?.toString() ?? '',
    shippingFee: json['shipping_fee']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    placedAtLabel: json['placed_at_label']?.toString(),
    canCancel: _bool(json['can_cancel']),
  );
}

class ApiOrderItem {
  final int id;
  final String name;
  final String image;
  final int quantity;
  final String price;
  final String? color;
  final String? size;

  const ApiOrderItem({
    required this.id,
    required this.name,
    required this.image,
    required this.quantity,
    required this.price,
    this.color,
    this.size,
  });

  factory ApiOrderItem.fromJson(Map<String, dynamic> json) => ApiOrderItem(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    quantity: _int(json['quantity']),
    price: json['price']?.toString() ?? '',
    color: json['color']?.toString(),
    size: json['size']?.toString(),
  );
}

class ApiOrderDetail {
  final ApiOrder order;
  final List<ApiOrderItem> items;
  final String? shippingAddress;
  final String? moneyStatusLabel;
  final String? voucherCode;
  final String? voucherDiscount;
  final List<String> timeline;

  const ApiOrderDetail({
    required this.order,
    required this.items,
    this.shippingAddress,
    this.moneyStatusLabel,
    this.voucherCode,
    this.voucherDiscount,
    this.timeline = const [],
  });

  factory ApiOrderDetail.fromJson(Map<String, dynamic> json) => ApiOrderDetail(
    order: ApiOrder.fromJson(json),
    items: (json['items'] as List? ?? [])
        .map((e) => ApiOrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    shippingAddress: json['shipping_address']?.toString(),
    moneyStatusLabel: json['money_status_label']?.toString(),
    voucherCode: json['voucher_code']?.toString(),
    voucherDiscount: json['voucher_discount']?.toString(),
    timeline: (json['timeline'] as List? ?? []).map((e) => '${e['label']}').toList(),
  );
}

class ApiNotification {
  final int id;
  final String title;
  final String message;
  final bool read;
  final String? timeAgo;

  const ApiNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    this.timeAgo,
  });

  factory ApiNotification.fromJson(Map<String, dynamic> json) => ApiNotification(
    id: _int(json['id']),
    title: json['title']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    read: _bool(json['read']),
    timeAgo: json['time_ago']?.toString(),
  );
}

class ApiBuyer {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final Map<String, dynamic>? address;

  const ApiBuyer({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
  });

  factory ApiBuyer.fromJson(Map<String, dynamic> json) => ApiBuyer(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone_number']?.toString(),
    address: json['address'] is Map ? Map<String, dynamic>.from(json['address'] as Map) : null,
  );
}

class ApiProvince {
  final String code;
  final String name;
  final List<ApiCity> cities;
  const ApiProvince(this.code, this.name, this.cities);

  factory ApiProvince.fromJson(Map<String, dynamic> json) => ApiProvince(
    json['code']?.toString() ?? '',
    json['name']?.toString() ?? '',
    (json['cities'] as List? ?? [])
        .map((e) => ApiCity('${e['code']}', '${e['name']}'))
        .toList(),
  );
}

class ApiCity {
  final String code;
  final String name;
  const ApiCity(this.code, this.name);
}

class ApiBarangay {
  final String code;
  final String name;
  const ApiBarangay(this.code, this.name);

  factory ApiBarangay.fromJson(Map<String, dynamic> json) => ApiBarangay(
    json['code']?.toString() ?? '',
    json['name']?.toString() ?? '',
  );
}

class ApiVoucher {
  final String name;
  final String code;
  final bool eligible;
  final String? reason;
  final String discount;
  final String discountLabel;
  const ApiVoucher({
    required this.name,
    required this.code,
    required this.eligible,
    required this.discount,
    required this.discountLabel,
    this.reason,
  });

  factory ApiVoucher.fromJson(Map<String, dynamic> json) => ApiVoucher(
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    eligible: _bool(json['eligible']),
    reason: json['reason']?.toString(),
    discount: json['discount']?.toString() ?? '',
    discountLabel: json['discount_label']?.toString() ?? '',
  );
}

class ApiCheckoutShop {
  final int sellerId;
  final String shop;
  final String items;
  final double itemsValue;
  final List<ApiVoucher> vouchers;
  const ApiCheckoutShop({
    required this.sellerId,
    required this.shop,
    required this.items,
    required this.itemsValue,
    this.vouchers = const [],
  });

  factory ApiCheckoutShop.fromJson(Map<String, dynamic> json) => ApiCheckoutShop(
    sellerId: _int(json['seller_id']),
    shop: json['shop']?.toString() ?? '',
    items: json['items']?.toString() ?? '',
    itemsValue: _num(json['items_value']),
    vouchers: (json['vouchers'] as List? ?? [])
        .map((e) => ApiVoucher.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class ApiCheckoutPreview {
  final String revision;
  final ApiCart cart;
  final List<ApiCheckoutShop> shops;
  final Map<String, dynamic> defaultAddress;

  const ApiCheckoutPreview({
    required this.revision,
    required this.cart,
    required this.shops,
    required this.defaultAddress,
  });

  factory ApiCheckoutPreview.fromJson(Map<String, dynamic> json) => ApiCheckoutPreview(
    revision: json['checkout_revision']?.toString() ?? '',
    cart: ApiCart.fromJson(Map<String, dynamic>.from(json['cart'] as Map)),
    shops: (json['shops'] as List? ?? [])
        .map((e) => ApiCheckoutShop.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    defaultAddress: Map<String, dynamic>.from((json['default_address'] as Map?) ?? const {}),
  );
}

class ApiShippingQuote {
  final double total;
  final String totalLabel;
  final Map<int, double> perSeller;
  final Map<int, String> perSellerLabel;
  const ApiShippingQuote({
    required this.total,
    required this.totalLabel,
    required this.perSeller,
    required this.perSellerLabel,
  });
}
