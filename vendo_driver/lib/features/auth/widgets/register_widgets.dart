import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';

/// The Driver registration uses the same look as the Rider registration:
/// a Prune gradient header, a white rounded sheet, labelled fields with hint
/// text only inside the box, upload rows, and a Back / Next bar at the bottom.

const double regRadius = 14;

// Picture size in the header, matching the Rider registration.
const double _heroW = 132;
const double _heroH = 92;

/// True for a field that was empty or wrong the last time Next was tapped.
class RegFormScope extends InheritedWidget {
  const RegFormScope({
    super.key,
    required this.flagged,
    required super.child,
  });

  final Set<String> flagged;

  static RegFormScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RegFormScope>();

  bool isFlagged(String id) => flagged.contains(id);

  @override
  bool updateShouldNotify(RegFormScope oldWidget) => true;
}

bool _flagged(BuildContext context, String id) =>
    RegFormScope.of(context)?.isFlagged(id) ?? false;

OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(regRadius),
  borderSide: BorderSide(color: color, width: width),
);

InputDecoration _decoration({
  String? hint,
  IconData? icon,
  Widget? suffix,
  bool error = false,
}) {
  final side = error ? VColors.red : VColors.border;
  final width = error ? 1.6 : 1.2;
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: VColors.muted, fontSize: 15),
    filled: true,
    fillColor: error ? VColors.redSoft : VColors.background,
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: error ? VColors.red : VColors.raisin, size: 20),
    suffixIcon: suffix == null
        ? null
        : Padding(padding: const EdgeInsets.only(right: 14), child: suffix),
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _border(side, width),
    enabledBorder: _border(side, width),
    disabledBorder: _border(side, width),
    focusedBorder: _border(error ? VColors.red : VColors.prune, 1.6),
  );
}

/// Purple header with the back button, the "Have an account? Login" pill and
/// the truck badge. The hero hides while the keyboard is open.
class RegisterHeader extends StatelessWidget {
  const RegisterHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onLogin,
    this.heroIcon = Icons.local_shipping_rounded,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onLogin;
  final IconData heroIcon;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _DecorPainter())),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onBack,
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
                    const Text(
                      'Have an account?  ',
                      style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: onLogin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: VColors.lin, width: 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: VColors.lin,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: keyboardOpen
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: _heroW,
                            height: _heroH,
                            child: _TruckHero(icon: heroIcon),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: VColors.lin,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small step card + segmented progress bar.
class RegisterStepBar extends StatelessWidget {
  const RegisterStepBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
    required this.icons,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VColors.pruneLight, VColors.prune],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icons[currentStep], color: VColors.lin, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: const TextStyle(
                        color: VColors.lin,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[currentStep],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentStep < totalSteps - 1)
                Flexible(
                  child: Text(
                    'Next: ${labels[currentStep + 1]}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 10.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(totalSteps, (i) {
            final done = i < currentStep;
            final active = i == currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 5,
                      decoration: BoxDecoration(
                        color: done
                            ? VColors.prune
                            : active
                            ? VColors.brique
                            : VColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        color: (done || active) ? VColors.prune : VColors.muted,
                        fontWeight: (done || active)
                            ? FontWeight.w800
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class RegisterSectionHeader extends StatelessWidget {
  const RegisterSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: VColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: VColors.muted, fontSize: 13)),
        const SizedBox(height: 10),
        const Divider(color: VColors.border, thickness: 1, height: 1),
      ],
    );
  }
}

/// Label above a field, with the small accent star when the field is required.
class _Label extends StatelessWidget {
  const _Label({required this.text, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: VColors.ink,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: VColors.brique),
                ),
              ]
            : const [],
      ),
    );
  }
}

/// Text field with the label above it, matching the Rider registration.
class RegInput extends StatelessWidget {
  const RegInput({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
    this.required = false,
    this.obscure = false,
    this.readOnly = false,
    this.keyboard,
    this.inputFormatters,
    this.suffix,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.forceError = false,
    this.errorText,
    this.autofillHints,
    this.labelAction,
  });

  final String id;
  final String label;

  /// Small action on the label row, for example the email "Verify" link.
  final Widget? labelAction;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool required;
  final bool obscure;
  final bool readOnly;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool forceError;
  final String? errorText;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasError = forceError || _flagged(context, id);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labelAction == null)
              _Label(text: label, required: required)
            else
              Row(
                children: [
                  Expanded(child: _Label(text: label, required: required)),
                  labelAction!,
                ],
              ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              obscureText: obscure,
              readOnly: readOnly,
              keyboardType: keyboard,
              inputFormatters: inputFormatters,
              onTap: onTap,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autofillHints: autofillHints,
              cursorColor: VColors.prune,
              style: const TextStyle(color: VColors.ink, fontSize: 15),
              decoration: _decoration(
                hint: hint,
                icon: icon,
                suffix: suffix,
                error: hasError,
              ),
            ),
            if (forceError && errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: VColors.red, fontSize: 11.5),
                ),
              ),
          ],
        );
      },
    );
  }
}

class RegDropdownItem {
  const RegDropdownItem(this.value, this.label);

  final String value;
  final String label;
}

/// Dropdown with the same box as a text field.
class RegDropdown extends StatelessWidget {
  const RegDropdown({
    super.key,
    required this.id,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.emptyNote,
  });

  final String id;
  final String label;
  final String hint;
  final String? value;
  final List<RegDropdownItem> items;
  final ValueChanged<String?> onChanged;
  final bool required;
  final bool enabled;
  final String? emptyNote;

  @override
  Widget build(BuildContext context) {
    final error = _flagged(context, id);
    final selected = items.where((item) => item.value == value).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label, required: required),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: error ? VColors.redSoft : VColors.background,
            borderRadius: BorderRadius.circular(regRadius),
            border: Border.all(
              color: error ? VColors.red : VColors.border,
              width: error ? 1.6 : 1.2,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected.isEmpty ? null : selected.first.value,
              hint: Text(
                items.isEmpty ? 'No hubs available' : hint,
                style: const TextStyle(color: VColors.muted, fontSize: 15),
              ),
              isExpanded: true,
              borderRadius: BorderRadius.circular(regRadius),
              dropdownColor: Colors.white,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: error ? VColors.red : VColors.muted,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VColors.ink, fontSize: 15),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: enabled && items.isNotEmpty ? onChanged : null,
            ),
          ),
        ),
        if (emptyNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              emptyNote!,
              style: const TextStyle(
                color: VColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
      ],
    );
  }
}

/// Upload row: shows the picked file name with a green check.
class RegUpload extends StatelessWidget {
  const RegUpload({
    super.key,
    required this.id,
    required this.label,
    required this.fileName,
    required this.hint,
    required this.onTap,
    this.required = false,
    this.helper,
  });

  final String id;
  final String label;
  final String? fileName;
  final String hint;
  final VoidCallback onTap;
  final bool required;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;
    final error = _flagged(context, id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: label, required: required),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: error
                  ? VColors.redSoft
                  : picked
                  ? VColors.raisinSoft
                  : VColors.background,
              borderRadius: BorderRadius.circular(regRadius),
              border: Border.all(
                color: error
                    ? VColors.red
                    : picked
                    ? VColors.raisin.withAlpha(90)
                    : VColors.border,
                width: error ? 1.6 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  picked
                      ? Icons.insert_drive_file_outlined
                      : Icons.attach_file,
                  color: error ? VColors.red : VColors.raisin,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName ?? hint,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: picked
                          ? VColors.ink
                          : (error ? VColors.red : VColors.muted),
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  picked ? Icons.check_circle_rounded : Icons.upload_outlined,
                  color: picked
                      ? VColors.green
                      : error
                      ? VColors.red
                      : VColors.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              helper!,
              style: const TextStyle(color: VColors.muted, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

/// Selectable card used for the Apply-to choice.
class RegChoiceCard extends StatelessWidget {
  const RegChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.flagged = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final borderColor = flagged
        ? VColors.red
        : selected
        ? VColors.prune
        : VColors.border;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? VColors.raisinSoft : VColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: selected || flagged ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? VColors.prune : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? VColors.prune : VColors.border,
                ),
              ),
              child: Icon(
                icon,
                size: 21,
                color: selected ? VColors.lin : VColors.raisin,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: VColors.ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: VColors.goldSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: VColors.prune,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: VColors.muted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? VColors.prune : VColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// One label / value row in the review step.
class RegReviewRow extends StatelessWidget {
  const RegReviewRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: VColors.muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                color: VColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegReviewCard extends StatelessWidget {
  const RegReviewCard({
    super.key,
    required this.title,
    required this.rows,
    this.onEdit,
  });

  final String title;
  final List<RegReviewRow> rows;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: VColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: VColors.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: VColors.raisin,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }
}

/// Back + Next / Submit bar, same buttons as the Rider registration.
class RegisterBottomBar extends StatelessWidget {
  const RegisterBottomBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.nextLabels,
    required this.onNext,
    this.onBack,
    this.submitting = false,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> nextLabels;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: VColors.border, width: 1)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: VColors.prune, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(regRadius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: VColors.prune,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: VColors.prune,
                  disabledBackgroundColor: VColors.prune,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(regRadius),
                  ),
                ),
                child: submitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: VColors.lin,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Submitting…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            nextLabels[currentStep],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded, size: 22),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet shown after a successful application.
class RegisterSuccessSheet extends StatelessWidget {
  const RegisterSuccessSheet({
    super.key,
    required this.reviewingHub,
    required this.applyLabel,
    required this.stationHub,
    required this.onDone,
  });

  final String reviewingHub;
  final String applyLabel;
  final String? stationHub;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        14,
        28,
        28 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: 200,
            height: 140,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [VColors.pruneLight, VColors.prune],
                        ),
                      ),
                      child: const CustomPaint(painter: _DecorPainter()),
                    ),
                  ),
                ),
                const Center(
                  child: SizedBox(
                    width: 120,
                    height: 90,
                    child: _TruckHero(icon: Icons.local_shipping_rounded),
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Application submitted',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VColors.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Waiting for approval',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VColors.raisin,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$reviewingHub reviews your application ($applyLabel).'
            '${stationHub != null ? '\nYour Station Hub is $stationHub.' : ''}'
            '\nSign in after it is approved.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Back to sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the server reports an error inside a step.
class RegErrorNote extends StatelessWidget {
  const RegErrorNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VColors.redSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VColors.red.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: VColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: VColors.red,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckHero extends StatelessWidget {
  const _TruckHero({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Icon(icon, size: 46, color: VColors.lin),
    );
  }
}

// Stable pseudo-random number in [0, 1), so the stars stay in the same places.
double _hash(int n) {
  final x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

/// Soft circles and stars behind the header, still.
class _DecorPainter extends CustomPainter {
  const _DecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Paint()..color = Colors.white.withAlpha(14);
    canvas.drawCircle(Offset(size.width * 0.88, 30), 62, circle);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.82), 46, circle);

    final star = Paint()..color = VColors.lin.withAlpha(120);
    for (var i = 0; i < 14; i++) {
      final dx = size.width * _hash(i);
      final dy = size.height * _hash(i + 40);
      canvas.drawCircle(Offset(dx, dy), 1.1 + _hash(i + 90) * 1.3, star);
    }
  }

  @override
  bool shouldRepaint(_DecorPainter oldDelegate) => false;
}
