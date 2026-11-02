import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_driver/core/api/driver_api.dart';
import 'package:vendo_driver/core/theme/vendo_theme.dart';
import 'package:vendo_driver/features/auth/widgets/register_widgets.dart';

/// Transport Driver registration.
///
/// Same layout, colours, fields, buttons and step flow as the Rider
/// registration, with the driver-only fields (vehicle and licence) and the
/// Apply-to choice: Station Hub, Province Hub, or both.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  static const int _totalSteps = 4;

  static const List<String> _stepLabels = [
    'Personal Info',
    'Address & Contact',
    'Vehicle & Licence',
    'Apply & Review',
  ];

  static const List<IconData> _stepIcons = [
    Icons.person_outline_rounded,
    Icons.location_on_outlined,
    Icons.local_shipping_outlined,
    Icons.fact_check_outlined,
  ];

  static const List<String> _nextLabels = [
    'Next: Address & Contact',
    'Next: Vehicle & Licence',
    'Next: Apply & Review',
    'Submit application',
  ];

  static const List<String> _applyOrder = ['station', 'province', 'both'];

  static const Map<String, String> _applyTitles = {
    'station': 'Station Hub only',
    'province': 'Province Hub only',
    'both': 'Both hubs',
  };

  static const Map<String, String> _applySubtitles = {
    'station':
        'You move parcels between Station Hubs. The Station Hub you choose approves your application.',
    'province':
        'You drive hub to hub trips. The Province Hub approves, and we link you to the Station Hub where you live.',
    'both':
        'Only the Province Hub approves. Your Station Hub can still see your details, but it does not approve you.',
  };

  static const Map<String, String> _applyBadges = {
    'station': 'STATION REVIEWS',
    'province': 'PROVINCE REVIEWS',
    'both': 'PROVINCE REVIEWS',
  };

  static const List<String> _vehicleTypes = [
    'L300 Van',
    'Closed Van',
    '6-Wheeler Truck',
    '10-Wheeler Truck',
    'Truck',
  ];

  static const List<String> _licenseCategories = [
    'Non-Professional',
    'Professional',
  ];

  final _scroll = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Step 1 — personal information.
  final _lastName = TextEditingController();
  final _firstName = TextEditingController();
  final _middleInitial = TextEditingController();
  final _email = TextEditingController();
  final _birthday = TextEditingController();
  final _age = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _sex;
  String? _emailVerificationToken;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _validIdName;
  String? _validIdPath;

  // Step 2 — address and contact.
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _zip = TextEditingController();
  Map<String, dynamic> _provinces = {};
  Map<String, dynamic> _barangays = {};
  String? _provinceCode;
  String? _cityCode;
  String? _barangayCode;
  bool _loadingLocations = false;
  bool _loadingBarangays = false;
  String? _locationsError;
  String? _barangaysError;

  // Step 3 — vehicle and licence.
  String? _vehicleType;
  final _plate = TextEditingController();
  final _licenseNumber = TextEditingController();
  final _expiry = TextEditingController();
  String? _licenseCategory;
  DateTime? _licenseExpiry;
  String? _licenseFileName;
  String? _licenseFilePath;

  // Step 4 — apply choice.
  String? _applyTo;
  List<Map<String, dynamic>> _provinceHubs = [];
  List<Map<String, dynamic>> _stationHubs = [];
  bool _loadingHubs = false;
  String? _hubsError;
  String? _provinceHubId;
  String? _stationHubId;
  bool _agreed = false;
  bool _termsError = false;

  int _currentStep = 0;
  bool _submitting = false;
  String? _submitError;
  Set<String> _flagged = {};
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _loadHubs();
  }

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _middleInitial.dispose();
    _email.dispose();
    _birthday.dispose();
    _age.dispose();
    _password.dispose();
    _confirm.dispose();
    _phone.dispose();
    _street.dispose();
    _zip.dispose();
    _plate.dispose();
    _licenseNumber.dispose();
    _expiry.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Server data ─────────────────────────────────────────────────────────

  Future<void> _loadLocations() async {
    setState(() {
      _loadingLocations = true;
      _locationsError = null;
    });
    try {
      final data = await DriverApi.instance.locations();
      if (!mounted) return;
      setState(() {
        _provinces = Map<String, dynamic>.from(data['provinces'] as Map);
        if (_provinces.isEmpty) {
          _locationsError = 'No provinces were returned by the Vendo API.';
        }
      });
    } on DriverApiException catch (error) {
      if (mounted) {
        setState(
          () => _locationsError = '${error.message} API: ${DriverApi.baseUrl}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationsError =
              'Cannot connect to ${DriverApi.baseUrl}. Check that the Laravel server is running.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    setState(() {
      _loadingBarangays = true;
      _barangaysError = null;
      _barangays = {};
    });
    try {
      final data = await DriverApi.instance.barangays(cityCode);
      if (!mounted || _cityCode != cityCode) return;
      setState(() {
        _barangays = Map<String, dynamic>.from(data['barangays'] as Map);
        if (_barangays.isEmpty) {
          _barangaysError = 'No barangays were returned for this city.';
        }
      });
    } on DriverApiException catch (error) {
      if (mounted && _cityCode == cityCode) {
        setState(() => _barangaysError = error.message);
      }
    } catch (_) {
      if (mounted && _cityCode == cityCode) {
        setState(
          () => _barangaysError =
              'Cannot load barangays from ${DriverApi.baseUrl}.',
        );
      }
    } finally {
      if (mounted && _cityCode == cityCode) {
        setState(() => _loadingBarangays = false);
      }
    }
  }

  Future<void> _loadHubs() async {
    setState(() {
      _loadingHubs = true;
      _hubsError = null;
    });
    try {
      final data = await DriverApi.instance.hubs();
      if (!mounted) return;
      setState(() {
        _provinceHubs = (data['province_hubs'] as List<dynamic>? ?? [])
            .map((hub) => Map<String, dynamic>.from(hub as Map))
            .toList();
        _stationHubs = (data['station_hubs'] as List<dynamic>? ?? [])
            .map((hub) => Map<String, dynamic>.from(hub as Map))
            .toList();
        if (_provinceHubs.isEmpty) {
          _hubsError = 'No Province Hub is accepting applications right now.';
        }
      });
    } on DriverApiException catch (error) {
      if (mounted) setState(() => _hubsError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _hubsError =
              'Cannot load the hub list from ${DriverApi.baseUrl}.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHubs = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool _blank(TextEditingController controller) =>
      controller.text.trim().isEmpty;

  String _fmtDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get _provinceName =>
      (_provinces[_provinceCode]?['name'] ?? '').toString();

  String get _cityName {
    final cities = _provinces[_provinceCode]?['cities'];
    if (cities is Map && _cityCode != null) {
      return (cities[_cityCode] ?? '').toString();
    }
    return '';
  }

  String get _barangayName => (_barangays[_barangayCode] ?? '').toString();

  String _hubName(List<Map<String, dynamic>> hubs, String? id, String fallback) {
    for (final hub in hubs) {
      if (hub['id']?.toString() == id) return hub['name']?.toString() ?? fallback;
    }
    return fallback;
  }

  Map<String, dynamic>? get _selectedProvinceHub {
    for (final hub in _provinceHubs) {
      if (hub['id']?.toString() == _provinceHubId) return hub;
    }
    return null;
  }

  /// The Station Hub the address points at, when the list already has one in
  /// that municipality. The server makes the final match.
  Map<String, dynamic>? get _stationInMyCity {
    for (final hub in _stationHubs) {
      if (_cityCode != null && hub['municipality_code']?.toString() == _cityCode) {
        return hub;
      }
    }
    return null;
  }

  String get _stationAssignmentNote {
    if (_applyTo == 'station') {
      return 'This Station Hub reviews your application. You will drive station to station.';
    }
    final match = _stationInMyCity;
    if (match != null) {
      return 'You will be linked to ${match['name']} because it covers $_cityName.';
    }
    if (_cityCode == null) {
      return 'Choose your municipality in the previous step so we can link you to the nearest Station Hub.';
    }
    return 'No Station Hub in $_cityName. The nearest one in your area will be used.';
  }

  void _scrollTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _scrollToField(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      }
    });
  }

  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _invalidIds(int step) {
    final checks = <(String, bool)>[];
    if (step == 0) {
      checks.addAll([
        ('lastName', _blank(_lastName)),
        ('firstName', _blank(_firstName)),
        ('sex', _sex == null),
        ('email', _blank(_email) || !_email.text.contains('@')),
        ('emailVerify', _emailVerificationToken == null),
        ('birthday', _birthday.text.isEmpty),
        ('password', _password.text.length < 8),
        (
          'confirm',
          _confirm.text.isEmpty || _confirm.text != _password.text,
        ),
        ('validId', _validIdPath == null),
      ]);
    } else if (step == 1) {
      checks.addAll([
        ('phone', !RegExp(r'^09\d{9}$').hasMatch(_phone.text.trim())),
        ('province', _provinceCode == null),
        ('city', _cityCode == null),
        ('barangay', _barangayCode == null),
        ('street', _blank(_street)),
        ('zip', _blank(_zip)),
      ]);
    } else if (step == 2) {
      checks.addAll([
        ('vehicleType', _vehicleType == null),
        ('plate', _blank(_plate)),
        ('licenseNumber', _blank(_licenseNumber)),
        ('licenseCategory', _licenseCategory == null),
        ('licenseExpiry', _licenseExpiry == null),
        ('licenseFile', _licenseFilePath == null),
      ]);
    } else {
      checks.addAll([
        ('applyTo', _applyTo == null),
        (
          'hub',
          _applyTo == 'station' ? _stationHubId == null : _provinceHubId == null,
        ),
      ]);
    }
    return [
      for (final check in checks)
        if (check.$2) check.$1,
    ];
  }

  Future<void> _next() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final invalid = _invalidIds(_currentStep);
    if (invalid.isNotEmpty) {
      setState(() => _flagged = invalid.toSet());
      _showMessage('Please complete the fields marked in red.');
      _scrollToField(invalid.first);
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _flagged = {};
        _submitError = null;
      });
      _scrollTop();
      return;
    }
    await _submit();
  }

  void _back() {
    setState(() {
      _currentStep--;
      _flagged = {};
      _submitError = null;
    });
    _scrollTop();
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      _flagged = {};
    });
    _scrollTop();
  }

  // ── Email code ──────────────────────────────────────────────────────────

  /// Opens the 6-digit code sheet, the same one the Rider and Buyer apps use.
  /// The server only accepts the application with the token it returns.
  Future<void> _openVerifyEmail() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showMessage('Enter your email address first.');
      _scrollToField('email');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _flagged = {'email'});
      _showMessage('Enter a valid email address.');
      _scrollToField('email');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerifyEmailModal(
        email: email,
        onVerified: (token) {
          if (!mounted) return;
          setState(() {
            _emailVerificationToken = token;
            _flagged.remove('emailVerify');
          });
        },
      ),
    );
  }

  // ── Files ───────────────────────────────────────────────────────────────

  Future<void> _pickDocument({
    required String title,
    required void Function(XFile file) onPicked,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: VColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Take a photo or choose one from your device.',
                style: TextStyle(color: VColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              _SourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Take a photo',
                subtitle: 'Use the camera to capture the document',
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                subtitle: 'Select an existing photo',
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (file != null) onPicked(file);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open the camera or gallery on this device.');
      }
    }
  }

  Future<void> _pickExpiry() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? DateTime(today.year + 1, today.month, today.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 15, 12, 31),
      helpText: 'Licence expiry date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: VColors.prune),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _licenseExpiry = picked;
      _expiry.text = _fmtDate(picked);
      _flagged.remove('licenseExpiry');
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_agreed) {
      setState(() => _termsError = true);
      _showMessage('Please confirm the declaration before submitting.');
      return;
    }
    if (_emailVerificationToken == null) {
      _goToStep(0);
      setState(() => _flagged = {'emailVerify'});
      _showMessage('Verify your email before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await DriverApi.instance.register(
        {
          'first_name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'middle_name': _middleInitial.text.trim(),
          'email': _email.text.trim(),
          'email_verification_token': _emailVerificationToken!,
          'password': _password.text,
          'password_confirmation': _confirm.text,
          'phone_number': _phone.text.trim().replaceAll(' ', ''),
          'apply_to': _applyTo!,
          if (_applyTo == 'station')
            'station_hub_id': _stationHubId!
          else
            'province_hub_id': _provinceHubId!,
          'province_code': _provinceCode!,
          'city_code': _cityCode!,
          'barangay_code': ?_barangayCode,
          'street': _street.text.trim(),
          'zip_code': _zip.text.trim(),
          'birthday': _isoDateFromSlash(_birthday.text),
          'sex': _sex!.toLowerCase(),
          'vehicle_type': _vehicleType!,
          'plate_number': _plate.text.trim(),
          'license_number': _licenseNumber.text.trim(),
          'license_category': _licenseCategory!,
          'license_expires_at': _isoDate(_licenseExpiry!),
        },
        {
          'drivers_license': _licenseFilePath!,
          'valid_id': _validIdPath!,
        },
      );
      await DriverApi.instance.saveApplicationEmail(_email.text);

      if (!mounted) return;
      final reviewing = (result['reviewing_hub'] as Map?)?['name']?.toString();
      final station = (result['station_hub'] as Map?)?['name']?.toString();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => RegisterSuccessSheet(
          reviewingHub: reviewing ?? 'Your hub',
          applyLabel: (result['apply_label'] ?? '').toString(),
          stationHub: station,
          onDone: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      );
    } on DriverApiException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _submitError =
              'Could not submit the application. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _isoDateFromSlash(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return value;
    return '${parts[2]}-${parts[0]}-${parts[1]}';
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: VColors.prune,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VColors.pruneLight, VColors.prune],
            ),
          ),
          child: Column(
            children: [
              RegisterHeader(
                eyebrow: 'Transport driver',
                title: 'Driver Registration',
                subtitle: 'Create your driver account',
                onBack: () => Navigator.of(context).maybePop(),
                onLogin: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      child: RegFormScope(
                        flagged: _flagged,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RegisterStepBar(
                              currentStep: _currentStep,
                              totalSteps: _totalSteps,
                              labels: _stepLabels,
                              icons: _stepIcons,
                            ),
                            const SizedBox(height: 26),
                            if (_currentStep == 0) _stepPersonal(),
                            if (_currentStep == 1) _stepAddress(),
                            if (_currentStep == 2) _stepVehicle(),
                            if (_currentStep == 3) _stepApply(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: RegisterBottomBar(
          currentStep: _currentStep,
          totalSteps: _totalSteps,
          nextLabels: _nextLabels,
          onNext: _submitting ? null : _next,
          onBack: _currentStep > 0 ? _back : null,
          submitting: _submitting,
        ),
      ),
    );
  }

  Widget _gap({double height = 18}) => SizedBox(height: height);

  Widget _keyed(String id, Widget child) =>
      KeyedSubtree(key: _key(id), child: child);

  // Step 1 ────────────────────────────────────────────────────────────────

  Widget _stepPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RegisterSectionHeader(
          title: 'Personal Information',
          subtitle: 'Tell the hub who you are',
        ),
        _gap(),
        _keyed(
          'lastName',
          RegInput(
            id: 'lastName',
            label: 'Last Name',
            controller: _lastName,
            hint: 'Enter last name',
            icon: Icons.person_outline_rounded,
            required: true,
            keyboard: TextInputType.name,
          ),
        ),
        _gap(),
        _keyed(
          'firstName',
          RegInput(
            id: 'firstName',
            label: 'First Name',
            controller: _firstName,
            hint: 'Enter first name',
            icon: Icons.person_outline_rounded,
            required: true,
            keyboard: TextInputType.name,
          ),
        ),
        _gap(),
        RegInput(
          id: 'middleInitial',
          label: 'Middle Initial',
          controller: _middleInitial,
          hint: 'Enter middle initial',
          icon: Icons.person_outline_rounded,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z.]')),
            LengthLimitingTextInputFormatter(3),
          ],
        ),
        _gap(),
        _keyed(
          'sex',
          RegDropdown(
            id: 'sex',
            label: 'Sex',
            hint: 'Select sex',
            value: _sex,
            required: true,
            items: const [
              RegDropdownItem('Male', 'Male'),
              RegDropdownItem('Female', 'Female'),
            ],
            onChanged: (value) => setState(() {
              _sex = value;
              _flagged.remove('sex');
            }),
          ),
        ),
        _gap(),
        _keyed(
          'email',
          RegInput(
            id: 'email',
            label: 'Email',
            controller: _email,
            hint: 'Enter email address',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            required: true,
            labelAction: _emailVerificationToken != null
                ? const Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: VColors.green,
                        size: 17,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: VColors.green,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: _openVerifyEmail,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        'Verify',
                        style: TextStyle(
                          color: VColors.raisin,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
            onChanged: (_) {
              if (_emailVerificationToken != null) {
                setState(() => _emailVerificationToken = null);
              }
            },
          ),
        ),
        if (_emailVerificationToken == null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              _flagged.contains('emailVerify')
                  ? 'Verify your email with the 6-digit code before continuing.'
                  : 'Tap Verify and enter the 6-digit code we email you.',
              style: TextStyle(
                color: _flagged.contains('emailVerify')
                    ? VColors.red
                    : VColors.muted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        _gap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RegInput(
                id: 'birthday',
                label: 'Birthday',
                controller: _birthday,
                hint: 'mm/dd/yyyy',
                readOnly: true,
                required: true,
                suffix: const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: VColors.muted,
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: VColors.prune,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked == null) return;
                  setState(() {
                    _birthday.text = _fmtDate(picked);
                    _age.text = (DateTime.now().year - picked.year).toString();
                    _flagged.remove('birthday');
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RegInput(
                id: 'age',
                label: 'Age',
                controller: _age,
                hint: '--',
                readOnly: true,
              ),
            ),
          ],
        ),
        _gap(),
        _keyed(
          'validId',
          RegUpload(
            id: 'validId',
            label: 'Valid ID',
            fileName: _validIdName,
            hint: 'Upload your valid ID',
            required: true,
            helper: 'Any government ID with your photo and name.',
            onTap: () => _pickDocument(
              title: 'Upload Valid ID',
              onPicked: (file) => setState(() {
                _validIdName = file.name;
                _validIdPath = file.path;
                _flagged.remove('validId');
              }),
            ),
          ),
        ),
        const SizedBox(height: 26),
        const RegisterSectionHeader(
          title: 'Account Security',
          subtitle: 'Set a password to secure your account',
        ),
        _gap(),
        RegInput(
          id: 'password',
          label: 'Password',
          controller: _password,
          hint: 'Create a password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          required: true,
          forceError: _flagged.contains('password') && _password.text.isNotEmpty,
          errorText: 'Password must be at least 8 characters.',
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 22,
              color: VColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            'Minimum 8 characters with letters and numbers',
            style: TextStyle(color: VColors.muted, fontSize: 11.5),
          ),
        ),
        _gap(),
        RegInput(
          id: 'confirm',
          label: 'Confirm Password',
          controller: _confirm,
          hint: 'Confirm your password',
          icon: Icons.lock_outline_rounded,
          obscure: _obscureConfirm,
          required: true,
          forceError: _flagged.contains('confirm') && _confirm.text.isNotEmpty,
          errorText: 'Passwords do not match.',
          suffix: GestureDetector(
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              _obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 22,
              color: VColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  // Step 2 ────────────────────────────────────────────────────────────────

  Widget _stepAddress() {
    final cities =
        (_provinces[_provinceCode]?['cities'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RegisterSectionHeader(
          title: 'Address & Contact',
          subtitle: 'The hub uses this to reach you and link your Station Hub',
        ),
        _gap(),
        _keyed(
          'phone',
          RegInput(
            id: 'phone',
            label: 'Mobile number',
            controller: _phone,
            hint: '09XX XXX XXXX',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            required: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              LengthLimitingTextInputFormatter(11),
            ],
          ),
        ),
        _gap(),
        _keyed(
          'province',
          RegDropdown(
            id: 'province',
            label: 'Province',
            hint: _loadingLocations ? 'Loading…' : 'Select province',
            value: _provinceCode,
            required: true,
            emptyNote: _locationsError,
            items: _provinces.entries
                .map(
                  (entry) => RegDropdownItem(
                    entry.key,
                    (entry.value as Map)['name'].toString(),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _provinceCode = value;
                _cityCode = null;
                _barangayCode = null;
                _barangays = {};
                _flagged.remove('province');
              });
            },
          ),
        ),
        _gap(),
        _keyed(
          'city',
          RegDropdown(
            id: 'city',
            label: 'City / Municipality',
            hint: 'Select city or municipality',
            value: _cityCode,
            required: true,
            items: cities.entries
                .map(
                  (entry) => RegDropdownItem(entry.key, entry.value.toString()),
                )
                .toList(),
            emptyNote: _provinceCode == null
                ? 'Choose a province first.'
                : null,
            onChanged: (value) {
              setState(() {
                _cityCode = value;
                _barangayCode = null;
                _flagged.remove('city');
              });
              if (value != null) _loadBarangays(value);
            },
          ),
        ),
        _gap(),
        _keyed(
          'barangay',
          RegDropdown(
            id: 'barangay',
            label: 'Barangay',
            hint: _loadingBarangays ? 'Loading…' : 'Select barangay',
            value: _barangayCode,
            required: true,
            items: _barangays.entries
                .map(
                  (entry) => RegDropdownItem(entry.key, entry.value.toString()),
                )
                .toList(),
            emptyNote: _barangaysError,
            onChanged: (value) => setState(() {
              _barangayCode = value;
              _flagged.remove('barangay');
            }),
          ),
        ),
        _gap(),
        _keyed(
          'street',
          RegInput(
            id: 'street',
            label: 'House number, street, purok',
            controller: _street,
            hint: 'e.g. 24 Rizal Street, Purok 2',
            icon: Icons.home_outlined,
            required: true,
          ),
        ),
        _gap(),
        _keyed(
          'zip',
          RegInput(
            id: 'zip',
            label: 'ZIP code',
            controller: _zip,
            hint: 'e.g. 4000',
            icon: Icons.markunread_mailbox_outlined,
            keyboard: TextInputType.number,
            required: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3 ────────────────────────────────────────────────────────────────

  Widget _stepVehicle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RegisterSectionHeader(
          title: 'Vehicle & Licence',
          subtitle: 'The hub checks these before approving you',
        ),
        _gap(),
        _keyed(
          'vehicleType',
          RegDropdown(
            id: 'vehicleType',
            label: 'Vehicle type',
            hint: 'Select vehicle type',
            value: _vehicleType,
            required: true,
            items: _vehicleTypes
                .map((type) => RegDropdownItem(type, type))
                .toList(),
            onChanged: (value) => setState(() {
              _vehicleType = value;
              _flagged.remove('vehicleType');
            }),
          ),
        ),
        _gap(),
        _keyed(
          'plate',
          RegInput(
            id: 'plate',
            label: 'Plate number',
            controller: _plate,
            hint: 'e.g. NBC 4821',
            icon: Icons.pin_outlined,
            required: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
              LengthLimitingTextInputFormatter(12),
            ],
          ),
        ),
        _gap(),
        _keyed(
          'licenseNumber',
          RegInput(
            id: 'licenseNumber',
            label: 'Licence number',
            controller: _licenseNumber,
            hint: 'e.g. N02-24-118942',
            icon: Icons.badge_outlined,
            required: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              LengthLimitingTextInputFormatter(20),
            ],
          ),
        ),
        _gap(),
        _keyed(
          'licenseCategory',
          RegDropdown(
            id: 'licenseCategory',
            label: 'Licence category',
            hint: 'Select category',
            value: _licenseCategory,
            required: true,
            items: _licenseCategories
                .map((category) => RegDropdownItem(category, category))
                .toList(),
            onChanged: (value) => setState(() {
              _licenseCategory = value;
              _flagged.remove('licenseCategory');
            }),
          ),
        ),
        _gap(),
        _keyed(
          'licenseExpiry',
          RegInput(
            id: 'licenseExpiry',
            label: 'Licence expiry',
            controller: _expiry,
            hint: 'Select expiry date',
            icon: Icons.event_outlined,
            readOnly: true,
            required: true,
            onTap: _pickExpiry,
            suffix: const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: VColors.muted,
            ),
          ),
        ),
        _gap(),
        _keyed(
          'licenseFile',
          RegUpload(
            id: 'licenseFile',
            label: "Driver's Licence",
            fileName: _licenseFileName,
            hint: "Upload Driver's Licence",
            required: true,
            helper: 'Make sure the number and expiry date are readable.',
            onTap: () => _pickDocument(
              title: "Upload Driver's Licence",
              onPicked: (file) => setState(() {
                _licenseFileName = file.name;
                _licenseFilePath = file.path;
                _flagged.remove('licenseFile');
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VColors.goldSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: VColors.prune, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The vehicle you drive on trips is assigned by the hub. '
                  'The plate here is the one printed on your application.',
                  style: TextStyle(
                    color: VColors.ink,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 4 ────────────────────────────────────────────────────────────────

  Widget _stepApply() {
    final stationItems = _stationHubs
        .map(
          (hub) => RegDropdownItem(
            hub['id'].toString(),
            '${hub['name']} — ${hub['municipality'] ?? hub['province']}',
          ),
        )
        .toList();
    final provinceItems = _provinceHubs
        .map(
          (hub) => RegDropdownItem(
            hub['id'].toString(),
            '${hub['name']} — ${hub['province']}',
          ),
        )
        .toList();
    final reviewHub = _applyTo == 'station'
        ? _hubName(_stationHubs, _stationHubId, 'Station Hub')
        : (_selectedProvinceHub?['name']?.toString() ?? 'Province Hub');
    final bothNote = _applyTo == 'both'
        ? 'Your Station Hub can see your details but does not approve you. '
        : '';
    final applyNote =
        '$reviewHub reviews this application. $bothNote$_stationAssignmentNote';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RegisterSectionHeader(
          title: 'Where do you want to apply?',
          subtitle: 'This decides which hub reviews and approves you',
        ),
        const SizedBox(height: 14),
        if (_hubsError != null) ...[
          RegErrorNote(message: _hubsError!),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadingHubs ? null : _loadHubs,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ),
          const SizedBox(height: 6),
        ],
        _keyed(
          'applyTo',
          Column(
            children: [
              for (final value in _applyOrder) ...[
                RegChoiceCard(
                  title: _applyTitles[value]!,
                  subtitle: _applySubtitles[value]!,
                  icon: value == 'station'
                      ? Icons.storefront_outlined
                      : value == 'province'
                      ? Icons.account_balance_outlined
                      : Icons.hub_outlined,
                  badge: _applyBadges[value],
                  selected: _applyTo == value,
                  flagged: _flagged.contains('applyTo'),
                  onTap: () => setState(() {
                    _applyTo = value;
                    _flagged.remove('applyTo');
                    _flagged.remove('hub');
                  }),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (_applyTo == 'station')
          _keyed(
            'hub',
            RegDropdown(
              id: 'hub',
              label: 'Station Hub you are applying to',
              hint: _loadingHubs ? 'Loading…' : 'Select Station Hub',
              value: _stationHubId,
              required: true,
              items: stationItems,
              emptyNote: stationItems.isEmpty && !_loadingHubs
                  ? 'No Station Hub is accepting applications yet.'
                  : null,
              onChanged: (value) => setState(() {
                _stationHubId = value;
                _flagged.remove('hub');
              }),
            ),
          )
        else if (_applyTo != null)
          _keyed(
            'hub',
            RegDropdown(
              id: 'hub',
              label: 'Province Hub you are applying to',
              hint: _loadingHubs ? 'Loading…' : 'Select Province Hub',
              value: _provinceHubId,
              required: true,
              items: provinceItems,
              emptyNote: provinceItems.isEmpty && !_loadingHubs
                  ? 'No Province Hub is accepting applications yet.'
                  : null,
              onChanged: (value) => setState(() {
                _provinceHubId = value;
                _flagged.remove('hub');
              }),
            ),
          ),
        if (_applyTo != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VColors.raisinSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: VColors.raisin,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    applyNote,
                    style: const TextStyle(
                      color: VColors.ink,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        RegReviewCard(
          title: 'Personal',
          onEdit: () => _goToStep(0),
          rows: [
            RegReviewRow(
              label: 'Name',
              value: [
                _firstName.text.trim(),
                _middleInitial.text.trim(),
                _lastName.text.trim(),
              ].where((part) => part.isNotEmpty).join(' '),
            ),
            RegReviewRow(label: 'Email', value: _email.text.trim()),
            RegReviewRow(label: 'Birthday', value: _birthday.text),
            RegReviewRow(label: 'Sex', value: _sex ?? ''),
          ],
        ),
        const SizedBox(height: 12),
        RegReviewCard(
          title: 'Address & contact',
          onEdit: () => _goToStep(1),
          rows: [
            RegReviewRow(label: 'Phone', value: _phone.text.trim()),
            RegReviewRow(
              label: 'Address',
              value: [
                _street.text.trim(),
                _barangayName,
                _cityName,
                _provinceName,
              ].where((part) => part.isNotEmpty).join(', '),
            ),
            RegReviewRow(label: 'ZIP', value: _zip.text.trim()),
          ],
        ),
        const SizedBox(height: 12),
        RegReviewCard(
          title: 'Vehicle & licence',
          onEdit: () => _goToStep(2),
          rows: [
            RegReviewRow(label: 'Vehicle', value: _vehicleType ?? ''),
            RegReviewRow(label: 'Plate', value: _plate.text.trim()),
            RegReviewRow(
              label: 'Licence no.',
              value: _licenseNumber.text.trim(),
            ),
            RegReviewRow(label: 'Category', value: _licenseCategory ?? ''),
            RegReviewRow(
              label: 'Expires',
              value: _licenseExpiry == null ? '' : _fmtDate(_licenseExpiry!),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => setState(() {
            _agreed = !_agreed;
            if (_agreed) _termsError = false;
          }),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreed,
                onChanged: (value) => setState(() {
                  _agreed = value ?? false;
                  if (_agreed) _termsError = false;
                }),
                activeColor: VColors.prune,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'I declare that my licence, vehicle and ID details are true and valid. '
                    'I understand the hub may reject my application.',
                    style: TextStyle(
                      color: _termsError ? VColors.red : VColors.muted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_termsError)
          const Padding(
            padding: EdgeInsets.only(left: 34, top: 2),
            child: Text(
              'Please confirm the declaration to submit.',
              style: TextStyle(color: VColors.red, fontSize: 11.5),
            ),
          ),
        if (_submitError != null) ...[
          const SizedBox(height: 14),
          RegErrorNote(message: _submitError!),
        ],
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'You can sign in only after the hub approves your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VColors.muted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verify email sheet
//
// The same six-box code sheet the Rider and Buyer registrations use: opening it
// sends a code straight away, the boxes move on their own, the form submits
// once all six digits are typed, and the token it returns is what the server
// accepts with the application.
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyEmailModal extends StatefulWidget {
  const _VerifyEmailModal({required this.email, required this.onVerified});

  final String email;
  final ValueChanged<String> onVerified;

  @override
  State<_VerifyEmailModal> createState() => _VerifyEmailModalState();
}

class _VerifyEmailModalState extends State<_VerifyEmailModal> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _errorMsg = null;
    });
    try {
      await DriverApi.instance.sendRegistrationCode(widget.email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sending = false;
      });
      _focusNodes.first.requestFocus();
    } on DriverApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _sending = false;
        _codeSent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Could not send the code. Check your connection.';
        _sending = false;
        _codeSent = false;
      });
    }
  }

  Future<void> _verify() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) {
      setState(() => _errorMsg = 'Enter the full 6-digit code.');
      return;
    }
    setState(() {
      _verifying = true;
      _errorMsg = null;
    });
    try {
      final token = await DriverApi.instance.verifyRegistrationCode(
        widget.email,
        code,
      );
      if (!mounted) return;
      widget.onVerified(token);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email verified.')));
    } on DriverApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _verifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Verification failed. Check your connection.';
        _verifying = false;
      });
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Submit once all six digits are in
    if (_otpControllers.every((c) => c.text.length == 1)) {
      _verify();
    }
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(regRadius),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 28 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icon
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: VColors.raisinSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: VColors.prune,
                  size: 38,
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: VColors.prune,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: VColors.lin, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const Text(
            'Verify Your Email',
            style: TextStyle(
              color: VColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sending
                ? 'Sending code to ${widget.email}…'
                : 'We sent a 6-digit code to ${widget.email}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VColors.muted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 46,
                height: 56,
                child: TextField(
                  controller: _otpControllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  enabled: _codeSent && !_verifying,
                  cursorColor: VColors.prune,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: VColors.ink,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: VColors.background,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: _border(VColors.border, 1.2),
                    focusedBorder: _border(VColors.prune, 1.8),
                    disabledBorder: _border(VColors.border, 1.2),
                  ),
                  onChanged: (v) => _onOtpChanged(v, i),
                ),
              );
            }),
          ),

          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VColors.red, fontSize: 13),
            ),
          ],

          const SizedBox(height: 20),

          // Resend
          GestureDetector(
            onTap: (_sending || _verifying) ? null : _sendCode,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sending)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: VColors.raisin,
                    ),
                  )
                else
                  const Icon(
                    Icons.refresh_rounded,
                    color: VColors.raisin,
                    size: 18,
                  ),
                const SizedBox(width: 6),
                const Text(
                  'Resend Code',
                  style: TextStyle(
                    color: VColors.raisin,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_codeSent && !_verifying && !_sending)
                  ? _verify
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: VColors.prune,
                disabledBackgroundColor: VColors.prune,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(regRadius),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: VColors.lin,
                      ),
                    )
                  : const Text(
                      'Verify Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _verifying ? null : () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Change email address',
                style: TextStyle(
                  color: VColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: VColors.raisinSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: VColors.prune, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: VColors.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: VColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: VColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

