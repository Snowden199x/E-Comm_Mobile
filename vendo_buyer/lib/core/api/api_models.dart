/// Typed views over the `/api/v1/buyer` JSON. Every field is optional-safe: the API always
/// sends the keys, but an older server build must not crash the app.
library;

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

bool _bool(dynamic value) => value == true || value == 1 || value == '1';

/// A field of a nested object, without caring whether the server sent one.
String? _child(dynamic map, String key) =>
    map is Map ? map[key]?.toString() : null;

class ApiProduct {
  final int id;
  final String name;
  final String price;
  final double priceValue;
  final String? compareAtPrice;
  final int discountPercent;
  final String image;
  final List<String> images;
  final String shop;
  final int shopId;
  final String province;
  final String municipality;
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
    this.province = '',
    this.municipality = '',
    this.images = const [],
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
    images: (json['images'] as List?)?.map((e) => '$e').toList() ?? const [],
    shop: json['shop']?.toString() ?? '',
    shopId: _int(json['shop_id']),
    province: json['province']?.toString() ?? '',
    municipality: json['municipality']?.toString() ?? '',
    rating: json['rating'] == null ? null : _num(json['rating']),
    sold: _int(json['sold']),
    stock: _int(json['stock']),
    hasVariations: _bool(json['has_variations']),
    colors: (json['colors'] as List?)?.map((e) => '$e').toList() ?? const [],
    sizes: (json['sizes'] as List?)?.map((e) => '$e').toList() ?? const [],
    soldOut: _bool(json['sold_out']),
  );
}

/// One top-level category and its subcategories, from `GET /categories`.
class ApiCategory {
  final int id;
  final String name;
  final List<ApiCategory> children;

  const ApiCategory({
    required this.id,
    required this.name,
    this.children = const [],
  });

  factory ApiCategory.fromJson(Map<String, dynamic> json) => ApiCategory(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    children: (json['children'] as List? ?? [])
        .map((e) => ApiCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
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

  factory ApiSpec.fromJson(Map<String, dynamic> json) => ApiSpec(
    (json['label'] ?? json['name'])?.toString() ?? '',
    json['value']?.toString() ?? '',
  );
}

/// Delivery + payment facts the web product page shows, sent as `product.delivery`.
class ApiDelivery {
  final String shipsFrom;
  final String shippingFee;
  final double shippingFeeValue;
  final String shippingNote;
  final String paymentMethod;

  const ApiDelivery({
    required this.shipsFrom,
    required this.shippingFee,
    required this.shippingFeeValue,
    required this.shippingNote,
    required this.paymentMethod,
  });

  factory ApiDelivery.fromJson(Map<String, dynamic> json) => ApiDelivery(
    shipsFrom: json['ships_from']?.toString() ?? '',
    shippingFee: json['shipping_fee']?.toString() ?? '',
    shippingFeeValue: _num(json['shipping_fee_value']),
    shippingNote: json['shipping_note']?.toString() ?? '',
    paymentMethod: json['payment_method']?.toString() ?? '',
  );
}

/// Published-review average plus the per-star counts drawn as bars.
class ApiRatingSummary {
  static const stars = [5, 4, 3, 2, 1];

  final double average;
  final int total;
  final Map<int, int> counts;

  const ApiRatingSummary({
    this.average = 0,
    this.total = 0,
    this.counts = const {},
  });

  factory ApiRatingSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['counts'];
    return ApiRatingSummary(
      average: _num(json['average']),
      total: _int(json['total']),
      counts: {
        for (final star in stars) star: _int(raw is Map ? raw['$star'] : null),
      },
    );
  }

  int countFor(int star) => counts[star] ?? 0;
}

/// One published rating, with the seller's reply when there is one.
class ApiProductReview {
  final int id;
  final String buyer;
  final String initial;
  final int rating;
  final String? date;
  final bool verified;
  final String? comment;
  final String? replyBody;
  final String? replySeller;

  const ApiProductReview({
    required this.id,
    required this.buyer,
    required this.initial,
    required this.rating,
    this.date,
    this.verified = false,
    this.comment,
    this.replyBody,
    this.replySeller,
  });

  factory ApiProductReview.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'];
    return ApiProductReview(
      id: _int(json['id']),
      buyer: json['buyer']?.toString() ?? 'Buyer',
      initial: json['initial']?.toString() ?? '',
      rating: _int(json['rating']),
      date: json['date']?.toString(),
      verified: _bool(json['verified']),
      comment: json['comment']?.toString(),
      replyBody: _child(reply, 'body'),
      replySeller: _child(reply, 'seller'),
    );
  }
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
  final int? ratingsCount;
  final double? averageRating;
  final String? joined;
  final String? banner;
  final String? avatar;
  final String? url;

  const ApiSeller({
    required this.id,
    required this.name,
    required this.owner,
    this.description,
    this.province,
    this.municipality,
    this.rating,
    this.productsCount = 0,
    this.ratingsCount,
    this.averageRating,
    this.joined,
    this.banner,
    this.avatar,
    this.url,
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
    ratingsCount: json['ratings_count'] == null
        ? null
        : _int(json['ratings_count']),
    averageRating: json['average_rating'] == null
        ? null
        : _num(json['average_rating']),
    joined: json['joined']?.toString(),
    banner: json['banner']?.toString(),
    avatar: json['avatar']?.toString(),
    url: json['url']?.toString(),
  );

  /// "Santa Cruz, Laguna" — where the shop ships from, as the web shop card shows it.
  String get location => [
    municipality,
    province,
  ].where((part) => part != null && part.trim().isNotEmpty).join(', ');

  /// First letter of the shop name, shown in the round avatar when there is no photo.
  String get initial =>
      name.trim().isEmpty ? '' : name.trim().substring(0, 1).toUpperCase();
}

class ApiProductDetail {
  final ApiProduct product;
  final String? description;
  final String? category;
  final List<String> images;
  final List<ApiVariant> variants;
  final List<ApiSpec> specifications;
  final ApiDelivery? delivery;
  final ApiRatingSummary ratings;
  final List<ApiProductReview> reviews;
  final ApiSeller? seller;
  final List<ApiProduct> recommended;

  const ApiProductDetail({
    required this.product,
    required this.images,
    required this.variants,
    required this.specifications,
    this.description,
    this.category,
    this.delivery,
    this.ratings = const ApiRatingSummary(),
    this.reviews = const [],
    this.seller,
    this.recommended = const [],
  });

  factory ApiProductDetail.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    return ApiProductDetail(
      product: ApiProduct.fromJson(product),
      description: product['description']?.toString(),
      category: product['category']?.toString(),
      images:
          (product['images'] as List?)?.map((e) => '$e').toList() ?? const [],
      variants: (product['variants'] as List? ?? [])
          .map((e) => ApiVariant.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      specifications: (product['specifications'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiSpec.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      delivery: product['delivery'] is Map
          ? ApiDelivery.fromJson(
              Map<String, dynamic>.from(product['delivery'] as Map),
            )
          : null,
      ratings: product['ratings'] is Map
          ? ApiRatingSummary.fromJson(
              Map<String, dynamic>.from(product['ratings'] as Map),
            )
          : const ApiRatingSummary(),
      reviews: (product['reviews'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiProductReview.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      seller: product['seller'] is Map
          ? ApiSeller.fromJson(
              Map<String, dynamic>.from(product['seller'] as Map),
            )
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

/// One tab on My orders. The web's seven tabs come from the API, so both sides
/// filter and count the same orders.
class ApiOrderTab {
  final String key;
  final String label;
  final int count;

  const ApiOrderTab({required this.key, required this.label, this.count = 0});

  factory ApiOrderTab.fromJson(Map<String, dynamic> json) => ApiOrderTab(
    key: json['key']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    count: _int(json['count']),
  );

  static List<ApiOrderTab> list(Object? raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((e) => ApiOrderTab.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// The return pill on an order card: pending, approved, rejected or done.
class ApiOrderPill {
  final String label;
  final String tone;

  const ApiOrderPill({required this.label, required this.tone});

  factory ApiOrderPill.fromJson(Map<String, dynamic> json) => ApiOrderPill(
    label: json['label']?.toString() ?? '',
    tone: json['tone']?.toString() ?? '',
  );
}

/// One page of My orders together with the tab counts above it.
class ApiOrdersPage {
  final List<ApiOrder> orders;
  final List<ApiOrderTab> tabs;
  final int page;
  final int lastPage;
  final int total;

  const ApiOrdersPage({
    required this.orders,
    this.tabs = const [],
    this.page = 1,
    this.lastPage = 1,
    this.total = 0,
  });

  /// The tab holds more orders than this page did.
  bool get hasMore => page < lastPage;
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

  /// Same grouping the web My Orders tabs use: to_ship, in_transit, delivered,
  /// cancelled or returned.
  final String shipmentGroup;

  /// Completed order items that still need a review.
  final int reviewPending;

  /// "you" or "the seller" when the order was cancelled, like the web header.
  final String? cancelledBy;
  final String? cancelReason;

  /// Set when the order sits on the Returns tab for a reason other than its status.
  final ApiOrderPill? returnPill;

  /// The web's footer label: View details, Confirm receipt or View and rate.
  final String actionLabel;

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
    this.shipmentGroup = '',
    this.reviewPending = 0,
    this.cancelledBy,
    this.cancelReason,
    this.returnPill,
    this.actionLabel = 'View details',
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
    shipmentGroup: json['shipment_group']?.toString() ?? '',
    reviewPending: _int(json['review_pending']),
    cancelledBy: json['cancelled_by']?.toString(),
    cancelReason: json['cancel_reason']?.toString(),
    returnPill: json['return_pill'] is Map
        ? ApiOrderPill.fromJson(
            Map<String, dynamic>.from(json['return_pill'] as Map),
          )
        : null,
    actionLabel: json['action_label']?.toString() ?? 'View details',
  );

  /// What the status pill says: a cancelled order names who cancelled it, as on the web.
  String get displayStatusLabel =>
      cancelledBy == null ? statusLabel : 'Cancelled by $cancelledBy';
}

class ApiOrderItem {
  final int id;
  final int productId;
  final String name;
  final String image;
  final int quantity;
  final String price;
  final String lineTotal;
  final String? color;
  final String? size;
  final bool reviewed;

  /// The review this Buyer already left on the item, with the seller's reply.
  final ApiOrderReview? review;

  const ApiOrderItem({
    required this.id,
    this.productId = 0,
    required this.name,
    required this.image,
    required this.quantity,
    required this.price,
    this.lineTotal = '',
    this.color,
    this.size,
    this.reviewed = false,
    this.review,
  });

  factory ApiOrderItem.fromJson(Map<String, dynamic> json) => ApiOrderItem(
    id: _int(json['id']),
    productId: _int(json['product_id']),
    name: json['name']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    quantity: _int(json['quantity']),
    price: json['price']?.toString() ?? '',
    lineTotal: json['line_total']?.toString() ?? '',
    color: json['color']?.toString(),
    size: json['size']?.toString(),
    reviewed: _bool(json['reviewed']),
    review: json['review'] is Map
        ? ApiOrderReview.fromJson(Map<String, dynamic>.from(json['review']))
        : null,
  );
}

/// What the Buyer wrote about one item, and the seller's answer.
class ApiOrderReview {
  final int rating;
  final String comment;
  final bool hidden;
  final String? reply;

  const ApiOrderReview({
    required this.rating,
    required this.comment,
    this.hidden = false,
    this.reply,
  });

  factory ApiOrderReview.fromJson(Map<String, dynamic> json) => ApiOrderReview(
    rating: _int(json['rating']),
    comment: json['comment']?.toString() ?? '',
    hidden: _bool(json['hidden']),
    reply: json['reply']?.toString(),
  );
}

/// One entry of the web page's "Order updates" card, newest first.
class ApiOrderEvent {
  final String status;
  final String label;
  final String? atLabel;
  final String? note;

  const ApiOrderEvent({
    required this.status,
    required this.label,
    this.atLabel,
    this.note,
  });

  factory ApiOrderEvent.fromJson(Map<String, dynamic> json) => ApiOrderEvent(
    status: json['status']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    atLabel: json['at_label']?.toString(),
    note: json['note']?.toString(),
  );
}

/// One stop on the progress rail; the server decides which stops this parcel has.
class ApiOrderStep {
  final String status;
  final String label;
  final bool done;
  final bool current;

  const ApiOrderStep({
    required this.status,
    required this.label,
    this.done = false,
    this.current = false,
  });

  factory ApiOrderStep.fromJson(Map<String, dynamic> json) => ApiOrderStep(
    status: json['status']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    done: _bool(json['done']),
    current: _bool(json['current']),
  );
}

class ApiOrderProgress {
  final bool terminalIssue;
  final String statusLabel;
  final List<ApiOrderStep> steps;

  const ApiOrderProgress({
    this.terminalIssue = false,
    this.statusLabel = '',
    this.steps = const [],
  });

  factory ApiOrderProgress.fromJson(Map<String, dynamic> json) =>
      ApiOrderProgress(
        terminalIssue: _bool(json['terminal_issue']),
        statusLabel: json['status_label']?.toString() ?? '',
        steps: (json['steps'] as List? ?? [])
            .map(
              (e) => ApiOrderStep.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

/// The shop behind the order, so the app can open its page and its chat.
class ApiOrderSeller {
  final int id;
  final String name;

  const ApiOrderSeller({required this.id, required this.name});

  factory ApiOrderSeller.fromJson(Map<String, dynamic> json) => ApiOrderSeller(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
  );
}

class ApiOrderTracking {
  final String number;
  final String? carrier;
  final String? carrierTracking;
  final String? estimatedFromLabel;
  final String? estimatedToLabel;
  final int attempts;
  final int maxAttempts;
  final String? nextAttemptLabel;

  /// The rider's delivery photo, fetched with the Buyer's token.
  final bool hasDeliveryProof;

  const ApiOrderTracking({
    this.number = '',
    this.carrier,
    this.carrierTracking,
    this.estimatedFromLabel,
    this.estimatedToLabel,
    this.attempts = 0,
    this.maxAttempts = 0,
    this.nextAttemptLabel,
    this.hasDeliveryProof = false,
  });

  factory ApiOrderTracking.fromJson(Map<String, dynamic> json) =>
      ApiOrderTracking(
        number: json['number']?.toString() ?? '',
        carrier: json['carrier']?.toString(),
        carrierTracking: json['carrier_tracking']?.toString(),
        estimatedFromLabel: json['estimated_from_label']?.toString(),
        estimatedToLabel: json['estimated_to_label']?.toString(),
        attempts: _int(json['attempts']),
        maxAttempts: _int(json['max_attempts']),
        nextAttemptLabel: json['next_attempt_label']?.toString(),
        hasDeliveryProof: _bool(json['has_delivery_proof']),
      );

  /// "Nov 20, 2026 to Nov 22, 2026", or the one date the parcel has.
  String? get estimatedLabel {
    if (estimatedFromLabel != null && estimatedToLabel != null)
      return '$estimatedFromLabel to $estimatedToLabel';
    return estimatedFromLabel ?? estimatedToLabel;
  }
}

/// The Seller's answer to a return request, as the web return card shows it.
class ApiOrderReturn {
  final String status;
  final String statusLabel;
  final String reasonLabel;
  final String? decisionNote;
  final String? refund;
  final String? returnStatusLabel;
  final String? pickedUpAtLabel;
  final String? timeAgo;
  final bool isPending;

  const ApiOrderReturn({
    required this.status,
    required this.statusLabel,
    required this.reasonLabel,
    this.decisionNote,
    this.refund,
    this.returnStatusLabel,
    this.pickedUpAtLabel,
    this.timeAgo,
    this.isPending = false,
  });

  factory ApiOrderReturn.fromJson(Map<String, dynamic> json) => ApiOrderReturn(
    status: json['status']?.toString() ?? '',
    statusLabel: json['status_label']?.toString() ?? '',
    reasonLabel: json['reason_label']?.toString() ?? '',
    decisionNote: json['decision_note']?.toString(),
    refund: json['refund']?.toString(),
    returnStatusLabel: json['return_status_label']?.toString(),
    pickedUpAtLabel: json['picked_up_at_label']?.toString(),
    timeAgo: json['time_ago']?.toString(),
    isPending: _bool(json['is_pending']),
  );

  bool get approved => status == 'approved';
  bool get rejected => status == 'rejected';
}

/// One choice of a server-supplied reason list (cancellation, return request).
class ApiOrderReason {
  final String key;
  final String label;

  const ApiOrderReason({required this.key, required this.label});

  factory ApiOrderReason.fromJson(Map<String, dynamic> json) => ApiOrderReason(
    key: json['key']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
  );

  static List<ApiOrderReason> list(dynamic raw) => (raw as List? ?? [])
      .map((e) => ApiOrderReason.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

class ApiOrderDetail {
  final ApiOrder order;
  final List<ApiOrderItem> items;
  final String itemsTotal;
  final String? shippingAddress;
  final String? moneyStatusLabel;
  final String? voucherCode;
  final String? voucherDiscount;
  final List<ApiOrderEvent> timeline;
  final ApiOrderProgress progress;
  final ApiOrderSeller? seller;
  final ApiOrderTracking? tracking;
  final bool canComplete;
  final bool cancelLocked;
  final String? buyerNote;
  final String paymentLabel;
  final bool canRequestReturn;
  final String? returnWindowClosesLabel;
  final int? returnDaysLeft;
  final List<ApiOrderReason> returnReasons;
  final List<ApiOrderReason> cancelReasons;
  final ApiOrderReturn? returnRequest;

  const ApiOrderDetail({
    required this.order,
    required this.items,
    this.itemsTotal = '',
    this.shippingAddress,
    this.moneyStatusLabel,
    this.voucherCode,
    this.voucherDiscount,
    this.timeline = const [],
    this.progress = const ApiOrderProgress(),
    this.seller,
    this.tracking,
    this.canComplete = false,
    this.cancelLocked = false,
    this.buyerNote,
    this.paymentLabel = '',
    this.canRequestReturn = false,
    this.returnWindowClosesLabel,
    this.returnDaysLeft,
    this.returnReasons = const [],
    this.cancelReasons = const [],
    this.returnRequest,
  });

  factory ApiOrderDetail.fromJson(Map<String, dynamic> json) => ApiOrderDetail(
    order: ApiOrder.fromJson(json),
    items: (json['items'] as List? ?? [])
        .map((e) => ApiOrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    itemsTotal: json['items_total']?.toString() ?? '',
    shippingAddress: json['shipping_address']?.toString(),
    moneyStatusLabel: json['money_status_label']?.toString(),
    voucherCode: json['voucher_code']?.toString(),
    voucherDiscount: json['voucher_discount']?.toString(),
    timeline: (json['timeline'] as List? ?? [])
        .map((e) => ApiOrderEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    progress: json['progress'] is Map
        ? ApiOrderProgress.fromJson(Map<String, dynamic>.from(json['progress']))
        : const ApiOrderProgress(),
    seller: json['seller'] is Map
        ? ApiOrderSeller.fromJson(Map<String, dynamic>.from(json['seller']))
        : null,
    tracking: json['tracking'] is Map
        ? ApiOrderTracking.fromJson(Map<String, dynamic>.from(json['tracking']))
        : null,
    canComplete: _bool(json['can_complete']),
    cancelLocked: _bool(json['cancel_locked']),
    buyerNote: json['buyer_note']?.toString(),
    paymentLabel: json['payment_label']?.toString() ?? '',
    canRequestReturn: _bool(json['can_request_return']),
    returnWindowClosesLabel: json['return_window_closes_at_label']?.toString(),
    returnDaysLeft: json['return_days_left'] == null
        ? null
        : _int(json['return_days_left']),
    returnReasons: ApiOrderReason.list(json['return_reasons']),
    cancelReasons: ApiOrderReason.list(json['cancel_reasons']),
    returnRequest: json['return_request'] is Map
        ? ApiOrderReturn.fromJson(
            Map<String, dynamic>.from(json['return_request']),
          )
        : null,
  );
}

class ApiNotification {
  final int id;
  final String title;
  final String message;
  final bool read;
  final String? timeAgo;

  /// Notification kind from the server (`order_update`, `platform_announcement`,
  /// …), the same field the web buyer page groups by. Nullable because a hot
  /// reload leaves it empty on objects built before it existed; the card then
  /// draws the generic bell icon.
  final String? type;

  /// The product the notification is about — the contents of the parcel — as the
  /// server resolves it from the notification's link. Null for notifications
  /// that point at nothing on sale (announcements, account notices).
  final String? productName;
  final String? productImage;

  /// The order behind an order/parcel notification, as the server reads it from
  /// the notification's link: the record the card opens, and the real status the
  /// card is labelled with. Null for announcements, messages and reviews.
  final int? orderId;
  final String? orderNumber;
  final String? orderStatus;
  final String? orderStatusLabel;

  const ApiNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    this.timeAgo,
    this.type,
    this.productName,
    this.productImage,
    this.orderId,
    this.orderNumber,
    this.orderStatus,
    this.orderStatusLabel,
  });

  factory ApiNotification.fromJson(Map<String, dynamic> json) =>
      ApiNotification(
        id: _int(json['id']),
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        read: _bool(json['read']),
        timeAgo: json['time_ago']?.toString(),
        type: json['type']?.toString(),
        productName: _child(json['product'], 'name'),
        productImage: _child(json['product'], 'image'),
        orderId: json['order'] is Map ? _int(json['order']['id']) : null,
        orderNumber: _child(json['order'], 'number'),
        orderStatus: _child(json['order'], 'status'),
        orderStatusLabel: _child(json['order'], 'status_label'),
      );

  /// The same record after the server (or the screen) marked it read.
  ApiNotification copyWith({bool? read}) => ApiNotification(
    id: id,
    title: title,
    message: message,
    read: read ?? this.read,
    timeAgo: timeAgo,
    type: type,
    productName: productName,
    productImage: productImage,
    orderId: orderId,
    orderNumber: orderNumber,
    orderStatus: orderStatus,
    orderStatusLabel: orderStatusLabel,
  );
}

/// One step of the strike ladder: how many strikes trigger what suspension.
class ApiStrikeStep {
  final int strikes;
  final int? days;
  final String label;

  const ApiStrikeStep({required this.strikes, this.days, required this.label});

  factory ApiStrikeStep.fromJson(Map<String, dynamic> json) => ApiStrikeStep(
    strikes: _int(json['strikes']),
    days: json['days'] == null ? null : _int(json['days']),
    label: json['label']?.toString() ?? '',
  );

  /// "3 strikes: 7-day suspension", the line the web page prints.
  String get summary =>
      '$strikes ${strikes == 1 ? 'strike' : 'strikes'}: $label';
}

/// One approved account report about this Buyer; each counts as one strike.
class ApiStandingReport {
  final int id;
  final String type;
  final String reportedOn;
  final String approvedOn;
  final String reporter;
  final String? note;
  final int? orderId;
  final String? orderNumber;

  const ApiStandingReport({
    required this.id,
    required this.type,
    required this.reportedOn,
    required this.approvedOn,
    required this.reporter,
    this.note,
    this.orderId,
    this.orderNumber,
  });

  factory ApiStandingReport.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    return ApiStandingReport(
      id: _int(json['id']),
      type: json['type']?.toString() ?? 'Account report',
      reportedOn: json['reported_on']?.toString() ?? '',
      approvedOn: json['approved_on']?.toString() ?? '',
      reporter: json['reporter']?.toString() ?? 'Another user',
      note: json['note']?.toString(),
      orderId: order is Map ? _int(order['id']) : null,
      orderNumber: _child(order, 'number'),
    );
  }

  String get orderLabel {
    final number = orderNumber ?? '';
    if (number.isNotEmpty) return number;
    return orderId == null ? '' : '#$orderId';
  }
}

/// Account standing from `GET /account-standing`: strikes, suspension state and
/// the approved reports behind them, matching the web page.
class ApiStanding {
  final int strikes;
  final int? untilNext;
  final bool suspended;
  final String? suspensionNotes;
  final String? suspendedUntilLabel;
  final List<ApiStrikeStep> ladder;
  final List<ApiStandingReport> reports;

  const ApiStanding({
    required this.strikes,
    this.untilNext,
    this.suspended = false,
    this.suspensionNotes,
    this.suspendedUntilLabel,
    this.ladder = const [],
    this.reports = const [],
  });

  factory ApiStanding.fromJson(Map<String, dynamic> json) {
    final account = json['account'] is Map
        ? Map<String, dynamic>.from(json['account'] as Map)
        : const <String, dynamic>{};
    return ApiStanding(
      strikes: _int(json['strikes']),
      untilNext: json['until_next'] == null ? null : _int(json['until_next']),
      suspended: _bool(json['suspended']),
      suspensionNotes: account['suspension_notes']?.toString(),
      suspendedUntilLabel: account['suspended_until_label']?.toString(),
      ladder: (json['ladder'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiStrikeStep.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      reports: (json['reports'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiStandingReport.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// One complaint the Buyer sent to Vendo.
class ApiComplaint {
  final int id;
  final String type;
  final String status;
  final String statusLabel;
  final String description;
  final String? decision;
  final String? filedAtLabel;
  final int attachments;
  final int? orderId;
  final String? orderNumber;
  final String? respondentName;
  final bool isAccountReport;

  const ApiComplaint({
    required this.id,
    required this.type,
    required this.status,
    required this.statusLabel,
    required this.description,
    this.decision,
    this.filedAtLabel,
    this.attachments = 0,
    this.orderId,
    this.orderNumber,
    this.respondentName,
    this.isAccountReport = false,
  });

  factory ApiComplaint.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    final respondent = json['respondent'];
    return ApiComplaint(
      id: _int(json['id']),
      type: json['type']?.toString() ?? 'Complaint',
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      decision: json['decision']?.toString(),
      filedAtLabel: json['filed_at_label']?.toString(),
      attachments: _int(json['attachments']),
      orderId: order is Map ? _int(order['id']) : null,
      orderNumber: _child(order, 'number'),
      respondentName: _child(respondent, 'name'),
      isAccountReport: json['kind']?.toString() == 'user_report',
    );
  }

  String get orderLabel {
    final number = orderNumber ?? '';
    if (number.isNotEmpty) return number;
    return orderId == null ? '' : '#$orderId';
  }
}

/// The complaints list plus the Open / In review / Resolved counts above it.
class ApiComplaintsPage {
  final List<ApiComplaint> items;
  final int open;
  final int inReview;
  final int resolved;
  final int total;
  final int page;
  final int lastPage;

  const ApiComplaintsPage({
    required this.items,
    this.open = 0,
    this.inReview = 0,
    this.resolved = 0,
    this.total = 0,
    this.page = 1,
    this.lastPage = 1,
  });

  /// The next page's rows appended to this one, with fresh counts.
  ApiComplaintsPage append(ApiComplaintsPage next) => ApiComplaintsPage(
    items: [...items, ...next.items],
    open: next.open,
    inReview: next.inReview,
    resolved: next.resolved,
    total: next.total,
    page: next.page,
    lastPage: next.lastPage,
  );

  bool get hasMore => page < lastPage;

  factory ApiComplaintsPage.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] is Map
        ? Map<String, dynamic>.from(json['counts'] as Map)
        : const <String, dynamic>{};
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : const <String, dynamic>{};
    return ApiComplaintsPage(
      items: (json['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiComplaint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      open: _int(counts['open']),
      inReview: _int(counts['in_review']),
      resolved: _int(counts['resolved']),
      total: _int(meta['total']),
      page: _int(meta['current_page']),
      lastPage: _int(meta['last_page']),
    );
  }
}

/// One shop chat in the Buyer's Messages inbox.
class ApiSellerChat {
  final int id;
  final int sellerId;
  final String sellerName;
  final String? sellerAvatar;
  final int? orderId;
  final String? orderNumber;
  final String preview;
  final String? time;
  final int unread;

  const ApiSellerChat({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    this.sellerAvatar,
    this.orderId,
    this.orderNumber,
    this.preview = 'No messages yet',
    this.time,
    this.unread = 0,
  });

  factory ApiSellerChat.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'];
    final order = json['order'];
    return ApiSellerChat(
      id: _int(json['id']),
      sellerId: _int(_child(seller, 'id')),
      sellerName: _child(seller, 'name') ?? 'Seller',
      sellerAvatar: _child(seller, 'avatar'),
      orderId: order is Map ? _int(order['id']) : null,
      orderNumber: _child(order, 'number'),
      preview: json['preview']?.toString() ?? 'No messages yet',
      time: json['time']?.toString(),
      unread: _int(json['unread']),
    );
  }

  String get initial {
    final name = sellerName.trim();
    return name.isEmpty ? 'S' : name.substring(0, 1).toUpperCase();
  }
}

class ApiSellerChats {
  final List<ApiSellerChat> items;
  final int unreadTotal;

  const ApiSellerChats({this.items = const [], this.unreadTotal = 0});

  factory ApiSellerChats.fromJson(Map<String, dynamic> json) => ApiSellerChats(
    items: (json['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ApiSellerChat.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    unreadTotal: _int(json['unread_total']),
  );
}

/// One topic offered by the Vendo Support card.
class ApiSupportReason {
  final String name;
  final String description;

  const ApiSupportReason({required this.name, required this.description});

  factory ApiSupportReason.fromJson(Map<String, dynamic> json) =>
      ApiSupportReason(
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );
}

class ApiSupportAttachment {
  final String url;
  final String name;

  const ApiSupportAttachment({required this.url, required this.name});

  factory ApiSupportAttachment.fromJson(Map<String, dynamic> json) =>
      ApiSupportAttachment(
        url: json['url']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  bool get isImage {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }
}

class ApiSupportMessage {
  final int id;
  final String body;
  final bool isMine;
  final bool isSystem;
  final String? avatar;
  final String initial;
  final String? time;
  final List<ApiSupportAttachment> attachments;

  const ApiSupportMessage({
    required this.id,
    required this.body,
    required this.isMine,
    required this.isSystem,
    this.avatar,
    this.initial = 'V',
    this.time,
    this.attachments = const [],
  });

  factory ApiSupportMessage.fromJson(Map<String, dynamic> json) =>
      ApiSupportMessage(
        id: _int(json['id']),
        body: json['body']?.toString() ?? '',
        isMine: _bool(json['is_mine']),
        isSystem: _bool(json['is_system']),
        avatar: json['avatar']?.toString(),
        initial: json['initial']?.toString() ?? 'V',
        time: json['time']?.toString(),
        attachments: (json['attachments'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) =>
                  ApiSupportAttachment.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );
}

/// A Vendo Support conversation — the same thread the web panel reads.
class ApiSupportConversation {
  final int id;
  final String status;
  final List<ApiSupportMessage> messages;

  const ApiSupportConversation({
    required this.id,
    required this.status,
    this.messages = const [],
  });

  factory ApiSupportConversation.fromJson(Map<String, dynamic> json) =>
      ApiSupportConversation(
        id: _int(json['id']),
        status: json['status']?.toString() ?? '',
        messages: (json['messages'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => ApiSupportMessage.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList(),
      );

  bool get isOpen => status == 'open';
  bool get isClosed => status == 'closed';

  /// The newest human message, for the "Continue conversation" row.
  String get lastPreview {
    for (final message in messages.reversed) {
      if (message.isSystem) continue;
      final body = message.body.trim();
      if (body.isNotEmpty) return body;
      if (message.attachments.isNotEmpty) return 'Photo';
    }
    return 'No messages yet';
  }
}

class ApiSupportInbox {
  final ApiSupportConversation? conversation;
  final List<ApiSupportReason> reasons;

  const ApiSupportInbox({this.conversation, this.reasons = const []});

  factory ApiSupportInbox.fromJson(Map<String, dynamic> json) {
    final conversation = json['conversation'];
    return ApiSupportInbox(
      conversation: conversation is Map
          ? ApiSupportConversation.fromJson(
              Map<String, dynamic>.from(conversation),
            )
          : null,
      reasons: (json['reasons'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ApiSupportReason.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ApiBuyer {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePicture;
  final Map<String, dynamic>? address;

  const ApiBuyer({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profilePicture,
    this.address,
  });

  factory ApiBuyer.fromJson(Map<String, dynamic> json) => ApiBuyer(
    id: _int(json['id']),
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone_number']?.toString(),
    profilePicture: json['profile_picture']?.toString(),
    address: json['address'] is Map
        ? Map<String, dynamic>.from(json['address'] as Map)
        : null,
  );

  String get province => _child(address, 'province') ?? '';
  String get municipality => _child(address, 'municipality') ?? '';
  String get barangay => _child(address, 'barangay') ?? '';
  String get street => _child(address, 'street') ?? '';
  String get houseNo => _child(address, 'house_no') ?? '';
  String get zipCode => _child(address, 'zip_code') ?? '';
}

/// A shop voucher as the My Vouchers screen shows it. Distinct from
/// [ApiVoucher], which is one shop's checkout quote.
class ApiShopVoucher {
  final int id;
  final int shopId;
  final String shop;
  final String name;
  final String code;
  final String discountLabel;
  final String scopeLabel;
  final String minSpendLabel;
  final String? maxDiscountLabel;
  final String validLabel;
  final int usesLeft;
  final int? shopUsesLeft;
  final bool usable;
  final String? unavailableReason;

  const ApiShopVoucher({
    required this.id,
    required this.shopId,
    required this.shop,
    required this.name,
    required this.code,
    required this.discountLabel,
    required this.scopeLabel,
    required this.minSpendLabel,
    required this.validLabel,
    required this.usesLeft,
    required this.usable,
    this.maxDiscountLabel,
    this.shopUsesLeft,
    this.unavailableReason,
  });

  factory ApiShopVoucher.fromJson(Map<String, dynamic> json) => ApiShopVoucher(
    id: _int(json['id']),
    shopId: _int(json['shop_id']),
    shop: json['shop']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    discountLabel: json['discount_label']?.toString() ?? '',
    scopeLabel: json['scope_label']?.toString() ?? '',
    minSpendLabel: json['min_spend_label']?.toString() ?? '',
    maxDiscountLabel: json['max_discount_label']?.toString(),
    validLabel: json['valid_label']?.toString() ?? '',
    usesLeft: _int(json['uses_left']),
    shopUsesLeft: json['shop_uses_left'] == null
        ? null
        : _int(json['shop_uses_left']),
    usable: _bool(json['usable']),
    unavailableReason: json['unavailable_reason']?.toString(),
  );
}

class ApiReviewReply {
  final String body;
  final String? atLabel;

  const ApiReviewReply({required this.body, this.atLabel});

  factory ApiReviewReply.fromJson(Map<String, dynamic> json) => ApiReviewReply(
    body: json['body']?.toString() ?? '',
    atLabel: json['at_label']?.toString(),
  );
}

/// One of the signed-in Buyer's own product reviews.
class ApiReview {
  final int id;
  final int orderId;
  final int productId;
  final String productName;
  final String image;
  final String shop;
  final int rating;
  final String comment;
  final String visibility;
  final String? createdAtLabel;
  final ApiReviewReply? reply;

  const ApiReview({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.image,
    required this.shop,
    required this.rating,
    required this.comment,
    this.visibility = 'published',
    this.createdAtLabel,
    this.reply,
  });

  factory ApiReview.fromJson(Map<String, dynamic> json) => ApiReview(
    id: _int(json['id']),
    orderId: _int(json['order_id']),
    productId: _int(json['product_id']),
    productName: json['product_name']?.toString() ?? '',
    image: json['image']?.toString() ?? '',
    shop: json['shop']?.toString() ?? '',
    rating: _int(json['rating']),
    comment: json['comment']?.toString() ?? '',
    visibility: json['visibility']?.toString() ?? 'published',
    createdAtLabel: json['created_at_label']?.toString(),
    reply: json['reply'] is Map
        ? ApiReviewReply.fromJson(
            Map<String, dynamic>.from(json['reply'] as Map),
          )
        : null,
  );
}

/// A block of a legal page. `type` is heading, paragraph or bullet.
class ApiContentBlock {
  final String type;
  final String text;
  final int level;

  const ApiContentBlock({
    required this.type,
    required this.text,
    this.level = 0,
  });

  factory ApiContentBlock.fromJson(Map<String, dynamic> json) =>
      ApiContentBlock(
        type: json['type']?.toString() ?? 'paragraph',
        text: json['text']?.toString() ?? '',
        level: _int(json['level']),
      );
}

class ApiContentPage {
  final String title;
  final String? updatedLabel;
  final List<ApiContentBlock> blocks;

  const ApiContentPage({
    required this.title,
    required this.blocks,
    this.updatedLabel,
  });

  factory ApiContentPage.fromJson(Map<String, dynamic> json) => ApiContentPage(
    title: json['title']?.toString() ?? '',
    updatedLabel: json['updated_label']?.toString(),
    blocks: (json['blocks'] as List? ?? [])
        .map(
          (e) => ApiContentBlock.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}

class ApiFaqItem {
  final String question;
  final String answer;

  const ApiFaqItem({required this.question, required this.answer});

  factory ApiFaqItem.fromJson(Map<String, dynamic> json) => ApiFaqItem(
    question: json['question']?.toString() ?? '',
    answer: json['answer']?.toString() ?? '',
  );
}

class ApiFaqGroup {
  final String title;
  final List<ApiFaqItem> items;

  const ApiFaqGroup({required this.title, required this.items});

  factory ApiFaqGroup.fromJson(Map<String, dynamic> json) => ApiFaqGroup(
    title: json['title']?.toString() ?? '',
    items: (json['items'] as List? ?? [])
        .map((e) => ApiFaqItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class ApiFaqPage {
  final String title;
  final String intro;
  final String? contactEmail;
  final List<ApiFaqGroup> groups;

  const ApiFaqPage({
    required this.title,
    required this.intro,
    required this.groups,
    this.contactEmail,
  });

  factory ApiFaqPage.fromJson(Map<String, dynamic> json) => ApiFaqPage(
    title: json['title']?.toString() ?? '',
    intro: json['intro']?.toString() ?? '',
    contactEmail: json['contact_email']?.toString(),
    groups: (json['groups'] as List? ?? [])
        .map((e) => ApiFaqGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
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

/// Map tiles and defaults for the delivery-pin picker, served by the API so the
/// Geoapify key stays on the server (the same tiles the web checkout draws).
class ApiGeoMapConfig {
  final String tileUrl;
  final String attribution;
  final double defaultLatitude;
  final double defaultLongitude;

  const ApiGeoMapConfig({
    required this.tileUrl,
    required this.attribution,
    required this.defaultLatitude,
    required this.defaultLongitude,
  });

  factory ApiGeoMapConfig.fromJson(Map<String, dynamic> json) =>
      ApiGeoMapConfig(
        tileUrl: json['tile_url']?.toString() ?? '',
        attribution: json['attribution']?.toString() ?? '',
        defaultLatitude:
            double.tryParse('${json['default_latitude']}') ?? 12.8797,
        defaultLongitude:
            double.tryParse('${json['default_longitude']}') ?? 121.7740,
      );
}

/// One Geoapify place: the pin coordinates, the written address and its parts
/// with the PSGC codes the address form uses.
class ApiGeoPlace {
  final double latitude;
  final double longitude;
  final String formatted;
  final String street;
  final String barangay;
  final String city;
  final String? cityCode;
  final String province;
  final String? provinceCode;
  final String postcode;

  const ApiGeoPlace({
    required this.latitude,
    required this.longitude,
    required this.formatted,
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.postcode,
    this.cityCode,
    this.provinceCode,
  });

  /// "2nd Avenue, San Pablo Sur" — what the address line becomes.
  String get line =>
      [street, barangay].where((part) => part.isNotEmpty).join(', ');

  factory ApiGeoPlace.fromJson(Map<String, dynamic> json) => ApiGeoPlace(
    latitude: double.tryParse('${json['latitude']}') ?? 0,
    longitude: double.tryParse('${json['longitude']}') ?? 0,
    formatted: json['formatted']?.toString() ?? '',
    street: json['street']?.toString() ?? '',
    barangay: json['barangay']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    cityCode: json['city_code']?.toString(),
    province: json['province']?.toString() ?? '',
    provinceCode: json['province_code']?.toString(),
    postcode: json['postcode']?.toString() ?? '',
  );
}

class ApiVoucher {
  final String name;
  final String code;
  final bool eligible;
  final String? reason;
  final String discount;
  final String discountLabel;
  final String scopeLabel;
  final double minSpend;
  final int? remainingUses;
  final int perBuyerLimit;
  final String? startsAt;
  final String? endsAt;

  const ApiVoucher({
    required this.name,
    required this.code,
    required this.eligible,
    required this.discount,
    required this.discountLabel,
    this.reason,
    this.scopeLabel = '',
    this.minSpend = 0,
    this.remainingUses,
    this.perBuyerLimit = 1,
    this.startsAt,
    this.endsAt,
  });

  factory ApiVoucher.fromJson(Map<String, dynamic> json) => ApiVoucher(
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    eligible: _bool(json['eligible']),
    reason: json['reason']?.toString(),
    discount: json['discount']?.toString() ?? '',
    discountLabel: json['discount_label']?.toString() ?? '',
    scopeLabel: json['scope_label']?.toString() ?? '',
    minSpend: _num(json['min_spend']),
    remainingUses: json['remaining_uses'] == null
        ? null
        : _int(json['remaining_uses']),
    perBuyerLimit: _int(json['per_buyer_limit']),
    startsAt: json['starts_at']?.toString(),
    endsAt: json['ends_at']?.toString(),
  );

  /// Short line the checkout voucher list shows under the code.
  String get details {
    final parts = <String>[
      if (scopeLabel.isNotEmpty) scopeLabel,
      if (minSpend > 0) 'Minimum spend ₱${minSpend.toStringAsFixed(2)}',
      if (endsAt != null && endsAt!.isNotEmpty) 'Valid until $endsAt',
      if (remainingUses != null) '$remainingUses use(s) left',
      'Up to $perBuyerLimit use(s) per Buyer',
    ];
    return parts.join(' · ');
  }
}

/// One address from the Buyer's saved address book (web: Buyer > Account > Delivery).
class ApiBuyerAddress {
  final int id;
  final String label;
  final String line;
  final String province;
  final String city;
  final String provinceCode;
  final String cityCode;
  final bool isDefault;
  final bool usable;
  final double? latitude;
  final double? longitude;

  const ApiBuyerAddress({
    required this.id,
    required this.label,
    required this.line,
    required this.province,
    required this.city,
    required this.provinceCode,
    required this.cityCode,
    required this.isDefault,
    required this.usable,
    this.latitude,
    this.longitude,
  });

  factory ApiBuyerAddress.fromJson(Map<String, dynamic> json) =>
      ApiBuyerAddress(
        id: _int(json['id']),
        label: json['label']?.toString() ?? 'Address',
        line: json['line']?.toString() ?? '',
        province: json['province']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        provinceCode: json['province_code']?.toString() ?? '',
        cityCode: json['city_code']?.toString() ?? '',
        isDefault: _bool(json['is_default']),
        usable: _bool(json['usable']),
        latitude: json['latitude'] == null ? null : _num(json['latitude']),
        longitude: json['longitude'] == null ? null : _num(json['longitude']),
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

  factory ApiCheckoutShop.fromJson(Map<String, dynamic> json) =>
      ApiCheckoutShop(
        sellerId: _int(json['seller_id']),
        shop: json['shop']?.toString() ?? '',
        items: json['items']?.toString() ?? '',
        itemsValue: _num(json['items_value']),
        vouchers: (json['vouchers'] as List? ?? [])
            .map(
              (e) => ApiVoucher.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
}

class ApiCheckoutPreview {
  final String revision;
  final ApiCart cart;
  final List<ApiCheckoutShop> shops;
  final Map<String, dynamic> defaultAddress;
  final String buyerName;
  final String buyerPhone;
  final List<ApiBuyerAddress> savedAddresses;
  final bool sellerNotesEnabled;

  const ApiCheckoutPreview({
    required this.revision,
    required this.cart,
    required this.shops,
    required this.defaultAddress,
    this.buyerName = '',
    this.buyerPhone = '',
    this.savedAddresses = const [],
    this.sellerNotesEnabled = true,
  });

  factory ApiCheckoutPreview.fromJson(Map<String, dynamic> json) =>
      ApiCheckoutPreview(
        revision: json['checkout_revision']?.toString() ?? '',
        cart: ApiCart.fromJson(Map<String, dynamic>.from(json['cart'] as Map)),
        shops: (json['shops'] as List? ?? [])
            .map(
              (e) =>
                  ApiCheckoutShop.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        defaultAddress: Map<String, dynamic>.from(
          (json['default_address'] as Map?) ?? const {},
        ),
        buyerName:
            ((json['buyer'] as Map?)?['name'] ?? json['buyer_name'])
                ?.toString() ??
            '',
        buyerPhone:
            ((json['buyer'] as Map?)?['phone_number'] ?? json['buyer_phone'])
                ?.toString() ??
            '',
        savedAddresses: (json['saved_addresses'] as List? ?? [])
            .map(
              (e) =>
                  ApiBuyerAddress.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        sellerNotesEnabled: json['seller_notes_enabled'] == null
            ? true
            : _bool(json['seller_notes_enabled']),
      );
}

/// One Logistics Company the Buyer can pick for a shop's parcel.
class ApiShippingOption {
  final int companyId;
  final String companyName;
  final bool isCheapest;
  final int hubCount;
  final List<String> route;
  final double fee;
  final String feeLabel;

  const ApiShippingOption({
    required this.companyId,
    required this.companyName,
    required this.isCheapest,
    required this.hubCount,
    required this.route,
    required this.fee,
    required this.feeLabel,
  });

  factory ApiShippingOption.fromJson(Map<String, dynamic> json) {
    final fee = _num(json['shipping_fee']);
    return ApiShippingOption(
      companyId: _int(json['company_id']),
      companyName: json['company_name']?.toString() ?? 'Logistics provider',
      isCheapest: _bool(json['is_cheapest']),
      hubCount: _int(json['hub_count']),
      route: (json['route'] as List? ?? [])
          .map((stop) => '${(stop as Map)['name'] ?? ''}')
          .where((name) => name.isNotEmpty)
          .toList(),
      fee: fee,
      feeLabel:
          json['shipping_fee_label']?.toString() ??
          '₱${fee.toStringAsFixed(2)}',
    );
  }

  /// "4 hubs · Sampaguita Station → Hilltop Hub → …" like the web card.
  String get routeLabel {
    if (route.isEmpty) return '$hubCount hub${hubCount == 1 ? '' : 's'}';
    return '$hubCount hub${hubCount == 1 ? '' : 's'} · ${route.join(' → ')}';
  }
}

class ApiShippingQuote {
  final double total;
  final String totalLabel;
  final Map<int, double> perSeller;
  final Map<int, String> perSellerLabel;

  /// The Company the server picked for each shop, and every Company the Buyer
  /// may choose instead.
  final Map<int, ApiShippingOption> selected;
  final Map<int, List<ApiShippingOption>> options;

  const ApiShippingQuote({
    required this.total,
    required this.totalLabel,
    required this.perSeller,
    required this.perSellerLabel,
    this.selected = const {},
    this.options = const {},
  });
}

// ── Seller chat ───────────────────────────────────────────────────────────────

/// The shop on the other side of a chat, as the web chat header names it.
class ApiChatSeller {
  final int id;
  final String name;
  final String owner;
  final String? avatar;
  final String? url;

  const ApiChatSeller({
    required this.id,
    required this.name,
    required this.owner,
    this.avatar,
    this.url,
  });

  factory ApiChatSeller.fromJson(Map<String, dynamic> json) => ApiChatSeller(
    id: _int(json['id']),
    name: json['name']?.toString() ?? 'Shop',
    owner: json['owner']?.toString() ?? '',
    avatar: json['avatar']?.toString(),
    url: json['url']?.toString(),
  );

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
}

/// An order the buyer can share in the chat: `#ORD-2026-0012 · Assigned to Rider`.
class ApiChatOrder {
  final int id;
  final String number;
  final String label;
  final String status;

  const ApiChatOrder({
    required this.id,
    required this.number,
    required this.label,
    this.status = '',
  });

  factory ApiChatOrder.fromJson(Map<String, dynamic> json) => ApiChatOrder(
    id: _int(json['id']),
    number: json['number']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
  );
}

/// The order card inside a shared-order message.
class ApiChatSharedOrder {
  final int orderId;
  final String number;
  final String? image;
  final String productName;
  final int itemCount;
  final String total;
  final String? carrier;
  final String? tracking;
  final String status;

  const ApiChatSharedOrder({
    required this.orderId,
    required this.number,
    required this.productName,
    required this.itemCount,
    required this.total,
    required this.status,
    this.image,
    this.carrier,
    this.tracking,
  });

  factory ApiChatSharedOrder.fromJson(Map<String, dynamic> json) =>
      ApiChatSharedOrder(
        orderId: _int(json['order_id']),
        number: json['number']?.toString() ?? '',
        image: json['image_url']?.toString(),
        productName: json['product_name']?.toString() ?? 'Order items',
        itemCount: _int(json['item_count']),
        total: json['total']?.toString() ?? '',
        carrier: json['carrier']?.toString(),
        tracking: json['tracking']?.toString(),
        status: json['status']?.toString() ?? '',
      );

  bool get hasTracking => tracking != null && tracking!.trim().isNotEmpty;

  String get trackingLabel => hasTracking
      ? '${(carrier ?? '').trim().isEmpty ? 'Courier' : carrier} · Tracking $tracking'
      : '';
}

/// One line of a marketplace chat: a buyer/seller message, an attached photo, a
/// shared order, or a Vendo notice (`system`).
class ApiChatMessage {
  final int id;
  final bool mine;
  final bool system;
  final String sender;
  final String initial;
  final String? avatar;
  final String? body;
  final String? item;
  final String? time;
  final String? attachmentUrl;
  final ApiChatSharedOrder? sharedOrder;

  const ApiChatMessage({
    required this.id,
    required this.sender,
    required this.initial,
    this.mine = false,
    this.system = false,
    this.avatar,
    this.body,
    this.item,
    this.time,
    this.attachmentUrl,
    this.sharedOrder,
  });

  factory ApiChatMessage.fromJson(Map<String, dynamic> json) {
    final shared = json['shared_order'];
    return ApiChatMessage(
      id: _int(json['id']),
      mine: _bool(json['mine']),
      system: _bool(json['system']),
      sender: json['sender']?.toString() ?? '',
      initial: json['initial']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      body: json['body']?.toString(),
      item: json['item']?.toString(),
      time: json['time']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      sharedOrder: shared is Map
          ? ApiChatSharedOrder.fromJson(Map<String, dynamic>.from(shared))
          : null,
    );
  }

  /// "You · Nov 16, 7:52 AM", the small line above each bubble.
  String get meta => [
    sender,
    time,
  ].where((part) => part != null && part.trim().isNotEmpty).join(' · ');
}

/// A whole chat thread: the shop, the order it is pinned to (if any), its
/// messages and the orders the buyer may share.
class ApiChatThread {
  final ApiChatSeller? seller;
  final ApiChatOrder? order;
  final List<ApiChatMessage> messages;
  final List<ApiChatOrder> shareOrders;

  /// Set when the web would send the buyer to their newest order chat instead
  /// of starting a shop chat (a shop chat already exists if this is null).
  final int? redirectOrderId;

  const ApiChatThread({
    this.seller,
    this.order,
    this.messages = const [],
    this.shareOrders = const [],
    this.redirectOrderId,
  });

  factory ApiChatThread.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'];
    final order = json['order'];
    return ApiChatThread(
      seller: seller is Map
          ? ApiChatSeller.fromJson(Map<String, dynamic>.from(seller))
          : null,
      order: order is Map
          ? ApiChatOrder.fromJson(Map<String, dynamic>.from(order))
          : null,
      messages: (json['messages'] as List? ?? [])
          .map(
            (e) => ApiChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      shareOrders: (json['share_orders'] as List? ?? [])
          .map(
            (e) => ApiChatOrder.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      redirectOrderId: json['redirect_order_id'] == null
          ? null
          : _int(json['redirect_order_id']),
    );
  }
}

/// Result of checking one shop's stacked voucher codes.
class ApiVoucherQuote {
  final double discount;
  final String discountLabel;
  final List<String> codes;

  const ApiVoucherQuote({
    required this.discount,
    required this.discountLabel,
    required this.codes,
  });

  factory ApiVoucherQuote.fromJson(Map<String, dynamic> json) =>
      ApiVoucherQuote(
        discount: _num(json['discount']),
        discountLabel: json['discount_label']?.toString() ?? '',
        codes: (json['codes'] as List? ?? [])
            .map((code) => code.toString())
            .toList(),
      );
}
