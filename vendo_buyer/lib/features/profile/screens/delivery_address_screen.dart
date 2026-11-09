import 'package:flutter/material.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// The delivery address saved with the Buyer's account. Read by checkout and
/// the web buyer account page from the same fields this screen writes.
class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _province = TextEditingController();
  final _municipality = TextEditingController();
  final _barangay = TextEditingController();
  final _houseNo = TextEditingController();
  final _street = TextEditingController();
  final _zipCode = TextEditingController();

  ApiBuyer? _buyer;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _province.dispose();
    _municipality.dispose();
    _barangay.dispose();
    _houseNo.dispose();
    _street.dispose();
    _zipCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final buyer = await BuyerApi.instance.account();
      if (!mounted) return;
      setState(() {
        _buyer = buyer;
        _province.text = buyer.province;
        _municipality.text = buyer.municipality;
        _barangay.text = buyer.barangay;
        _houseNo.text = buyer.houseNo;
        _street.text = buyer.street;
        _zipCode.text = buyer.zipCode;
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final buyer = _buyer;
    if (buyer == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final updated = await BuyerApi.instance.updateAccount(
        name: buyer.name,
        phone: buyer.phone,
        province: _province.text.trim(),
        municipality: _municipality.text.trim(),
        barangay: _barangay.text.trim(),
        street: _street.text.trim(),
        houseNo: _houseNo.text.trim(),
        zipCode: _zipCode.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _buyer = updated;
        _province.text = updated.province;
        _municipality.text = updated.municipality;
        _barangay.text = updated.barangay;
        _houseNo.text = updated.houseNo;
        _street.text = updated.street;
        _zipCode.text = updated.zipCode;
      });
      _toast('Delivery address saved.');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileScaffold(
      title: 'Delivery Address',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your address',
              text: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            )
          : _content(),
    );
  }

  Widget _content() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProfileCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: ProfileColors.soft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: ProfileColors.header,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Checkout uses this address, and it is shared with the Seller and the assigned Rider for delivery. Keep it complete and current.',
                    style: TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProfileCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved delivery address',
                  style: TextStyle(
                    color: ProfileColors.header,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ProfileTextField(
                  controller: _province,
                  label: 'Province',
                  textInputAction: TextInputAction.next,
                  validator: _required('Enter your province.'),
                ),
                const SizedBox(height: 12),
                ProfileTextField(
                  controller: _municipality,
                  label: 'Municipality / city',
                  textInputAction: TextInputAction.next,
                  validator: _required('Enter your municipality or city.'),
                ),
                const SizedBox(height: 12),
                ProfileTextField(
                  controller: _barangay,
                  label: 'Barangay',
                  textInputAction: TextInputAction.next,
                  validator: _required('Enter your barangay.'),
                ),
                const SizedBox(height: 12),
                ProfileTextField(
                  controller: _houseNo,
                  label: 'House no.',
                  hint: 'Optional',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                ProfileTextField(
                  controller: _street,
                  label: 'Street',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                  validator: _required('Enter your street.'),
                ),
                const SizedBox(height: 12),
                ProfileTextField(
                  controller: _zipCode,
                  label: 'ZIP code',
                  hint: 'Optional',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.postalCode],
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    return text.length > 20 ? 'Use 20 characters or fewer.' : null;
                  },
                ),
                const SizedBox(height: 18),
                ProfilePrimaryButton(
                  label: 'Save address',
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String? Function(String?) _required(String message) {
    return (value) => (value ?? '').trim().isEmpty ? message : null;
  }
}
