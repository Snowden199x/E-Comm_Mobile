import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/core/utils/date_labels.dart';
import 'package:vendo_driver/features/shared/widgets/driver_ui.dart';

const List<String> _hubs = [
  'Laguna Province Hub',
  'Cavite Province Hub',
  'Quezon Province Hub',
  'Batangas Province Hub',
];

const List<String> _vehicleTypes = ['Truck', 'Van', 'L300'];

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  final _license = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String _hub = _hubs.first;
  String _vehicleType = _vehicleTypes.first;
  DateTime? _expiry;
  String? _expiryError;
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _plate.dispose();
    _license.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(today.year + 1, today.month, today.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 12, 12, 31),
      helpText: 'License expiry date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: VColors.prune,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiry = picked;
      _expiryError = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    final expiryMissing = _expiry == null;
    setState(
      () => _expiryError = expiryMissing
          ? 'Choose the expiry date printed on your license.'
          : null,
    );
    if (!valid || expiryMissing) return;

    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _submitting = false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: VColors.greenSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: VColors.green,
            size: 26,
          ),
        ),
        title: const Text(
          'Application submitted',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          '$_hub will review your license and vehicle details. '
          'You can sign in once the hub approves the account.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: VColors.muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: VColors.background,
        body: Column(
          children: [
            DriverHeader(
              eyebrow: 'Transport driver',
              title: 'Create driver account',
              subtitle:
                  'Your Province Hub reviews and approves every application.',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    _FormSection(
                      title: 'Your details',
                      children: [
                        _Field(
                          controller: _firstName,
                          label: 'First name',
                          hint: 'Miguel',
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter your first name.'
                              : null,
                        ),
                        _Field(
                          controller: _lastName,
                          label: 'Last name',
                          hint: 'Santos',
                          icon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter your last name.'
                              : null,
                        ),
                        _Field(
                          controller: _email,
                          label: 'Email address',
                          hint: 'driver@vendoxpress.ph',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = (value ?? '').trim();
                            if (email.isEmpty) return 'Enter your email.';
                            if (!email.contains('@') || !email.contains('.')) {
                              return 'Enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                        _Field(
                          controller: _phone,
                          label: 'Mobile number',
                          hint: '09XX XXX XXXX',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9 ]'),
                            ),
                          ],
                          validator: (value) {
                            final digits = (value ?? '').replaceAll(' ', '');
                            if (digits.isEmpty) return 'Enter your mobile number.';
                            if (!RegExp(r'^09\d{9}$').hasMatch(digits)) {
                              return 'Use an 11-digit number starting with 09.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Hub assignment',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _hub,
                          decoration: const InputDecoration(
                            labelText: 'Province Hub',
                            prefixIcon: Icon(
                              Icons.account_balance_outlined,
                              size: 20,
                            ),
                          ),
                          items: _hubs
                              .map(
                                (hub) => DropdownMenuItem(
                                  value: hub,
                                  child: Text(hub),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) setState(() => _hub = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: VColors.raisinSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.business_outlined,
                                color: VColors.raisin,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vendo Xpress Logistics',
                                      style: TextStyle(
                                        color: VColors.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Company is set by the hub after approval.',
                                      style: TextStyle(
                                        color: VColors.muted,
                                        fontSize: 11,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Vehicle',
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _vehicleType,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle type',
                            prefixIcon: Icon(
                              Icons.local_shipping_outlined,
                              size: 20,
                            ),
                          ),
                          items: _vehicleTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _vehicleType = value);
                            }
                          },
                        ),
                        _Field(
                          controller: _plate,
                          label: 'Plate number',
                          hint: 'NBC 4821',
                          icon: Icons.pin_outlined,
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter the plate number.'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Driver license',
                      children: [
                        _Field(
                          controller: _license,
                          label: 'License number',
                          hint: 'N02-24-118942',
                          icon: Icons.badge_outlined,
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Enter your license number.'
                              : null,
                        ),
                        InkWell(
                          onTap: _pickExpiry,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'License expiry',
                              prefixIcon: Icon(
                                Icons.event_outlined,
                                size: 20,
                              ),
                              suffixIcon: Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                            ),
                            child: Text(
                              _expiry == null
                                  ? 'Select expiry date'
                                  : shortDateLabel(_expiry!),
                              style: TextStyle(
                                color: _expiry == null
                                    ? VColors.muted
                                    : VColors.ink,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                        if (_expiryError != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 6),
                            child: Text(
                              _expiryError!,
                              style: const TextStyle(
                                color: VColors.red,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Password',
                      children: [
                        _Field(
                          controller: _password,
                          label: 'Password',
                          hint: 'At least 8 characters',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          trailing: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: VColors.muted,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.isEmpty) return 'Enter a password.';
                            if (password.length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        _Field(
                          controller: _confirm,
                          label: 'Confirm password',
                          hint: 'Repeat your password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          validator: (value) =>
                              value != _password.text
                              ? 'Passwords do not match.'
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const NoticeCard(
                      icon: Icons.info_outline_rounded,
                      title: 'Before you submit',
                      message:
                          'The hub needs a valid license and active vehicle. '
                          'Approval is done on the web portal; this build does '
                          'not send an application yet.',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: VColors.lin,
                                ),
                              )
                            : const Text('Submit application'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'You will be able to sign in only after approval.',
                        style: TextStyle(
                          color: VColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return VCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VColors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.trailing,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? trailing;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      cursorColor: VColors.prune,
      style: const TextStyle(color: VColors.ink, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: trailing,
      ),
    );
  }
}
