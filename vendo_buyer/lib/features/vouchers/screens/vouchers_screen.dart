import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/seller_page/screens/api_seller_screen.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Shop vouchers from `GET /api/v1/buyer/vouchers` — the same active vouchers,
/// limits and codes the web buyer voucher page lists. A code copied here is
/// entered at checkout, where the discount is applied per shop order.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  List<ApiShopVoucher> _vouchers = const [];
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
      final vouchers = await BuyerApi.instance.vouchers();
      if (!mounted) return;
      setState(() {
        _vouchers = vouchers;
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

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$code copied. Paste it at checkout.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'My Vouchers',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load vouchers',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: ProfileColors.header,
              onRefresh: _load,
              child: _vouchers.isEmpty ? _empty() : _list(),
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
            icon: Icons.local_offer_outlined,
            title: 'No vouchers available right now',
            text:
                'When a Seller you follow activates a voucher, it appears here and in your notifications.',
          ),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _vouchers.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _vouchers.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Codes are typed or selected at checkout, per shop. Vouchers cannot be stacked, and shipping is quoted separately.',
              style: TextStyle(
                color: ProfileColors.muted,
                fontSize: 11.5,
                height: 1.55,
              ),
            ),
          );
        }
        return _VoucherCard(
          voucher: _vouchers[index],
          onCopy: _copy,
          onShop: (id, name) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApiSellerScreen(sellerId: id, name: name),
            ),
          ),
        );
      },
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final ApiShopVoucher voucher;
  final Future<void> Function(String code) onCopy;
  final void Function(int shopId, String shop) onShop;

  const _VoucherCard({
    required this.voucher,
    required this.onCopy,
    required this.onShop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ProfileColors.white,
        borderRadius: BorderRadius.circular(profileRadius),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: voucher.usable
                    ? const [ProfileColors.purple, ProfileColors.header]
                    : const [Color(0xFFD9CFDC), Color(0xFFB9AEBC)],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              voucher.shop,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ProfileColors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              voucher.name,
                              style: const TextStyle(
                                color: ProfileColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: ProfileColors.soft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          voucher.discountLabel,
                          style: const TextStyle(
                            color: ProfileColors.header,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Detail(label: 'Scope', value: voucher.scopeLabel),
                  _Detail(label: 'Min. spend', value: voucher.minSpendLabel),
                  _Detail(label: 'Valid', value: voucher.validLabel),
                  _Detail(
                    label: 'You can use',
                    value: voucher.usesLeft == 1
                        ? '1 more time'
                        : '${voucher.usesLeft} more times',
                  ),
                  if (voucher.maxDiscountLabel != null)
                    _Detail(
                      label: 'Max discount',
                      value: voucher.maxDiscountLabel!,
                    ),
                  if (voucher.shopUsesLeft != null)
                    _Detail(
                      label: 'Shop-wide uses left',
                      value: '${voucher.shopUsesLeft}',
                    ),
                  if (!voucher.usable && voucher.unavailableReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      voucher.unavailableReason!,
                      style: const TextStyle(
                        color: ProfileColors.danger,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: ProfileColors.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: voucher.usable
                            ? () => onCopy(voucher.code)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: voucher.usable
                                ? const Color(0xFFFAF5FA)
                                : const Color(0xFFF7F3F8),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: voucher.usable
                                  ? ProfileColors.purple
                                  : const Color(0xFFD9CFDC),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: voucher.usable
                                    ? ProfileColors.header
                                    : ProfileColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                voucher.code,
                                style: TextStyle(
                                  color: voucher.usable
                                      ? ProfileColors.header
                                      : ProfileColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (voucher.shopId > 0)
                        TextButton(
                          onPressed: () =>
                              onShop(voucher.shopId, voucher.shop),
                          child: Text(
                            voucher.usable ? 'Shop now' : 'View shop',
                            style: const TextStyle(
                              color: ProfileColors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;

  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: ProfileColors.muted,
                fontSize: 11.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ProfileColors.ink,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
