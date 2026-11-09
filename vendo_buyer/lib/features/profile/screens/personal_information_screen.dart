import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';
import 'package:vendo_buyer/features/shared/profile_kit.dart';

/// Profile information from `GET /api/v1/buyer/account`, saved with
/// `PUT /api/v1/buyer/account` and `POST /api/v1/buyer/account/photo`.
///
/// Same record as the web buyer account page: a name or phone number saved here
/// is what the web shows, and a photo replaced here replaces the web avatar.
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  ApiBuyer? _buyer;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
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
        _name.text = buyer.name;
        _phone.text = buyer.phone ?? '';
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
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final buyer = await BuyerApi.instance.updateAccount(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _buyer = buyer;
        _name.text = buyer.name;
        _phone.text = buyer.phone ?? '';
      });
      _toast('Profile updated.');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not reach Vendo. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final buyer = await BuyerApi.instance.uploadProfilePhoto(picked.path);
      if (!mounted) return;
      setState(() => _buyer = buyer);
      _toast('Profile picture updated.');
    } on BuyerApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('Could not upload the photo. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      title: 'Personal Information',
      child: _loading
          ? const ProfileLoading()
          : _error != null
          ? ProfileEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your profile',
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
            child: Column(
              children: [
                _Avatar(
                  imageUrl: _buyer?.profilePicture,
                  uploading: _uploading,
                  onTap: _uploading ? null : _changePhoto,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Profile picture',
                  style: TextStyle(
                    color: ProfileColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Shown on your Vendo account and in the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _changePhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 17),
                  label: Text(
                    _uploading ? 'Uploading…' : 'Change photo',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProfileColors.header,
                    side: const BorderSide(color: ProfileColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                  'Profile information',
                  style: TextStyle(
                    color: ProfileColors.header,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'This is what sellers and riders use to reach you and deliver your orders.',
                  style: TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ProfileTextField(
                  controller: _name,
                  label: 'Full name',
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter your full name.'
                      : null,
                ),
                const SizedBox(height: 12),
                ProfileTextField(
                  controller: _phone,
                  label: 'Phone number',
                  hint: 'e.g. 0917 123 4567',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    return text.length > 20 ? 'Use 20 characters or fewer.' : null;
                  },
                ),
                const SizedBox(height: 12),
                _ReadOnlyField(label: 'Email', value: _buyer?.email ?? ''),
                const SizedBox(height: 6),
                const Text(
                  'Your email is your sign-in and cannot be changed here.',
                  style: TextStyle(
                    color: ProfileColors.muted,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                ProfilePrimaryButton(
                  label: 'Save changes',
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
}

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _Avatar({this.imageUrl, required this.uploading, this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: ProfileColors.orange,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: url == null || url.isEmpty
                  ? Container(
                      color: const Color(0xFF5C3275),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF5C3275),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ProfileColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: ProfileColors.white, width: 2),
              ),
              child: uploading
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: ProfileColors.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: ProfileColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: ProfileColors.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
