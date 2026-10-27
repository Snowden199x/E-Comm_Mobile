import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/auth/screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette — matches the rest of the buyer app
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const headerTop = Color(0xFF3B1F52);
  static const headerBot = Color(0xFF2A1440);
  static const orange = Color(0xFFE8873A);
  static const purpleDark = Color(0xFF2D1B3D);
  static const purpleMid = Color(0xFF7B2FBE);
  static const bg = Color(0xFFF4F1F8);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF888888);
  static const border = Color(0xFFECE6EA);
  static const raisinSoft = Color(0xFFF4EDF5);
  static const orangeSoft = Color(0xFFFFF0E6);
}

const double _radius = 16;

// ─────────────────────────────────────────────────────────────────────────────
// Buyer Profile Screen
// ─────────────────────────────────────────────────────────────────────────────
class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  String _name = '';
  String _email = '';
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await BuyerApi.instance.buyerName();
    final email = await BuyerApi.instance.buyerEmail();
    if (mounted) {
      setState(() {
        _name = name ?? 'Buyer';
        _email = email ?? '';
      });
    }
  }

  Future<void> _confirmLogout() async {
    HapticFeedback.selectionClick();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius + 4),
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(
            color: _C.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'You will need to sign in again to continue shopping.',
          style: TextStyle(color: _C.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Stay',
              style: TextStyle(color: _C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: _C.orange, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await BuyerApi.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on BuyerApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Check your connection.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Order quick actions ─────────────────────
                    _buildOrderBar(),
                    const SizedBox(height: 20),

                    // ── Account section ─────────────────────────
                    _Section(
                      title: 'Account',
                      items: const [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Personal Information',
                        ),
                        _MenuItem(
                          icon: Icons.location_on_outlined,
                          label: 'Delivery Addresses',
                        ),
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                        ),
                        _MenuItem(
                          icon: Icons.notifications_outlined,
                          label: 'Notification Settings',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Shopping section ────────────────────────
                    _Section(
                      title: 'Shopping',
                      items: const [
                        _MenuItem(
                          icon: Icons.receipt_long_outlined,
                          label: 'My Orders',
                        ),
                        _MenuItem(
                          icon: Icons.favorite_border_rounded,
                          label: 'Saved Items',
                        ),
                        _MenuItem(
                          icon: Icons.local_offer_outlined,
                          label: 'My Vouchers',
                        ),
                        _MenuItem(
                          icon: Icons.star_border_rounded,
                          label: 'My Reviews',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Support section ─────────────────────────
                    _Section(
                      title: 'Support',
                      items: const [
                        _MenuItem(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & FAQ',
                        ),
                        _MenuItem(
                          icon: Icons.headset_mic_outlined,
                          label: 'Contact Support',
                        ),
                        _MenuItem(
                          icon: Icons.star_outline_rounded,
                          label: 'Rate the App',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Legal section ───────────────────────────
                    _Section(
                      title: 'Legal',
                      items: const [
                        _MenuItem(
                          icon: Icons.description_outlined,
                          label: 'Terms & Conditions',
                        ),
                        _MenuItem(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Log out button ──────────────────────────
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Purple gradient header ────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.headerTop, _C.headerBot],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: _C.orange,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF5C3275),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _C.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.headerTop, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),

          // Name + email + status pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isEmpty ? 'Buyer' : _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: _C.orange, size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Verified Buyer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            onPressed: () {},
            icon: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order status quick-jump bar ───────────────────────────────────────────
  Widget _buildOrderBar() {
    const statuses = [
      _OrderStatus(Icons.payments_outlined, 'To Pay'),
      _OrderStatus(Icons.local_shipping_outlined, 'To Ship'),
      _OrderStatus(Icons.inventory_2_outlined, 'To Receive'),
      _OrderStatus(Icons.rate_review_outlined, 'To Review'),
      _OrderStatus(Icons.assignment_return_outlined, 'Returns'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: [
                const Text(
                  'My Orders',
                  style: TextStyle(
                    color: _C.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text(
                        'View all',
                        style: TextStyle(
                          color: _C.purpleMid,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: _C.purpleMid),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: statuses.map((s) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: _C.raisinSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(s.icon, color: _C.purpleDark, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.label,
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Log out button ────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return Material(
      color: _C.orangeSoft,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _loggingOut ? null : _confirmLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: const Color(0xFFFFD0B0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loggingOut)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.orange,
                  ),
                )
              else
                const Icon(Icons.logout_rounded, color: _C.orange, size: 20),
              const SizedBox(width: 10),
              Text(
                _loggingOut ? 'Signing out…' : 'Log Out',
                style: const TextStyle(
                  color: _C.orange,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small data classes
// ─────────────────────────────────────────────────────────────────────────────
class _OrderStatus {
  final IconData icon;
  final String label;

  const _OrderStatus(this.icon, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Section widget — title bar + rounded card of menu items
// ─────────────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Accent bar + title
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _C.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    color: _C.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu item row
// ─────────────────────────────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: _C.raisinSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _C.purpleDark, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 20),
          ],
        ),
      ),
    );
  }//
}
