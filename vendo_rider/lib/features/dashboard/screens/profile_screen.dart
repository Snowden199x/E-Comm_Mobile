import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_rider/core/api/rider_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the Home, Deliveries and Earnings screens
//  • Prune   → dark header, main text
//  • Brique  → accent (camera badge, section bars, log out)
//  • Lin     → soft gold for key details on dark
//  • Raisin  → icons and secondary tones
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const prune = Color(0xFF412143);
  static const pruneLight = Color(0xFF55295A);
  static const brique = Color(0xFFBF5E40);
  static const lin = Color(0xFFDBC583);
  static const raisin = Color(0xFF815488);

  static const background = Color(0xFFFAF7F5);
  static const ink = Color(0xFF2A1B2C);
  static const muted = Color(0xFF8C8290);
  static const border = Color(0xFFECE6EA);

  static const raisinSoft = Color(0xFFF4EDF5);
  static const briqueSoft = Color(0xFFF8EAE5);
}

const double _radius = 16;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _riderName = '';

  // Placeholder until the API returns the real rider ID
  static const _riderId = 'RID-45821';

  @override
  void initState() {
    super.initState();
    RiderApi.instance.riderName().then((name) {
      if (mounted) setState(() => _riderName = name ?? 'Rider');
    });
  }

  // Ask first, so the rider can't log out by accident
  Future<void> _confirmLogout() async {
    HapticFeedback.selectionClick();
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
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
          'You will need to sign in again to see your deliveries.',
          style: TextStyle(color: _C.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Stay',
              style: TextStyle(color: _C.muted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: _C.brique, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldLogOut == true && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.background,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ProfileSection(
                      title: 'Account',
                      items: [
                        _MenuItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Personal Information',
                        ),
                        _MenuItem(
                          icon: Icons.two_wheeler_outlined,
                          label: 'Vehicle Details',
                        ),
                        _MenuItem(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change Password',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _ProfileSection(
                      title: 'Support',
                      items: [
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
                    const SizedBox(height: 24),
                    const _ProfileSection(
                      title: 'Legal',
                      items: [
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

  // ── Dark header: avatar, name, status, quick stats ───────────────────────
  Widget _buildHeader() {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 24, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.pruneLight, _C.prune],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Avatar with gold ring and camera badge
          Stack(
            children: [
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: _C.lin,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: _C.raisin,
                    shape: BoxShape.circle,
                  ),
                  // Swap this Icon for an Image / NetworkImage when you have photos
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _C.brique,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.prune, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _riderName.isEmpty ? 'Rider' : _riderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // Status pill + rider ID (same style as the pill on Home)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _C.lin,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Active Rider',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 10, color: const Color(0x40FFFFFF)),
                const SizedBox(width: 8),
                const Text(
                  _riderId,
                  style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Glass-style stats strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: const Row(
              children: [
                _ProfileStat(label: 'Total Trips', value: '248'),
                _StatDivider(),
                _ProfileStat(label: 'Rating', value: '4.9 ★'),
                _StatDivider(),
                _ProfileStat(label: 'Since', value: 'Jan 2024'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Log out: soft accent color, asks before leaving ──────────────────────
  Widget _buildLogoutButton() {
    return Material(
      color: _C.briqueSoft,
      borderRadius: BorderRadius.circular(_radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _confirmLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: const Color(0xFFF0D3C9)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: _C.brique, size: 20),
              SizedBox(width: 10),
              Text(
                'Log Out',
                style: TextStyle(
                  color: _C.brique,
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
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileStat extends StatelessWidget {
  final String label, value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _C.lin,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: const Color(0x26FFFFFF));
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with the small accent bar (same as other screens)
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _C.brique,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: _C.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: _C.raisinSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _C.raisin, size: 20),
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
  }
}
//gusto ko mag push
