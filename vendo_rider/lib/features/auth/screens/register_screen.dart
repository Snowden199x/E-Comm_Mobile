import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_rider/core/api/rider_api.dart';
import 'package:vendo_rider/features/auth/services/license_ocr_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the login screen
//  • Prune   → header, main buttons, main text
//  • Brique  → small accent (required star, active step)
//  • Lin     → soft gold for highlights
//  • Raisin  → icons and links
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
  static const success = Color(0xFF248A5A);
  static const error = Color(0xFFE53935);
  static const errorSoft = Color(0xFFFFF4F3);
}

const double _radius = 14;

// Rider picture size in the header (same 4:3 shape as the login rider)
const double _riderW = 112;
const double _riderH = 84;

// Stable pseudo-random number in [0, 1), so the stars stay in the same places.
double _hash(int n) {
  final x = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

// ── Shared input look (same as the login fields) ────────────────────────────
OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(_radius),
  borderSide: BorderSide(color: color, width: width),
);

InputDecoration _decoration({
  String? hint,
  IconData? icon,
  Widget? suffix,
  bool error = false,
}) {
  final side = error ? _C.error : _C.border;
  final width = error ? 1.6 : 1.2;
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _C.muted, fontSize: 15),
    filled: true,
    fillColor: error ? _C.errorSoft : _C.background,
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: error ? _C.error : _C.raisin, size: 20),
    suffixIcon: suffix == null
        ? null
        : Padding(padding: const EdgeInsets.only(right: 14), child: suffix),
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _border(side, width),
    enabledBorder: _border(side, width),
    disabledBorder: _border(side, width),
    focusedBorder: _border(error ? _C.error : _C.prune, 1.6),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.googleRegistrationToken,
    this.verifiedEmail,
    this.googleFirstName = '',
    this.googleLastName = '',
  });

  final String? googleRegistrationToken;
  final String? verifiedEmail;
  final String googleFirstName;
  final String googleLastName;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0; // 0,1,2,3
  final _scroll = ScrollController();

  // ── Step 1: Personal Information ──────────────────────────────
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleInitialCtrl = TextEditingController();
  String? _selectedSex;
  final _emailCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController();
  String? _emailVerificationToken;
  bool _sendingEmailOtp = false;
  bool _verifyingEmailOtp = false;
  final _birthdayCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _validIdFileName;
  String? _validIdPath;

  // ── Step 2: Vehicle Details ────────────────────────────────────
  String? _vehicleType;
  final _plateNumberCtrl = TextEditingController();
  String? _driversLicenseFile;
  String? _orCrFile;
  String? _driversLicensePath;
  String? _orCrPath;

  // Driver's License info fields
  final _dlLastNameCtrl = TextEditingController();
  final _dlFirstNameCtrl = TextEditingController();
  final _dlMiddleNameCtrl = TextEditingController();
  final _dlAddressCtrl = TextEditingController();
  final _dlLicenseNoCtrl = TextEditingController();
  final _dlExpirationCtrl = TextEditingController();
  final _dlNationalityCtrl = TextEditingController();
  final _dlBloodTypeCtrl = TextEditingController();
  String? _dlRestrictionCode;

  // OR / CR info fields
  bool _scanningLicense = false;
  final _orCrMVFileNoCtrl = TextEditingController();
  final _orCrPlateNoCtrl = TextEditingController();
  final _orCrMakeCtrl = TextEditingController();
  final _orCrSeriesCtrl = TextEditingController();
  final _orCrBodyTypeCtrl = TextEditingController();
  final _orCrColorCtrl = TextEditingController();
  final _orCrEngineNoCtrl = TextEditingController();
  final _orCrChassisNoCtrl = TextEditingController();
  final _orCrYearModelCtrl = TextEditingController();
  final _orCrOwnerCtrl = TextEditingController();
  final _orCrAddressCtrl = TextEditingController();
  final _orCrExpirationCtrl = TextEditingController();

  // ── Step 3: Contact & Address ──────────────────────────────────
  final _phoneCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _zipCodeCtrl = TextEditingController();

  // ── Step 4: Review & Submit ────────────────────────────────────
  bool _agreedToTerms = false;
  bool _submitting = false;
  bool _loadingLocations = false;
  String? _locationsError;
  Map<String, dynamic> _provinces = {};
  Map<String, dynamic> _barangays = {};
  bool _loadingBarangays = false;
  String? _barangaysError;
  String? _provinceCode;
  String? _cityCode;
  String? _barangayCode;
  String? _matchedCenterName;

  // The fields that were wrong at the moment the user tapped Next.
  // Only these go red, and each one goes back to normal once it is fixed.
  Set<String> _flagged = {};
  bool _termsError = false;
  late final Listenable _allInputs;

  static const int _totalSteps = 4;

  final List<String> _sexOptions = ['Male', 'Female'];
  final List<String> _vehicleOptions = ['Motorcycle', 'Van', 'L300', 'Truck'];

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.verifiedEmail ?? '';
    _firstNameCtrl.text = widget.googleFirstName;
    _lastNameCtrl.text = widget.googleLastName;
    _allInputs = Listenable.merge([
      _lastNameCtrl, _firstNameCtrl, _emailCtrl, _birthdayCtrl,
      _passwordCtrl, _confirmPassCtrl, _plateNumberCtrl,
      _dlLastNameCtrl, _dlFirstNameCtrl, _dlAddressCtrl, _dlLicenseNoCtrl,
      _dlExpirationCtrl, _dlNationalityCtrl, _orCrMVFileNoCtrl,
      _orCrPlateNoCtrl, _orCrMakeCtrl, _orCrBodyTypeCtrl, _orCrYearModelCtrl,
      _orCrEngineNoCtrl, _orCrChassisNoCtrl, _orCrOwnerCtrl, _orCrAddressCtrl,
      _orCrExpirationCtrl, _phoneCtrl, _streetCtrl, _zipCodeCtrl,
    ])..addListener(_onInputChanged);
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _loadingLocations = true;
      _locationsError = null;
    });
    try {
      final data = await RiderApi.instance.locations();
      final provinces = Map<String, dynamic>.from(data['provinces'] as Map);
      if (mounted) {
        setState(() {
          _provinces = provinces;
          if (provinces.isEmpty) {
            _locationsError = 'No provinces were returned by the Vendo API.';
          }
        });
      }
    } on RiderApiException catch (error) {
      if (mounted) {
        setState(
          () => _locationsError = '${error.message} API: ${RiderApi.baseUrl}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationsError =
              'Cannot connect to ${RiderApi.baseUrl}. Check that the Laravel server is running.',
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
      final data = await RiderApi.instance.barangays(cityCode);
      if (!mounted || _cityCode != cityCode) return;
      final barangays = Map<String, dynamic>.from(data['barangays'] as Map);
      setState(() {
        _barangays = barangays;
        if (barangays.isEmpty) {
          _barangaysError = 'No barangays were returned for this city.';
        }
      });
    } on RiderApiException catch (error) {
      if (mounted && _cityCode == cityCode) {
        setState(() => _barangaysError = error.message);
      }
    } catch (_) {
      if (mounted && _cityCode == cityCode) {
        setState(
          () => _barangaysError =
              'Cannot load barangays from ${RiderApi.baseUrl}.',
        );
      }
    } finally {
      if (mounted && _cityCode == cityCode) {
        setState(() => _loadingBarangays = false);
      }
    }
  }

  @override
  void dispose() {
    _allInputs.removeListener(_onInputChanged);
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleInitialCtrl.dispose();
    _emailCtrl.dispose();
    _emailOtpCtrl.dispose();
    _birthdayCtrl.dispose();
    _ageCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _plateNumberCtrl.dispose();
    _dlLastNameCtrl.dispose();
    _dlFirstNameCtrl.dispose();
    _dlMiddleNameCtrl.dispose();
    _dlAddressCtrl.dispose();
    _dlLicenseNoCtrl.dispose();
    _dlExpirationCtrl.dispose();
    _dlNationalityCtrl.dispose();
    _dlBloodTypeCtrl.dispose();
    _orCrMVFileNoCtrl.dispose();
    _orCrPlateNoCtrl.dispose();
    _orCrMakeCtrl.dispose();
    _orCrSeriesCtrl.dispose();
    _orCrBodyTypeCtrl.dispose();
    _orCrColorCtrl.dispose();
    _orCrEngineNoCtrl.dispose();
    _orCrChassisNoCtrl.dispose();
    _orCrYearModelCtrl.dispose();
    _orCrOwnerCtrl.dispose();
    _orCrAddressCtrl.dispose();
    _orCrExpirationCtrl.dispose();
    _phoneCtrl.dispose();
    _provinceCtrl.dispose();
    _municipalityCtrl.dispose();
    _barangayCtrl.dispose();
    _streetCtrl.dispose();
    _zipCodeCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendEmailOtp() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _showError('Enter a valid email address first.');
      return;
    }
    setState(() => _sendingEmailOtp = true);
    try {
      await RiderApi.instance.sendRegistrationCode(email);
      if (mounted) _showError('Verification code sent. Check your email.');
    } on RiderApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError(
          'Could not send the code. Check your connection and email setup.',
        );
      }
    } finally {
      if (mounted) setState(() => _sendingEmailOtp = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    setState(() => _verifyingEmailOtp = true);
    try {
      _emailVerificationToken = await RiderApi.instance.verifyRegistrationCode(
        _emailCtrl.text.trim(),
        _emailOtpCtrl.text,
      );
      if (mounted) setState(() {});
    } on RiderApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) _showError('Could not verify the code. Try again.');
    } finally {
      if (mounted) setState(() => _verifyingEmailOtp = false);
    }
  }

  Future<void> _nextStep() async {
    if (_submitting) return;
    if (_currentStep < _totalSteps - 1) {
      final invalid = _invalidIds(_currentStep);
      if (invalid.isNotEmpty) {
        // Snapshot taken NOW: only these fields turn red
        setState(() => _flagged = invalid.toSet());
        _showError('Please complete the fields marked in red.');
        _scrollToField(invalid.first);
        return;
      }
      setState(() {
        _currentStep++;
        _flagged = {};
      });
      _scrollToTop();
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _termsError = true);
      _showError('Please agree to the terms before submitting.');
      return;
    }
    final parts = _birthdayCtrl.text.split('/');
    if (parts.length != 3) {
      _showError('Choose a valid birthday.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await RiderApi.instance.register(
        {
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'middle_name': _middleInitialCtrl.text.trim(),
          'sex': _selectedSex!.toLowerCase(),
          'birthday': '${parts[2]}-${parts[0]}-${parts[1]}',
          'email': _emailCtrl.text.trim(),
          if (widget.googleRegistrationToken != null)
            'google_registration_token': widget.googleRegistrationToken!,
          if (_emailVerificationToken != null)
            'email_verification_token': _emailVerificationToken!,
          'password': _passwordCtrl.text,
          'password_confirmation': _confirmPassCtrl.text,
          'phone_number': _phoneCtrl.text.trim(),
          'province_code': _provinceCode!,
          'city_code': _cityCode!,
          'barangay_code': _barangayCode!,
          'street': _streetCtrl.text.trim(),
          'zip_code': _zipCodeCtrl.text.trim(),
          'vehicle_type': _vehicleType!,
          'plate_number': _plateNumberCtrl.text.trim(),
        },
        {
          'valid_id': _validIdPath!,
          'drivers_license': _driversLicensePath!,
          'or_cr': _orCrPath!,
        },
      );
      if (!mounted) return;
      _matchedCenterName = (result['logistics_center'] as Map)['name']
          ?.toString();
      _showSuccessModal(context);
    } on RiderApiException catch (error) {
      if (mounted) _showError(error.message);
    } catch (_) {
      if (mounted) {
        _showError('Could not submit the application. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessModal(
        centerName: _matchedCenterName,
        onBackToLogin: () => Navigator.of(context).popUntil((r) => r.isFirst),
      ),
    );
  }

  static const _stepLabels = [
    'Personal Info',
    'Vehicle Details',
    'Contact & Address',
    'Review & Submit',
  ];

  static const _stepIcons = [
    Icons.person_outline_rounded,
    Icons.two_wheeler_outlined,
    Icons.location_on_outlined,
    Icons.fact_check_outlined,
  ];

  // ────────────────────────────────────────────────────────────────
  // Page layout: purple header with the rider + rounded white card
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_flagged.isNotEmpty) _flagged.retainAll(_invalidIds(_currentStep));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons because the header is dark
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.prune,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_C.pruneLight, _C.prune],
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context),
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
                  child: SingleChildScrollView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MobileStepBar(
                          currentStep: _currentStep,
                          totalSteps: _totalSteps,
                          labels: _stepLabels,
                          icons: _stepIcons,
                        ),
                        const SizedBox(height: 28),
                        if (_currentStep == 0) _buildStep1(),
                        if (_currentStep == 1) _buildStep2(),
                        if (_currentStep == 2) _buildStep3(),
                        if (_currentStep == 3) _buildStep4(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomNextBar(
          currentStep: _currentStep,
          totalSteps: _totalSteps,
          onNext: _submitting ? null : _nextStep,
          submitting: _submitting,
          onBack: _currentStep > 0 ? _goBack : null,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return ClipRect(
      child: Stack(
        children: [
          // Soft circles and stars (still, not moving)
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _DecorPainter())),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 26),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _C.lin, width: 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: _C.lin,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // The rider hides while the keyboard is open to save space
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: keyboardOpen
                      ? const SizedBox(width: double.infinity)
                      : const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: _riderW,
                            height: _riderH,
                            child: _RiderPicture(),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rider Registration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create your rider account',
                  style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Small helpers to keep the steps short
  // ────────────────────────────────────────────────────────────────
  static const SizedBox _gap = SizedBox(height: 18);

  bool _blank(TextEditingController c) => c.text.trim().isEmpty;

  // While the user fixes a red field, it turns normal. It never turns red
  // again by itself: only the next tap on Next can do that.
  void _onInputChanged() {
    if (_flagged.isEmpty) return;
    final still = _invalidIds(_currentStep).toSet();
    if (_flagged.any((id) => !still.contains(id))) {
      setState(() => _flagged.retainAll(still));
    }
  }

  void _goBack() {
    setState(() {
      _currentStep--;
      _flagged = {};
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _scrollToField(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = (_keys[id] ?? _keys['email'])?.currentContext;
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

  // Every field (in screen order) that is empty or not valid.
  // Every field marked with a red * is checked here.
  List<String> _invalidIds(int step) {
    final checks = <(String, bool)>[];
    if (step == 0) {
      checks.addAll([
        ('lastName', _blank(_lastNameCtrl)),
        ('firstName', _blank(_firstNameCtrl)),
        ('sex', _selectedSex == null),
        ('email', _blank(_emailCtrl)),
        (
          'emailVerify',
          widget.googleRegistrationToken == null &&
              _emailVerificationToken == null,
        ),
        ('birthday', _birthdayCtrl.text.isEmpty),
        ('password', _passwordCtrl.text.length < 8),
        (
          'confirm',
          _confirmPassCtrl.text.isEmpty ||
              _passwordCtrl.text != _confirmPassCtrl.text,
        ),
        ('validId', _validIdPath == null),
      ]);
    } else if (step == 1) {
      checks.addAll([
        ('vehicleType', _vehicleType == null),
        ('plate', _blank(_plateNumberCtrl)),
        ('license', _driversLicensePath == null),
        ('dlLast', _blank(_dlLastNameCtrl)),
        ('dlFirst', _blank(_dlFirstNameCtrl)),
        ('dlAddress', _blank(_dlAddressCtrl)),
        ('dlLicenseNo', _blank(_dlLicenseNoCtrl)),
        ('dlExpiration', _blank(_dlExpirationCtrl)),
        ('dlNationality', _blank(_dlNationalityCtrl)),
        ('dlCode', _dlRestrictionCode == null),
        ('orCr', _orCrPath == null),
        ('mvFile', _blank(_orCrMVFileNoCtrl)),
        ('orPlate', _blank(_orCrPlateNoCtrl)),
        ('make', _blank(_orCrMakeCtrl)),
        ('body', _blank(_orCrBodyTypeCtrl)),
        ('year', _blank(_orCrYearModelCtrl)),
        ('engine', _blank(_orCrEngineNoCtrl)),
        ('chassis', _blank(_orCrChassisNoCtrl)),
        ('owner', _blank(_orCrOwnerCtrl)),
        ('ownerAddress', _blank(_orCrAddressCtrl)),
        ('regExp', _blank(_orCrExpirationCtrl)),
      ]);
    } else if (step == 2) {
      checks.addAll([
        ('phone', _blank(_phoneCtrl)),
        ('province', _provinceCode == null),
        ('city', _cityCode == null),
        ('barangay', _barangayCode == null),
        ('street', _blank(_streetCtrl)),
        ('zip', _blank(_zipCodeCtrl)),
      ]);
    }
    return [for (final c in checks) if (c.$2) c.$1];
  }

  // One key per field, so the page can scroll to the first red one
  final Map<String, GlobalKey> _keys = {};
  GlobalKey _k(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  Widget _col(String id, String label, Widget child, {bool required = false}) {
    return KeyedSubtree(
      key: _k(id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          const SizedBox(height: 8),
          // Tells the field below it which id it has, so it can check if it is flagged
          _FieldScope(id: id, flagged: _flagged, child: child),
        ],
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  String _fmtDate(DateTime p) =>
      '${p.month.toString().padLeft(2, '0')}/${p.day.toString().padLeft(2, '0')}/${p.year}';

  Future<DateTime?> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: _C.prune),
        ),
        child: child!,
      ),
    );
  }

  // Date field that opens a date picker for a date in the future
  Widget _futureDateField(TextEditingController controller) {
    return _Field(
      controller: controller,
      hint: 'mm/dd/yyyy',
      readOnly: true,
      suffix: const Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: _C.muted,
      ),
      onTap: () async {
        final p = await _pickDate(
          initial: DateTime.now().add(const Duration(days: 365)),
          first: DateTime.now(),
          last: DateTime(2060),
        );
        if (p != null) {
          controller.text = _fmtDate(p);
          setState(() {});
        }
      },
    );
  }

  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    foregroundColor: _C.raisin,
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  );

  // ────────────────────────────────────────────────────────────────
  // STEP 1 — Personal Information
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Personal Information',
          subtitle: 'Please provide your personal details',
        ),
        const SizedBox(height: 18),

        _col(
          'lastName',
          'Last Name',
          _Field(
            controller: _lastNameCtrl,
            hint: 'Enter last name',
            icon: Icons.person_outline_rounded,
          ),
          required: true,
        ),
        _gap,
        _col(
          'firstName',
          'First Name',
          _Field(
            controller: _firstNameCtrl,
            hint: 'Enter first name',
            icon: Icons.person_outline_rounded,
          ),
          required: true,
        ),
        _gap,
        _col(
          'middleInitial',
          'Middle Initial',
          _Field(
            controller: _middleInitialCtrl,
            hint: 'Enter middle initial',
            icon: Icons.person_outline_rounded,
          ),
        ),
        _gap,
        _col(
          'sex',
          'Sex',
          _Dropdown(
            value: _selectedSex,
            hint: 'Select Sex',
            options: _sexOptions,
            onChanged: (v) => setState(() => _selectedSex = v),
          ),
          required: true,
        ),
        _gap,

        _col(
          'email',
          'Email',
          _Field(
            controller: _emailCtrl,
            hint: 'Enter email address',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            readOnly: widget.googleRegistrationToken != null,
            onChanged: widget.googleRegistrationToken != null
                ? null
                : (_) {
                    if (_emailVerificationToken != null) {
                      setState(() => _emailVerificationToken = null);
                    }
                  },
          ),
          required: true,
        ),
        const SizedBox(height: 10),
        if (widget.googleRegistrationToken != null)
          const Row(
            children: [
              Icon(Icons.verified, color: _C.success, size: 18),
              SizedBox(width: 6),
              Text('Verified with Google', style: TextStyle(color: _C.success)),
            ],
          )
        else if (_emailVerificationToken != null)
          const Row(
            children: [
              Icon(Icons.verified, color: _C.success, size: 18),
              SizedBox(width: 6),
              Text('Email verified', style: TextStyle(color: _C.success)),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _emailOtpCtrl,
                  hint: '6-digit email code',
                  forceError: _flagged.contains('emailVerify'),
                  errorText: 'Verify your email to continue.',
                  icon: Icons.pin_outlined,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: _linkStyle,
                onPressed: _sendingEmailOtp ? null : _sendEmailOtp,
                child: Text(_sendingEmailOtp ? 'Sending…' : 'Send code'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: _linkStyle,
              onPressed: _verifyingEmailOtp ? null : _verifyEmailOtp,
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: Text(_verifyingEmailOtp ? 'Checking…' : 'Verify email'),
            ),
          ),
        ],
        _gap,

        _row2(
          _col(
          'birthday',
          'Birthday',
            _Field(
              controller: _birthdayCtrl,
              hint: 'mm/dd/yyyy',
              readOnly: true,
              suffix: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: _C.muted,
              ),
              onTap: () async {
                final p = await _pickDate(
                  initial: DateTime(2000),
                  first: DateTime(1900),
                  last: DateTime.now(),
                );
                if (p != null) {
                  _birthdayCtrl.text = _fmtDate(p);
                  _ageCtrl.text = (DateTime.now().year - p.year).toString();
                  setState(() {});
                }
              },
            ),
            required: true,
          ),
          _col(
          'age',
          'Age',
            _Field(controller: _ageCtrl, hint: '--', readOnly: true),
            required: true,
          ),
        ),
        _gap,

        _col(
          'validId',
          'Valid ID',
          _UploadField(
            fileName: _validIdFileName,
            hint: 'Upload Valid ID here',
            onTap: () => _showImageSourceSheet((file) {
              setState(() {
                _validIdFileName = file.name;
                _validIdPath = file.path;
              });
            }),
          ),
          required: true,
        ),
        const SizedBox(height: 28),

        const _SectionHeader(
          title: 'Account Security',
          subtitle: 'Set a password to secure your account.',
        ),
        const SizedBox(height: 18),

        _col(
          'password',
          'Password',
          _Field(
            controller: _passwordCtrl,
            hint: 'Create a password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            forceError: _flagged.contains('password') && _passwordCtrl.text.isNotEmpty,
            errorText: 'Password must be at least 8 characters.',
            
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePass = !_obscurePass),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 22,
                color: _C.muted,
              ),
            ),
          ),
          required: true,
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            'Minimum 8 characters with letters and numbers',
            style: TextStyle(color: _C.muted, fontSize: 11.5),
          ),
        ),
        _gap,

        _col(
          'confirm',
          'Confirm Password',
          _Field(
            controller: _confirmPassCtrl,
            hint: 'Confirm your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            forceError: _flagged.contains('confirm') && _confirmPassCtrl.text.isNotEmpty,
            errorText: 'Passwords do not match.',
            
            suffix: GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              behavior: HitTestBehavior.opaque,
              child: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 22,
                color: _C.muted,
              ),
            ),
          ),
          required: true,
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // STEP 2 — Vehicle Details
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Vehicle Details',
          subtitle: 'Provide your vehicle and license information',
        ),
        const SizedBox(height: 18),

        _col(
          'vehicleType',
          'Type of Vehicle',
          _Dropdown(
            value: _vehicleType,
            hint: 'Select vehicle type',
            options: _vehicleOptions,
            onChanged: (v) => setState(() => _vehicleType = v),
          ),
          required: true,
        ),
        _gap,

        _col(
          'plate',
          'Plate Number',
          _Field(
            controller: _plateNumberCtrl,
            hint: 'e.g. ABC 1234',
            icon: Icons.pin_outlined,
          ),
          required: true,
        ),
        _gap,

        _col(
          'license',
          "Driver's License",
          _UploadField(
            fileName: _driversLicenseFile,
            hint: "Upload Driver's License",
            onTap: _showLicenseSourceSheet,
          ),
          required: true,
        ),
        // Scanning indicator
        if (_scanningLicense)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _C.raisinSoft,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: _C.raisin.withAlpha(60)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(_C.prune),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Scanning license, please wait…',
                  style: TextStyle(
                    color: _C.prune,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),

        // ── Driver's License Information ───────────────────────
        const _SectionHeader(
          title: "Driver's License Information",
          subtitle: 'Fill in the details as shown on your license',
        ),
        const SizedBox(height: 18),

        _row2(
          _col(
          'dlLast',
          'Last Name',
            _Field(controller: _dlLastNameCtrl, hint: 'Last name on license'),
            required: true,
          ),
          _col(
          'dlFirst',
          'First Name',
            _Field(controller: _dlFirstNameCtrl, hint: 'First name on license'),
            required: true,
          ),
        ),
        _gap,

        _col(
          'dlMiddle',
          'Middle Name',
          _Field(controller: _dlMiddleNameCtrl, hint: 'Middle name on license'),
        ),
        _gap,

        _col(
          'dlAddress',
          'Address',
          _Field(
            controller: _dlAddressCtrl,
            hint: 'Address as shown on license',
            icon: Icons.home_outlined,
          ),
          required: true,
        ),
        _gap,

        _row2(
          _col(
          'dlLicenseNo',
          'License No.',
            _Field(controller: _dlLicenseNoCtrl, hint: 'e.g. N01-23-456789'),
            required: true,
          ),
          _col(
          'dlExpiration',
          'Expiration Date',
            _futureDateField(_dlExpirationCtrl),
            required: true,
          ),
        ),
        _gap,

        _row2(
          _col(
          'dlNationality',
          'Nationality',
            _Field(controller: _dlNationalityCtrl, hint: 'e.g. Filipino'),
            required: true,
          ),
          _col(
          'bloodType',
          'Blood Type',
            _Dropdown(
              value: _dlBloodTypeCtrl.text.isEmpty ? null : _dlBloodTypeCtrl.text,
              hint: 'Select',
              options: const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
              onChanged: (v) => setState(() => _dlBloodTypeCtrl.text = v ?? ''),
            ),
          ),
        ),
        _gap,

        KeyedSubtree(
          key: _k('dlCode'),
          child: _label("Driver's License Code", required: true),
        ),
        const SizedBox(height: 4),
        const Text(
          'Vehicle classification you are authorized to drive',
          style: TextStyle(color: _C.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        _Dropdown(
          value: _dlRestrictionCode,
          forceError: _flagged.contains('dlCode'),
          hint: 'Select license code',
          options: const [
            'A — Motorcycle',
            'A1 — Tricycle',
            'B — Up to 4,500 KGS GVW / 8 seats',
          ],
          onChanged: (v) => setState(() => _dlRestrictionCode = v),
        ),
        const SizedBox(height: 28),

        KeyedSubtree(key: _k('orCr'), child: _label('OR / CR', required: true)),
        const SizedBox(height: 4),
        const Text(
          'Official Receipt / Certificate of Registration',
          style: TextStyle(color: _C.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        _UploadField(
          fileName: _orCrFile,
          forceError: _flagged.contains('orCr'),
          hint: 'Upload OR / CR',
          onTap: () => _showImageSourceSheet((file) {
            setState(() {
              _orCrFile = file.name;
              _orCrPath = file.path;
            });
          }),
        ),
        const SizedBox(height: 28),

        // ── OR / CR Information ────────────────────────────────
        const _SectionHeader(
          title: 'OR / CR Information',
          subtitle: 'Fill in the details as shown on your OR / CR',
        ),
        const SizedBox(height: 18),

        _row2(
          _col(
          'mvFile',
          'MV File No.',
            _Field(controller: _orCrMVFileNoCtrl, hint: 'e.g. 1234567890'),
            required: true,
          ),
          _col(
          'orPlate',
          'Plate No.',
            _Field(controller: _orCrPlateNoCtrl, hint: 'e.g. ABC 1234'),
            required: true,
          ),
        ),
        _gap,

        _row2(
          _col(
          'make',
          'Make',
            _Field(controller: _orCrMakeCtrl, hint: 'e.g. Honda, Yamaha'),
            required: true,
          ),
          _col(
          'series',
          'Series / Model',
            _Field(controller: _orCrSeriesCtrl, hint: 'e.g. Click 125i'),
          ),
        ),
        _gap,

        _row2(
          _col(
          'body',
          'Body Type',
            _Field(controller: _orCrBodyTypeCtrl, hint: 'e.g. Motorcycle'),
            required: true,
          ),
          _col(
          'color',
          'Color',
            _Field(controller: _orCrColorCtrl, hint: 'e.g. Black'),
          ),
        ),
        _gap,

        _row2(
          _col(
          'year',
          'Year Model',
            _Field(
              controller: _orCrYearModelCtrl,
              hint: 'e.g. 2022',
              keyboard: TextInputType.number,
            ),
            required: true,
          ),
          _col(
          'engine',
          'Engine No.',
            _Field(controller: _orCrEngineNoCtrl, hint: 'Engine number'),
            required: true,
          ),
        ),
        _gap,

        _col(
          'chassis',
          'Chassis No.',
          _Field(controller: _orCrChassisNoCtrl, hint: 'Chassis / VIN number'),
          required: true,
        ),
        _gap,

        _col(
          'owner',
          'Registered Owner',
          _Field(
            controller: _orCrOwnerCtrl,
            hint: 'Full name of registered owner',
            icon: Icons.person_outline_rounded,
          ),
          required: true,
        ),
        _gap,

        _col(
          'ownerAddress',
          "Owner's Address",
          _Field(
            controller: _orCrAddressCtrl,
            hint: 'Address of registered owner',
            icon: Icons.home_outlined,
          ),
          required: true,
        ),
        _gap,

        _col(
          'regExp',
          'Registration Expiration',
          _futureDateField(_orCrExpirationCtrl),
          required: true,
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // STEP 3 — Contact & Address
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    const hintStyle = TextStyle(color: _C.muted, fontSize: 15);
    const itemStyle = TextStyle(color: _C.ink, fontSize: 15);
    const arrow = Icon(Icons.keyboard_arrow_down_rounded, color: _C.muted);
    final barangayError = _flagged.contains('barangay');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Contact & Address',
          subtitle: 'Tell us about your contact and where you live.',
        ),
        const SizedBox(height: 18),

        _col(
          'phone',
          'Phone Number',
          _Field(
            controller: _phoneCtrl,
            hint: 'e.g. 09XX XXX XXXX',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
          ),
          required: true,
        ),
        _gap,

        KeyedSubtree(key: _k('province'), child: _label('Province', required: true)),
        const SizedBox(height: 8),
        if (_loadingLocations)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              color: _C.brique,
              backgroundColor: _C.raisinSoft,
            ),
          ),
        if (_locationsError != null)
          TextButton(
            style: _linkStyle,
            onPressed: _loadLocations,
            child: Text('$_locationsError Tap to retry.'),
          ),
        DropdownButtonFormField<String>(
          initialValue: _provinceCode,
          isExpanded: true,
          icon: arrow,
          borderRadius: BorderRadius.circular(_radius),
          dropdownColor: Colors.white,
          style: itemStyle,
          decoration: _decoration(error: _flagged.contains('province')),
          hint: const Text('Select province', style: hintStyle),
          items: _provinces.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(
                    (entry.value as Map)['name'].toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _provinces.isEmpty
              ? null
              : (code) => setState(() {
                  _provinceCode = code;
                  _cityCode = null;
                  _barangayCode = null;
                  _barangayCtrl.clear();
                  _barangays = {};
                  _barangaysError = null;
                  _provinceCtrl.text = code == null
                      ? ''
                      : (_provinces[code] as Map)['name'].toString();
                  _municipalityCtrl.clear();
                }),
        ),
        _gap,

        KeyedSubtree(key: _k('city'), child: _label('Municipality / City', required: true)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(_provinceCode),
          initialValue: _cityCode,
          isExpanded: true,
          icon: arrow,
          borderRadius: BorderRadius.circular(_radius),
          dropdownColor: Colors.white,
          style: itemStyle,
          decoration: _decoration(error: _flagged.contains('city')),
          hint: const Text('Select municipality or city', style: hintStyle),
          items: _provinceCode == null
              ? []
              : Map<String, dynamic>.from(
                      (_provinces[_provinceCode] as Map)['cities'] as Map,
                    ).entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value.toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
          onChanged: _provinceCode == null
              ? null
              : (code) {
                  setState(() {
                    _cityCode = code;
                    _barangayCode = null;
                    _barangayCtrl.clear();
                    _barangays = {};
                    _barangaysError = null;
                    _municipalityCtrl.text = code == null
                        ? ''
                        : (_provinces[_provinceCode] as Map)['cities'][code]
                              .toString();
                  });
                  if (code != null) _loadBarangays(code);
                },
        ),
        _gap,

        KeyedSubtree(key: _k('barangay'), child: _label('Barangay', required: true)),
        const SizedBox(height: 8),
        if (_loadingBarangays)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              color: _C.brique,
              backgroundColor: _C.raisinSoft,
            ),
          ),
        if (_barangaysError != null)
          TextButton(
            style: _linkStyle,
            onPressed: _cityCode == null
                ? null
                : () => _loadBarangays(_cityCode!),
            child: Text('$_barangaysError Tap to retry.'),
          ),
        LayoutBuilder(
          builder: (context, constraints) => DropdownMenu<String>(
            key: ValueKey('barangay-$_cityCode'),
            width: constraints.maxWidth,
            enabled: _barangays.isNotEmpty && !_loadingBarangays,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            hintText: 'Select barangay',
            textStyle: itemStyle,
            initialSelection: _barangayCode,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: barangayError ? _C.errorSoft : _C.background,
              hintStyle: hintStyle,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: _border(barangayError ? _C.error : _C.border, barangayError ? 1.6 : 1.2),
              enabledBorder: _border(barangayError ? _C.error : _C.border, barangayError ? 1.6 : 1.2),
              disabledBorder: _border(barangayError ? _C.error : _C.border, barangayError ? 1.6 : 1.2),
              focusedBorder: _border(barangayError ? _C.error : _C.prune, 1.6),
            ),
            menuStyle: const MenuStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.white),
            ),
            menuHeight: 280,
            dropdownMenuEntries: _barangays.entries
                .map(
                  (entry) => DropdownMenuEntry<String>(
                    value: entry.key,
                    label: entry.value.toString(),
                  ),
                )
                .toList(),
            onSelected: (code) => setState(() {
              _barangayCode = code;
              _barangayCtrl.text = code == null
                  ? ''
                  : _barangays[code].toString();
            }),
          ),
        ),
        _gap,

        _col(
          'street',
          'Street / House No.',
          _Field(
            controller: _streetCtrl,
            hint: 'Enter street or house number',
            icon: Icons.home_outlined,
          ),
          required: true,
        ),
        _gap,

        _col(
          'zip',
          'Zip Code',
          _Field(
            controller: _zipCodeCtrl,
            hint: 'Enter zip code',
            icon: Icons.markunread_mailbox_outlined,
            keyboard: TextInputType.number,
          ),
          required: true,
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // STEP 4 — Review & Submit
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep4() {
    final mi = _middleInitialCtrl.text.trim();
    final fullName =
        '${_firstNameCtrl.text.trim()} ${mi.isNotEmpty ? '$mi. ' : ''}${_lastNameCtrl.text.trim()}'
            .trim();
    String v(String s) => s.trim().isEmpty ? '—' : s.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Review your Information',
          subtitle:
              'Please review all the details below before submitting your registration',
        ),
        const SizedBox(height: 18),

        _ReviewCard(
          title: 'Rider Information',
          onEdit: () {
            setState(() {
              _currentStep = 0;
              _flagged = {};
            });
            _scrollToTop();
          },
          rows: [
            _ReviewRow4(
              item1: _RC(
                label: 'Full Name',
                value: fullName.isEmpty ? '—' : fullName,
              ),
              item2: _RC(label: 'Phone Number', value: v(_phoneCtrl.text)),
              item3: _RC(label: 'Province', value: v(_provinceCtrl.text)),
              item4: _RC(label: 'Street/House No.', value: v(_streetCtrl.text)),
            ),
            _ReviewRow4(
              item1: _RC(label: 'Sex', value: _selectedSex ?? '—'),
              item2: _RC(label: 'Birthday', value: v(_birthdayCtrl.text)),
              item3: _RC(
                label: 'Municipality',
                value: v(_municipalityCtrl.text),
              ),
              item4: _RC(label: 'Zip Code', value: v(_zipCodeCtrl.text)),
            ),
            _ReviewRow4(
              item1: _RC(label: 'Email', value: v(_emailCtrl.text)),
              item2: _RC(label: 'Age', value: v(_ageCtrl.text)),
              item3: _RC(label: 'Barangay', value: v(_barangayCtrl.text)),
              item4: _RC(
                label: 'Valid ID',
                value: _validIdFileName ?? '—',
                isFile: _validIdFileName != null,
              ),
            ),
            _ReviewRow4(
              item1: _RC(label: 'Vehicle Type', value: _vehicleType ?? '—'),
              item2: _RC(
                label: 'Plate Number',
                value: v(_plateNumberCtrl.text),
              ),
              item3: _RC(
                label: "Driver's License",
                value: _driversLicenseFile ?? '—',
                isFile: _driversLicenseFile != null,
              ),
              item4: _RC(
                label: 'OR / CR',
                value: _orCrFile ?? '—',
                isFile: _orCrFile != null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.raisinSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.raisin.withAlpha(60), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: _C.prune,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: _C.lin,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Please Review Carefully',
                    style: TextStyle(
                      color: _C.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'By submitting this registration, you confirm that all information provided is true and correct. '
                'The matched logistics hub will review your application. You can sign in after approval.',
                style: TextStyle(color: _C.muted, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setState(() {
                  _agreedToTerms = !_agreedToTerms;
                  if (_agreedToTerms) _termsError = false;
                }),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _agreedToTerms ? _C.prune : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreedToTerms
                              ? _C.prune
                              : (_termsError ? _C.error : _C.muted),
                          width: 1.4,
                        ),
                      ),
                      child: _agreedToTerms
                          ? const Icon(Icons.check, color: _C.lin, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(color: _C.muted, fontSize: 12.5),
                          children: [
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(
                                color: _C.raisin,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: _C.raisin,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _C.ink,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: _C.brique),
                ),
              ]
            : [],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Camera / gallery sheets
  // ────────────────────────────────────────────────────────────────
  void _showLicenseSourceSheet() {
    _showSourceSheet(
      title: "Scan Driver's License",
      subtitle: 'Take or upload a photo — fields will be auto-filled',
      cameraIcon: Icons.document_scanner_outlined,
      cameraTitle: 'Scan with Camera',
      cameraSubtitle: 'Point camera at your license to auto-fill',
      gallerySubtitle: 'Select a photo of your license from gallery',
      quality: 90,
      onPicked: (file) => _runLicenseOcr(file.path, file.name),
    );
  }

  void _showImageSourceSheet(void Function(XFile) onPicked) {
    _showSourceSheet(
      title: 'Upload Document',
      subtitle: 'Choose how you want to upload',
      cameraIcon: Icons.camera_alt_outlined,
      cameraTitle: 'Take a Photo',
      cameraSubtitle: 'Use your camera to capture the document',
      gallerySubtitle: 'Select an existing photo from your device',
      quality: 85,
      onPicked: (file) async => onPicked(file),
    );
  }

  void _showSourceSheet({
    required String title,
    required String subtitle,
    required IconData cameraIcon,
    required String cameraTitle,
    required String cameraSubtitle,
    required String gallerySubtitle,
    required int quality,
    required Future<void> Function(XFile) onPicked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> pick(ImageSource source) async {
          Navigator.pop(sheetContext);
          final file = await ImagePicker().pickImage(
            source: source,
            imageQuality: quality,
          );
          if (file != null) await onPicked(file);
        }

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            14,
            24,
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
                    color: _C.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _C.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _SourceTile(
                icon: cameraIcon,
                title: cameraTitle,
                subtitle: cameraSubtitle,
                onTap: () => pick(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from Gallery',
                subtitle: gallerySubtitle,
                onTap: () => pick(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runLicenseOcr(String path, String fileName) async {
    setState(() {
      _driversLicenseFile = fileName;
      _driversLicensePath = path;
      _scanningLicense = true;
    });

    try {
      final result = await LicenseOcrService.scan(path);

      setState(() {
        if (result.lastName != null && result.lastName!.isNotEmpty) {
          _dlLastNameCtrl.text = result.lastName!;
        }
        if (result.firstName != null && result.firstName!.isNotEmpty) {
          _dlFirstNameCtrl.text = result.firstName!;
        }
        if (result.middleName != null && result.middleName!.isNotEmpty) {
          _dlMiddleNameCtrl.text = result.middleName!;
        }
        if (result.address != null && result.address!.isNotEmpty) {
          _dlAddressCtrl.text = result.address!;
        }
        if (result.licenseNo != null && result.licenseNo!.isNotEmpty) {
          _dlLicenseNoCtrl.text = result.licenseNo!;
        }
        if (result.expiration != null && result.expiration!.isNotEmpty) {
          _dlExpirationCtrl.text = result.expiration!;
        }
        if (result.nationality != null && result.nationality!.isNotEmpty) {
          _dlNationalityCtrl.text = result.nationality!;
        }
        if (result.bloodType != null && result.bloodType!.isNotEmpty) {
          _dlBloodTypeCtrl.text = result.bloodType!;
        }
      });

      // Show snackbar feedback
      if (mounted) {
        final filled = [
          result.lastName,
          result.firstName,
          result.licenseNo,
          result.expiration,
          result.address,
        ].where((v) => v != null && v.isNotEmpty).length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              filled > 0
                  ? 'Scanned successfully — $filled field${filled == 1 ? '' : 's'} auto-filled'
                  : 'Could not read license text clearly. Please fill in manually.',
            ),
            backgroundColor: filled > 0 ? _C.prune : _C.brique,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Scan failed. Please fill in the fields manually.',
            ),
            backgroundColor: _C.brique,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _scanningLicense = false);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step bar: dark gradient card for the active step + segmented progress
// ─────────────────────────────────────────────────────────────────────────────
class _MobileStepBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final List<IconData> icons;

  const _MobileStepBar({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
    required this.icons,
  });

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
              colors: [_C.pruneLight, _C.prune],
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
                child: Icon(icons[currentStep], color: _C.lin, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: const TextStyle(
                        color: _C.lin,
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

        // Segmented progress bar
        Row(
          children: List.generate(totalSteps, (i) {
            final isDone = i < currentStep;
            final isActive = i == currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _C.prune
                            : isActive
                            ? _C.brique
                            : _C.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        color: (isDone || isActive) ? _C.prune : _C.muted,
                        fontWeight: (isDone || isActive)
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

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _C.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: _C.muted, fontSize: 13)),
        const SizedBox(height: 10),
        const Divider(color: _C.border, thickness: 1, height: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input field (same look as the login fields)
// ─────────────────────────────────────────────────────────────────────────────
// Tells the fields below it which id they have and which ids are flagged
// (wrong when the user tapped Next).
class _FieldScope extends InheritedWidget {
  final String id;
  final Set<String> flagged;

  const _FieldScope({
    required this.id,
    required this.flagged,
    required super.child,
  });

  static _FieldScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FieldScope>();

  // The set is changed in place, so always tell the fields to check again
  @override
  bool updateShouldNotify(_FieldScope old) => true;
}

// True when this field was flagged by the last tap on Next and is not fixed yet
bool _scopeError(BuildContext context) {
  final s = _FieldScope.of(context);
  return s != null && s.flagged.contains(s.id);
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure, readOnly;
  final TextInputType? keyboard;
  final Widget? suffix;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  /// Red border even if the field is not empty (for example: password too
  /// short). `errorText` is shown in red under the field.
  final bool forceError;
  final String? errorText;

  const _Field({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.readOnly = false,
    this.keyboard,
    this.suffix,
    this.onTap,
    this.onChanged,
    this.forceError = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    // Listens to the text, so the red border goes away as soon as the user types
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasError = forceError || _scopeError(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              obscureText: obscure,
              readOnly: readOnly,
              keyboardType: keyboard,
              onTap: onTap,
              onChanged: onChanged,
              cursorColor: _C.prune,
              style: const TextStyle(color: _C.ink, fontSize: 15),
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
                  style: const TextStyle(color: _C.error, fontSize: 11.5),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _Dropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool forceError;

  const _Dropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.forceError = false,
  });

  @override
  Widget build(BuildContext context) {
    final error = forceError || _scopeError(context);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: error ? _C.errorSoft : _C.background,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: error ? _C.error : _C.border,
          width: error ? 1.6 : 1.2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: _C.muted, fontSize: 15),
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(_radius),
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: error ? _C.error : _C.muted,
          ),
          items: options
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s,
                    style: const TextStyle(color: _C.ink, fontSize: 15),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload field
// ─────────────────────────────────────────────────────────────────────────────

class _UploadField extends StatelessWidget {
  final String? fileName;
  final String hint;
  final VoidCallback onTap;
  final bool forceError;

  const _UploadField({
    required this.fileName,
    required this.hint,
    required this.onTap,
    this.forceError = false,
  });

  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;
    final error = forceError || _scopeError(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: error
              ? _C.errorSoft
              : picked
              ? _C.raisinSoft
              : _C.background,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: error
                ? _C.error
                : picked
                ? _C.raisin.withAlpha(90)
                : _C.border,
            width: error ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              picked ? Icons.insert_drive_file_outlined : Icons.attach_file,
              color: error ? _C.error : _C.raisin,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: picked ? _C.ink : (error ? _C.error : _C.muted),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              picked ? Icons.check_circle_rounded : Icons.upload_outlined,
              color: picked
                  ? _C.success
                  : error
                  ? _C.error
                  : _C.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source tile (camera / gallery)
// ─────────────────────────────────────────────────────────────────────────────
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: _C.raisinSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _C.prune, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _C.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _C.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review card + rows
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final List<Widget> rows;

  const _ReviewCard({
    required this.title,
    required this.onEdit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _C.raisinSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _C.raisin,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _C.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: _C.prune, width: 1.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: _C.prune,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: _C.border, height: 1),
          const SizedBox(height: 14),
          ...rows.map(
            (r) =>
                Padding(padding: const EdgeInsets.only(bottom: 14), child: r),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow4 extends StatelessWidget {
  final _RC item1, item2, item3, item4;

  const _ReviewRow4({
    required this.item1,
    required this.item2,
    required this.item3,
    required this.item4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _cell(item1)),
        const SizedBox(width: 8),
        Expanded(child: _cell(item2)),
        const SizedBox(width: 8),
        Expanded(child: _cell(item3)),
        const SizedBox(width: 8),
        Expanded(child: _cell(item4)),
      ],
    );
  }

  Widget _cell(_RC item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: const TextStyle(color: _C.muted, fontSize: 10.5),
        ),
        const SizedBox(height: 3),
        item.isFile
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.raisinSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.raisin.withAlpha(60), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 12,
                      color: _C.raisin,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        item.value,
                        style: const TextStyle(
                          color: _C.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                item.value,
                style: const TextStyle(
                  color: _C.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ],
    );
  }
}

class _RC {
  final String label, value;
  final bool isFile;
  const _RC({required this.label, required this.value, this.isFile = false});
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar: Back + Next / Submit (same buttons as the login screen)
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNextBar extends StatelessWidget {
  final int currentStep, totalSteps;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool submitting;

  const _BottomNextBar({
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    this.onBack,
    this.submitting = false,
  });

  static const _nextLabels = [
    'Next: Vehicle Details',
    'Next: Contact & Address',
    'Next: Review & Submit',
    'Submit',
  ];

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
        border: Border(top: BorderSide(color: _C.border, width: 1)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            SizedBox(
              height: 54,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _C.prune, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: _C.prune,
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
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.prune,
                  disabledBackgroundColor: _C.prune,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_radius),
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
                              color: _C.lin,
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
                            _nextLabels[currentStep],
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

// ─────────────────────────────────────────────────────────────────────────────
// Success modal
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessModal extends StatelessWidget {
  final VoidCallback onBackToLogin;
  final String? centerName;

  const _SuccessModal({required this.onBackToLogin, this.centerName});

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
              color: _C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // The rider on a purple card, with a green check badge
          SizedBox(
            width: 210,
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_C.pruneLight, _C.prune],
                        ),
                      ),
                      child: const CustomPaint(painter: _DecorPainter()),
                    ),
                  ),
                ),
                const Center(
                  child: SizedBox(
                    width: 140,
                    height: 105,
                    child: _RiderPicture(),
                  ),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Thank you for Registering',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your registration is pending review',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.raisin,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your application was sent to ${centerName ?? 'your logistics hub'}. Sign in after that hub approves it.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onBackToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.prune,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: const Text(
                'Back to Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Still decoration for purple areas: soft circles and stars (no movement)
// ─────────────────────────────────────────────────────────────────────────────
class _DecorPainter extends CustomPainter {
  const _DecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawCircle(
      Offset(w * 0.88, h * 0.14),
      90,
      Paint()..color = Colors.white.withAlpha(16),
    );
    canvas.drawCircle(
      Offset(w * 0.06, h * 0.78),
      80,
      Paint()..color = _C.raisin.withAlpha(46),
    );

    final star = Paint();
    for (int i = 0; i < 26; i++) {
      final x = _hash(i * 3 + 1) * w;
      final y = _hash(i * 3 + 2) * h * 0.92;
      final r = 0.7 + _hash(i * 3 + 3) * 1.2;
      star.color = Colors.white.withAlpha((25 + 105 * _hash(i * 3 + 4)).round());
      canvas.drawCircle(Offset(x, y), r, star);
    }
  }

  @override
  bool shouldRepaint(covariant _DecorPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// The rider: the same drawing used on the splash and login screens
//
// Drawn in the pose the splash rider has when it stops (engine idling, wheels
// at rest, brake light off). If you ever change the rider in the splash
// screen, change it here too.
// ─────────────────────────────────────────────────────────────────────────────
class _RiderPicture extends StatelessWidget {
  const _RiderPicture();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RiderPainter(
        wheelAngle: 2600 / 20, // wheel position when the splash rider stops
        speed: 0,
        brake: 0,
        phase: 1,
      ),
    );
  }
}

// Person on a motorcycle with a delivery box, drawn in a 160 x 120 box and
// scaled to fit. Faces right.
class _RiderPainter extends CustomPainter {
  final double wheelAngle, speed, brake, phase;

  _RiderPainter({
    required this.wheelAngle,
    required this.speed,
    required this.brake,
    required this.phase,
  });

  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _fill(Color c) => Paint()..color = c;

  void _wheel(Canvas canvas, Offset c) {
    final blur = (speed * 2.2).clamp(0.0, 1.0); // 1 = blurry, 0 = clear

    if (blur > 0.02) {
      canvas.drawCircle(
        c,
        15,
        _fill(Colors.white.withAlpha((blur * 50).round())),
      );
    }
    // tire + rim
    canvas.drawCircle(c, 17.5, _stroke(const Color(0xFFEFE6F2), 5.5));
    canvas.drawCircle(c, 11.5, _stroke(_C.lin.withAlpha(150), 1.5));

    // spokes + a marker dot, only visible when the wheel is slower
    final clear = ((1 - blur) * 255).round();
    if (clear > 4) {
      final spoke = _stroke(_C.lin.withAlpha(clear), 2);
      for (int i = 0; i < 3; i++) {
        final a = wheelAngle + i * math.pi / 3;
        final d = Offset(math.cos(a), math.sin(a)) * 11.5;
        canvas.drawLine(c - d, c + d, spoke);
      }
      final m = c + Offset(math.cos(wheelAngle), math.sin(wheelAngle)) * 11.5;
      canvas.drawCircle(m, 1.8, _fill(_C.brique.withAlpha(clear)));
    }
    canvas.drawCircle(c, 3.5, _fill(_C.lin));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 120);

    const rear = Offset(40, 76);
    const front = Offset(122, 76);
    const jacket = Color(0xFFEADFF0);
    const jacketShade = Color(0xFFCDB9D6);
    const pants = Color(0xFF2B1530);
    const dark = Color(0xFF1F0F21);
    const red = Color(0xFFFF3B30);

    // Headlight glow
    canvas.drawCircle(
      const Offset(123, 50),
      12,
      Paint()
        ..color = _C.lin.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Wheels and fenders
    _wheel(canvas, rear);
    _wheel(canvas, front);
    canvas.drawArc(
      Rect.fromCircle(center: rear, radius: 23),
      math.pi * 1.1,
      math.pi * 0.75,
      false,
      _stroke(_C.lin, 3),
    );
    canvas.drawArc(
      Rect.fromCircle(center: front, radius: 23),
      math.pi * 1.2,
      math.pi * 0.7,
      false,
      _stroke(_C.lin, 3),
    );

    // Delivery box on a rack
    canvas.drawLine(
      const Offset(14, 61),
      const Offset(52, 61),
      _stroke(_C.lin, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 31, 40, 29),
        const Radius.circular(5),
      ),
      _fill(_C.brique),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 31, 40, 8),
        const Radius.circular(4),
      ),
      _fill(Colors.black.withAlpha(45)),
    );
    // "V" logo on the box
    canvas.drawPath(
      Path()
        ..moveTo(25, 43)
        ..lineTo(32, 55)
        ..lineTo(39, 43),
      _stroke(Colors.white, 3.2),
    );

    // Tail light (glows when braking)
    if (brake > 0.02) {
      canvas.drawCircle(
        const Offset(10, 50),
        10,
        Paint()
          ..color = red.withAlpha((160 * brake).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(
      const Offset(12, 50),
      2.6,
      _fill(Color.lerp(const Color(0xFF7A2A22), red, brake)!),
    );

    // Bike body
    final bike = _stroke(_C.lin, 5);
    canvas.drawLine(rear, const Offset(68, 69), bike); // swingarm
    canvas.drawLine(const Offset(110, 41), front, bike); // fork
    canvas.drawLine(
      const Offset(113, 52),
      const Offset(120, 70),
      _stroke(Colors.white.withAlpha(150), 1.8),
    ); // fork shine
    canvas.drawLine(
      const Offset(64, 78),
      const Offset(34, 82),
      _stroke(_C.raisin, 4.5),
    ); // exhaust
    canvas.drawCircle(const Offset(33, 82), 2.8, _fill(_C.raisin));

    // engine
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(62, 62, 28, 18),
        const Radius.circular(5),
      ),
      _fill(_C.lin),
    );
    canvas.drawRect(
      const Rect.fromLTWH(70, 66, 12, 8),
      _fill(_C.prune.withAlpha(120)),
    );
    // seat
    canvas.drawPath(
      Path()
        ..moveTo(44, 57)
        ..lineTo(78, 55)
        ..lineTo(80, 61)
        ..lineTo(46, 63)
        ..close(),
      _fill(dark),
    );
    // fuel tank
    canvas.drawPath(
      Path()
        ..moveTo(72, 56)
        ..quadraticBezierTo(88, 38, 108, 50)
        ..lineTo(106, 60)
        ..lineTo(76, 62)
        ..close(),
      _fill(_C.lin),
    );
    // handlebar + headlight
    canvas.drawLine(
      const Offset(106, 41),
      const Offset(115, 38),
      _stroke(Colors.white, 3.5),
    );
    canvas.drawCircle(const Offset(122, 50), 6, _fill(Colors.white));
    canvas.drawCircle(const Offset(122, 50), 3.5, _fill(_C.lin));

    // ── Rider ──────────────────────────────────────────────────────────
    // leg (outlined so it stands out from the dark background)
    final leg = Path()
      ..moveTo(68, 52)
      ..lineTo(92, 59)
      ..lineTo(83, 79);
    canvas.drawPath(leg, _stroke(_C.raisin.withAlpha(200), 12));
    canvas.drawPath(leg, _stroke(pants, 9));
    canvas.drawLine(
      const Offset(83, 80),
      const Offset(95, 82),
      _stroke(Colors.white, 5.5),
    );

    // torso, leaning forward
    canvas.drawLine(
      const Offset(66, 53),
      const Offset(84, 29),
      _stroke(_C.raisin.withAlpha(180), 19),
    );
    canvas.drawLine(
      const Offset(66, 53),
      const Offset(84, 29),
      _stroke(jacket, 17),
    );
    canvas.drawLine(
      const Offset(68, 36),
      const Offset(82, 46),
      _stroke(_C.lin, 3),
    ); // jacket stripe

    // arm to the handlebar + glove
    final arm = Path()
      ..moveTo(82, 32)
      ..lineTo(95, 45)
      ..lineTo(110, 41);
    canvas.drawPath(arm, _stroke(jacketShade, 6.5));
    canvas.drawCircle(const Offset(111, 41), 3.6, _fill(_C.prune));

    // scarf: streams back when fast, droops when stopped
    final scarf = Path()..moveTo(80, 28);
    final len = 0.35 + speed * 0.65;
    for (int k = 1; k <= 6; k++) {
      final x = 80 - k * 5.5 * len;
      final y =
          28 +
          k * 1.4 * (1 - speed) +
          math.sin(phase * math.pi * 14 + k * 0.9) * (0.8 + k * 0.55) * speed;
      scarf.lineTo(x, y);
    }
    canvas.drawPath(scarf, _stroke(_C.lin, 4.5));

    // helmet with visor
    const head = Offset(90, 16);
    canvas.drawCircle(head, 10.5, _fill(_C.brique));
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: 7),
      math.pi * 1.15,
      math.pi * 0.6,
      false,
      _stroke(_C.lin, 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(93, 11.5, 11, 7),
        const Radius.circular(3.5),
      ),
      _fill(dark),
    );
    canvas.drawLine(
      const Offset(96, 13.5),
      const Offset(101, 13.5),
      _stroke(Colors.white.withAlpha(180), 1.3),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RiderPainter old) =>
      old.wheelAngle != wheelAngle ||
      old.speed != speed ||
      old.brake != brake ||
      old.phase != phase;
}