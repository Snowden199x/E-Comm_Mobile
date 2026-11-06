import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/dashboard/widgets/profile_ui.dart';

/// Every personal detail the Vendo API holds for the signed-in Rider:
/// identity, contact, home address, and the Station Hub assignment.
///
/// The Rider can edit their full name, birthday, and account photo. Contact
/// details, address, vehicle, documents, service areas, and the hub assignment
/// stay Station-Hub managed.
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  Map<String, dynamic>? _rider;
  bool _loading = true;
  String? _error;

  // Edit mode for the full name and birthday
  bool _editing = false;
  bool _saving = false;
  String? _formError;
  final Map<String, String> _errors = {};

  final _firstNameCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  DateTime? _birthday;

  bool _uploadingPhoto = false;

  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    foregroundColor: ProfileColors.lin,
    disabledForegroundColor: const Color(0x66FFFFFF),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rider = await RiderApi.instance.riderProfile();
      if (!mounted) return;
      setState(() {
        _rider = rider;
        _loading = false;
      });
    } on RiderApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Cannot reach Vendo Xpress right now. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  void _startEditing() {
    final rider = _rider;
    if (rider == null) return;
    final details = _map(rider['details']);

    _firstNameCtrl.text = _text(rider['first_name']) ?? '';
    _middleCtrl.text = _text(rider['middle_initial']) ?? '';
    _lastNameCtrl.text = _text(rider['last_name']) ?? '';
    final birthday = _text(details['birthday']);
    _birthday = birthday == null ? null : DateTime.tryParse(birthday);

    setState(() {
      _editing = true;
      _formError = null;
      _errors.clear();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editing = false;
      _formError = null;
      _errors.clear();
    });
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) setState(() => _errors.remove(field));
  }

  Future<void> _pickBirthday() async {
    final today = DateTime.now();
    final lastAllowed = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
    final initial = _birthday ?? DateTime(today.year - 20, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(lastAllowed) ? lastAllowed : initial,
      firstDate: DateTime(1900),
      lastDate: lastAllowed,
      builder: (pickerContext, child) => Theme(
        data: Theme.of(pickerContext).copyWith(
          colorScheme: const ColorScheme.light(primary: ProfileColors.prune),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _birthday = picked;
        _errors.remove('birthday');
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final firstName = _firstNameCtrl.text.trim();
    final middleName = _middleCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final birthday = _birthday;

    final errors = <String, String>{
      if (firstName.isEmpty) 'firstName': 'Enter your first name.',
      if (lastName.isEmpty) 'lastName': 'Enter your last name.',
      if (birthday == null) 'birthday': 'Select your birthday.',
    };

    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      _formError = null;
    });

    if (errors.isNotEmpty) {
      HapticFeedback.selectionClick();
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await RiderApi.instance.updateRiderProfile(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        birthday: _isoDate(birthday!),
      );
      final updatedName = _text(updated['name']);
      if (updatedName != null) {
        await RiderApi.instance.saveRiderName(updatedName);
      }
      if (!mounted) return;
      setState(() {
        _rider = updated;
        _editing = false;
        _saving = false;
      });
      // The Profile tab header reads the name from storage.
      RiderApi.instance.notifyProfileChanged();
      _showSnack('Personal information updated.');
    } on RiderApiException catch (error) {
      if (mounted) {
        setState(() {
          _formError = error.message;
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _formError =
              'Could not save your changes. Check your connection and try again.';
          _saving = false;
        });
      }
    }
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;

    final source = await _pickPhotoSource();
    if (source == null || !mounted) return;

    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
    } catch (_) {
      if (mounted) _showSnack('The camera or gallery could not be opened.');
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final updated = await RiderApi.instance.uploadProfilePicture(file.path);
      if (!mounted) return;
      setState(() {
        _rider = updated;
        _uploadingPhoto = false;
      });
      RiderApi.instance.notifyProfileChanged();
      _showSnack('Profile picture updated.');
    } on RiderApiException catch (error) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        _showSnack(error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        _showSnack('Could not upload your photo. Check your connection and try again.');
      }
    }
  }

  Future<ImageSource?> _pickPhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ProfileColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const ProfileSectionTitle(
              title: 'Profile picture',
              caption: 'Use a clear photo of your face',
            ),
            const SizedBox(height: 14),
            _PhotoOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take a Photo',
              subtitle: 'Use your camera',
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _PhotoOption(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Pick an existing photo from your device',
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ProfilePageScaffold(
      title: 'Personal Information',
      subtitle: _editing
          ? 'Edit the name and birthday on your rider record'
          : 'The details on file for your rider account',
      icon: Icons.person_outline_rounded,
      action: _buildHeaderAction(),
      child: _buildBody(),
    );
  }

  Widget? _buildHeaderAction() {
    if (_loading || _rider == null) return null;
    if (_editing) {
      return TextButton(
        onPressed: _saving ? null : _cancelEditing,
        style: _linkStyle,
        child: const Text('Cancel'),
      );
    }
    return TextButton.icon(
      onPressed: _startEditing,
      icon: const Icon(Icons.edit_outlined, size: 16),
      label: const Text('Edit'),
      style: _linkStyle,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const ProfileStateCard(
        icon: Icons.person_outline_rounded,
        title: 'Loading your details…',
        message: 'This only takes a moment.',
        busy: true,
      );
    }

    final rider = _rider;
    if (_error != null || rider == null) {
      return ProfileStateCard(
        icon: Icons.cloud_off_rounded,
        title: 'Your details could not load',
        message: _error ?? 'Try again in a moment.',
        onRetry: _load,
      );
    }

    final details = _map(rider['details']);
    final address = _map(details['address']);
    final name = _text(rider['name']) ?? 'Rider';
    final email = _text(rider['email']);
    final phone = _text(rider['phone_number']);
    final hub = _text(_map(rider['station_hub'])['name']);
    final center = _text(_map(rider['logistics_center'])['name']);
    final riderId = rider['id']?.toString();
    final birthday = _text(details['birthday']);
    final age = details['age']?.toString();
    final photoUrl = _text(rider['profile_picture']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IdentityCard(
          name: name,
          email: email,
          hub: hub,
          riderId: riderId,
          photoUrl: photoUrl,
          uploadingPhoto: _uploadingPhoto,
          onChangePhoto: _changePhoto,
        ),
        const SizedBox(height: 24),
        if (_editing)
          _buildEditForm()
        else
          ProfileSection(
            title: 'Personal details',
            children: [
              ProfileInfoRow(
                icon: Icons.badge_outlined,
                label: 'Full name',
                value: name,
              ),
              ProfileInfoRow(
                icon: Icons.wc_rounded,
                label: 'Sex',
                value: _capitalize(_text(details['sex'])),
              ),
              ProfileInfoRow(
                icon: Icons.cake_outlined,
                label: 'Birthday',
                value: birthday == null ? null : formatLongDate(birthday),
                hint: 'Not on file',
                trailing: age == null
                    ? null
                    : ProfileStatusPill(label: '$age yrs'),
              ),
              ProfileInfoRow(
                icon: Icons.tag_rounded,
                label: 'Rider ID',
                value: riderId == null ? null : '#$riderId',
              ),
            ],
          ),
        const SizedBox(height: 22),
        ProfileSection(
          title: 'Contact',
          caption: 'How your Station Hub reaches you about deliveries',
          children: [
            ProfileInfoRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email address',
              value: email,
            ),
            ProfileInfoRow(
              icon: Icons.phone_outlined,
              label: 'Mobile number',
              value: phone,
            ),
          ],
        ),
        const SizedBox(height: 22),
        ProfileSection(
          title: 'Home address',
          caption: 'Used to match you with a Station Hub',
          children: [
            ProfileInfoRow(
              icon: Icons.home_outlined,
              label: 'Street',
              value: _text(address['street']),
            ),
            ProfileInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Barangay',
              value: _text(address['barangay']),
            ),
            ProfileInfoRow(
              icon: Icons.location_city_outlined,
              label: 'Municipality / City',
              value: _text(address['municipality']),
            ),
            ProfileInfoRow(
              icon: Icons.map_outlined,
              label: 'Province',
              value: _text(address['province']),
            ),
            ProfileInfoRow(
              icon: Icons.markunread_mailbox_outlined,
              label: 'ZIP code',
              value: _text(address['zip_code']),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ProfileSection(
          title: 'Assignment',
          children: [
            ProfileInfoRow(
              icon: Icons.business_outlined,
              label: 'Logistics center',
              value: center,
            ),
            ProfileInfoRow(
              icon: Icons.warehouse_outlined,
              label: 'Station hub',
              value: hub,
            ),
            ProfileInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Rider since',
              value: _joinedLabel(rider['joined_at']),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_editing)
          const ProfileNote(
            text:
                'Keep your name and birthday matching your driver\'s licence. Saving updates your rider record; your Station Hub still handles your contact details, address, vehicle, and documents.',
          )
        else
          const ProfileNote(
            text:
                'Tap your photo or Change photo to update your picture, and use Edit to change your name or birthday. Your contact details, home address, vehicle, and documents are the ones your Station Hub approved — ask your hub to correct those.',
          ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProfileSectionTitle(
          title: 'Name & birthday',
          caption: 'The identity details on your rider record',
        ),
        const SizedBox(height: 10),
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileTextField(
                controller: _firstNameCtrl,
                label: 'First name',
                hint: 'Enter your first name',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                errorText: _errors['firstName'],
                onChanged: (_) => _clearError('firstName'),
              ),
              const SizedBox(height: 16),
              ProfileTextField(
                controller: _middleCtrl,
                label: 'Middle initial (optional)',
                hint: 'e.g. A',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(1)],
                errorText: _errors['middle'],
                onChanged: (_) => _clearError('middle'),
              ),
              const SizedBox(height: 16),
              ProfileTextField(
                controller: _lastNameCtrl,
                label: 'Last name',
                hint: 'Enter your last name',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                errorText: _errors['lastName'],
                onChanged: (_) => _clearError('lastName'),
              ),
              const SizedBox(height: 16),
              _BirthdayField(
                value: _birthday,
                errorText: _errors['birthday'],
                onTap: _pickBirthday,
              ),
            ],
          ),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 16),
          _FormErrorBanner(message: _formError!),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: ProfileColors.prune,
              disabledBackgroundColor: ProfileColors.prune,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: ProfileColors.lin,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Saving…',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String? _joinedLabel(dynamic raw) {
    final joined = _text(raw);
    if (joined == null) return null;
    final date = formatLongDate(joined);
    return date.isEmpty ? joined : date;
  }
}

// ── Birthday picker row ─────────────────────────────────────────────────────
class _BirthdayField extends StatelessWidget {
  const _BirthdayField({
    required this.value,
    required this.onTap,
    required this.errorText,
  });

  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Birthday',
          style: TextStyle(
            color: ProfileColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: ProfileColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError ? ProfileColors.brique : ProfileColors.border,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cake_outlined,
                  color: ProfileColors.raisin,
                  size: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value == null
                        ? 'Select your birthday'
                        : formatLongDate(value!.toIso8601String()),
                    style: TextStyle(
                      color: value == null
                          ? ProfileColors.muted
                          : ProfileColors.ink,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  color: ProfileColors.muted,
                  size: 17,
                ),
              ],
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

// ── Server error shown above the save button ────────────────────────────────
class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF1EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D3C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: ProfileColors.brique,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ProfileColors.brique,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo source option on the bottom sheet ─────────────────────────────────
class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ProfileColors.background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ProfileColors.raisinSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: ProfileColors.raisin, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ProfileColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ProfileColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ProfileColors.muted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header summary: photo, name, email, status, with photo change action ────
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.name,
    required this.email,
    required this.hub,
    required this.riderId,
    required this.photoUrl,
    required this.uploadingPhoto,
    required this.onChangePhoto,
  });

  final String name;
  final String? email;
  final String? hub;
  final String? riderId;
  final String? photoUrl;
  final bool uploadingPhoto;
  final VoidCallback onChangePhoto;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _initialsCircle() {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ProfileColors.pruneLight, ProfileColors.prune],
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          color: ProfileColors.lin,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: uploadingPhoto ? null : onChangePhoto,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 66,
              height: 66,
              child: Stack(
                children: [
                  photoUrl == null
                      ? _initialsCircle()
                      : ClipOval(
                          child: Image.network(
                            photoUrl!,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _initialsCircle(),
                          ),
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: ProfileColors.brique,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: uploadingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ProfileColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ProfileColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const ProfileStatusPill(label: 'Approved rider'),
                    if (riderId != null)
                      Text(
                        'ID #$riderId',
                        style: const TextStyle(
                          color: ProfileColors.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                if (hub != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.warehouse_outlined,
                        size: 13,
                        color: ProfileColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          hub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ProfileColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: uploadingPhoto ? null : onChangePhoto,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      uploadingPhoto ? 'Uploading photo…' : 'Change photo',
                      style: const TextStyle(
                        color: ProfileColors.raisin,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

// ── Small JSON helpers (the API may omit fields) ────────────────────────────
Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

String? _capitalize(String? value) {
  if (value == null || value.isEmpty) return null;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
