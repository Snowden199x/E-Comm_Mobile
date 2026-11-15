import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vendo palette shared by the Profile sub-screens
//  • Prune   → dark header, main text
//  • Brique  → accent (section bars, warnings)
//  • Lin     → soft gold on dark
//  • Raisin  → icons and secondary tones
// ─────────────────────────────────────────────────────────────────────────────
class ProfileColors {
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
  static const success = Color(0xFF248A5A);
}

const double _radius = 16;

/// "May 4, 1998" from an ISO date. Falls back to the raw string.
String formatLongDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final date = DateTime.parse(iso);
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  } catch (_) {
    return iso;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page shell: dark header with back button, then a soft scrolling body
// ─────────────────────────────────────────────────────────────────────────────
class ProfilePageScaffold extends StatelessWidget {
  const ProfilePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ProfileColors.background,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ProfileColors.pruneLight, ProfileColors.prune],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ?action,
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x26FFFFFF)),
                        ),
                        child: Icon(icon, color: ProfileColors.lin, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 22, 20, 28 + bottomInset),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title with the small accent bar used across the dashboard
// ─────────────────────────────────────────────────────────────────────────────
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({super.key, required this.title, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: ProfileColors.brique,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: ProfileColors.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              caption!,
              style: const TextStyle(
                color: ProfileColors.muted,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// White card with an optional title, holding rows separated by dividers.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    this.caption,
    required this.children,
  });

  final String title;
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionTitle(title: title, caption: caption),
        const SizedBox(height: 10),
        ProfileCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 62,
                    color: ProfileColors.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: ProfileColors.border),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One labelled detail, e.g. "Mobile number — 09171234567"
// ─────────────────────────────────────────────────────────────────────────────
class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.hint = 'Not on file',
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final shown = (value == null || value!.trim().isEmpty) ? null : value!.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ProfileColors.raisinSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: ProfileColors.raisin, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shown ?? hint,
                  style: TextStyle(
                    color: shown == null ? ProfileColors.muted : ProfileColors.ink,
                    fontSize: 14,
                    fontWeight: shown == null ? FontWeight.w500 : FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Soft callout used to explain what the app can and cannot change.
class ProfileNote extends StatelessWidget {
  const ProfileNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProfileColors.raisinSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileColors.raisin.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ProfileColors.raisin, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6B5A70),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStatusPill extends StatelessWidget {
  const ProfileStatusPill({
    super.key,
    required this.label,
    this.color = ProfileColors.success,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Labelled text field, used by the editable profile fields
// ─────────────────────────────────────────────────────────────────────────────
class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ProfileColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          cursorColor: ProfileColors.prune,
          style: const TextStyle(color: ProfileColors.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: ProfileColors.muted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: ProfileColors.background,
            prefixIcon: icon == null
                ? null
                : Icon(icon, color: ProfileColors.raisin, size: 19),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: _fieldBorder(
              hasError ? ProfileColors.brique : ProfileColors.border,
            ),
            enabledBorder: _fieldBorder(
              hasError ? ProfileColors.brique : ProfileColors.border,
            ),
            focusedBorder: _fieldBorder(
              hasError ? ProfileColors.brique : ProfileColors.prune,
              1.6,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              color: ProfileColors.brique,
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}

OutlineInputBorder _fieldBorder(Color color, [double width = 1.2]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

/// Wrapped list of short labels, used for service-area barangays.
class ProfileTagList extends StatelessWidget {
  const ProfileTagList({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in labels)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ProfileColors.raisinSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ProfileColors.raisin.withAlpha(40)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: ProfileColors.raisin,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Loading and error states, kept honest instead of showing placeholder data.
class ProfileStateCard extends StatelessWidget {
  const ProfileStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: ProfileColors.raisinSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: ProfileColors.raisin, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ProfileColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ProfileColors.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: ProfileColors.prune,
              ),
            ),
          ] else if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ProfileColors.prune,
                  side: const BorderSide(color: ProfileColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
