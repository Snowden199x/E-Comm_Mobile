import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_buyer/core/api/api_models.dart';
import 'package:vendo_buyer/core/api/buyer_api.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Same Vendo palette as the rider app and the buyer login screen
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
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  final _scroll = ScrollController();

  // Step 1 controllers
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleInitialCtrl = TextEditingController();
  String? _selectedSex;
  final _emailCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ID fields
  String _idCategory = 'primary'; // 'primary' or 'secondary'
  String? _primaryIdType;
  String? _validIdFileName; // primary ID file
  String? _secondaryId1Type;
  String? _secondaryId1FileName;
  String? _secondaryId2Type;
  String? _secondaryId2FileName;

  static const List<String> _primaryIdTypes = [
    'Philippine Passport',
    'PhilSys National ID',
    "Driver's License",
    'UMID',
    'SSS ID',
    'GSIS ID',
    'PRC ID',
    'Postal ID',
  ];

  static const List<String> _secondaryIdTypes = [
    'PhilHealth ID',
    'TIN ID',
    "Voter's ID/Certification",
    'NBI Clearance',
    'Barangay Certification',
    'Company ID',
    'School ID',
    'Senior Citizen/PWD ID',
  ];

  // Step 2 controllers
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _zipCodeCtrl = TextEditingController();

  // Step 2 address picks, loaded from the PSGC location API
  List<ApiProvince> _provinces = const [];
  List<ApiCity> _municipalities = const [];
  List<ApiBarangay> _barangays = const [];
  ApiProvince? _province;
  ApiCity? _municipality;
  ApiBarangay? _barangay;
  bool _loadingProvinces = false;
  bool _loadingBarangays = false;

  // Step 3
  bool _agreedToTerms = false;

  // API state
  String? _verificationToken; // set after OTP verify
  String? _validIdPath; // actual file path for primary ID
  String? _secondaryId1Path;
  String? _secondaryId2Path;
  bool _submitting = false;

  // Validation — keys match field names; red border shown when key is present
  final Set<String> _errors = {};

  final List<String> _sexOptions = ['Male', 'Female', 'Prefer not to say'];

  static const _stepLabels = [
    'Personal Info',
    'Contact & Address',
    'Review & Submit',
  ];

  static const _stepIcons = [
    Icons.person_outline_rounded,
    Icons.location_on_outlined,
    Icons.fact_check_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    setState(() => _loadingProvinces = true);
    try {
      final provinces = await BuyerApi.instance.locations();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _loadingProvinces = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProvinces = false);
      _showSnack('Could not load the province list. Check your connection.');
    }
  }

  Future<void> _loadBarangays(ApiCity city) async {
    setState(() {
      _loadingBarangays = true;
      _barangays = const [];
      _barangay = null;
    });
    try {
      final barangays = await BuyerApi.instance.barangays(city.code);
      if (!mounted) return;
      setState(() {
        _barangays = barangays;
        _loadingBarangays = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBarangays = false);
      _showSnack('Could not load the barangay list. Check your connection.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleInitialCtrl.dispose();
    _emailCtrl.dispose();
    _birthdayCtrl.dispose();
    _ageCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _zipCodeCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _nextStep() {
    final newErrors = <String>{};

    if (_currentStep == 0) {
      if (_lastNameCtrl.text.trim().isEmpty) newErrors.add('lastName');
      if (_firstNameCtrl.text.trim().isEmpty) newErrors.add('firstName');
      if (_selectedSex == null) newErrors.add('sex');
      if (_emailCtrl.text.trim().isEmpty) newErrors.add('email');
      if (_birthdayCtrl.text.trim().isEmpty) newErrors.add('birthday');
      if (_passwordCtrl.text.isEmpty) newErrors.add('password');
      if (_confirmPasswordCtrl.text.isEmpty) newErrors.add('confirmPassword');
      if (_idCategory == 'primary') {
        if (_primaryIdType == null) newErrors.add('primaryIdType');
        if (_validIdFileName == null) newErrors.add('validId');
      } else {
        if (_secondaryId1Type == null) newErrors.add('secondaryId1Type');
        if (_secondaryId1FileName == null) newErrors.add('secondaryId1');
        if (_secondaryId2Type == null) newErrors.add('secondaryId2Type');
        if (_secondaryId2FileName == null) newErrors.add('secondaryId2');
      }
    } else if (_currentStep == 1) {
      if (!RegExp(r'^09\d{9}$').hasMatch(_phoneCtrl.text.trim())) {
        newErrors.add('phone');
      }
      if (_province == null) newErrors.add('province');
      if (_municipality == null) newErrors.add('municipality');
      if (_barangay == null) newErrors.add('barangay');
      if (_streetCtrl.text.trim().isEmpty) newErrors.add('street');
      if (_zipCodeCtrl.text.trim().isEmpty) newErrors.add('zipCode');
    }

    if (newErrors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(newErrors),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the fields marked in red.'),
        ),
      );
      return;
    }

    setState(() => _errors.clear());

    if (_currentStep < 2) {
      // Step 0→1: require email verified before advancing
      if (_currentStep == 0 && _verificationToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify your email before continuing.'),
          ),
        );
        return;
      }
      setState(() => _currentStep++);
      _scrollToTop();
    } else {
      _submitRegistration();
    }
  }

  Future<void> _submitRegistration() async {
    if (_submitting) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms and Conditions.'),
        ),
      );
      return;
    }
    if (_verificationToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email verification expired. Please go back and verify again.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final idPath = _idCategory == 'primary'
          ? _validIdPath
          : _secondaryId1Path;
      if (idPath == null) throw const BuyerApiException('ID file is missing.');

      // Map sex value to what the server expects
      final sexMap = {
        'Male': 'male',
        'Female': 'female',
        'Prefer not to say': 'prefer_not_to_say',
      };

      await BuyerApi.instance.register(
        fields: {
          'last_name': _lastNameCtrl.text.trim(),
          'first_name': _firstNameCtrl.text.trim(),
          'middle_initial': _middleInitialCtrl.text.trim(),
          'sex': sexMap[_selectedSex] ?? 'prefer_not_to_say',
          'email': _emailCtrl.text.trim(),
          'birthday': _birthdayCtrl.text.trim(),
          'id_category': _idCategory,
          if (_idCategory == 'primary') 'id_type': _primaryIdType ?? '',
          if (_idCategory == 'secondary') 'id_type_1': _secondaryId1Type ?? '',
          if (_idCategory == 'secondary') 'id_type_2': _secondaryId2Type ?? '',
          'password': _passwordCtrl.text,
          'password_confirmation': _confirmPasswordCtrl.text,
          'province': _province?.name ?? '',
          'municipality': _municipality?.name ?? '',
          'barangay': _barangay?.name ?? '',
          'street': _streetCtrl.text.trim(),
          'zip_code': _zipCodeCtrl.text.trim(),
          'contact_number': _phoneCtrl.text.trim(),
          'agree_terms': '1',
          'verification_token': _verificationToken!,
        },
        validIdPath: idPath,
        validId2Path: _idCategory == 'secondary' ? _secondaryId2Path : null,
      );
      if (!mounted) return;
      _showSuccessModal(context);
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
            content: Text(
              'Cannot reach Vendo. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goBack() {
    setState(() {
      _currentStep--;
      _errors.clear();
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessModal(
        onBackToLogin: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Page layout: purple header with the logo + rounded white card
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
                          totalSteps: _stepLabels.length,
                          labels: _stepLabels,
                          icons: _stepIcons,
                        ),
                        const SizedBox(height: 28),
                        if (_currentStep == 0) _buildStep1(),
                        if (_currentStep == 1) _buildStep2(),
                        if (_currentStep == 2) _buildStep3(),
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
          onNext: _nextStep,
          onBack: _currentStep > 0 ? _goBack : null,
          submitting: _submitting,
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
                // The logo hides while the keyboard is open to save space
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: keyboardOpen
                      ? const SizedBox(width: double.infinity)
                      : const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: SizedBox(
                            width: 112,
                            height: 84,
                            child: Center(
                              child: _VendoBagLogo(width: 62, height: 70),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Buyer Registration',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create your buyer account',
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
  // Small helpers
  // ────────────────────────────────────────────────────────────────
  static const SizedBox _gap = SizedBox(height: 18);

  /// Read-only picker used for the PSGC address fields; the options come from the buyer API.
  Widget _locationDropdown({
    required String hint,
    required IconData icon,
    required bool hasError,
    required bool loading,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$hint-$value-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: _decoration(
        hint: loading ? 'Loading…' : hint,
        icon: icon,
        error: hasError,
      ),
      style: TextStyle(color: _C.raisin, fontSize: 15),
      items: items,
      onChanged: loading ? null : onChanged,
    );
  }

  Widget _col(String label, Widget child, {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, required: required),
        const SizedBox(height: 8),
        child,
      ],
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

  Widget _hintText(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, top: 6),
    child: Text(text, style: const TextStyle(color: _C.muted, fontSize: 11.5)),
  );

  Widget _eye(bool obscure, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 22,
        color: _C.muted,
      ),
    );
  }

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
          'Last Name',
          _Field(
            controller: _lastNameCtrl,
            hasError: _errors.contains('lastName'),
            hint: 'Enter last name',
            icon: Icons.person_outline_rounded,
          ),
          required: true,
        ),
        _gap,
        _col(
          'First Name',
          _Field(
            controller: _firstNameCtrl,
            hasError: _errors.contains('firstName'),
            hint: 'Enter first name',
            icon: Icons.person_outline_rounded,
          ),
          required: true,
        ),
        _gap,
        _col(
          'Middle Initial',
          _Field(
            controller: _middleInitialCtrl,
            hint: 'Enter middle initial',
            icon: Icons.person_outline_rounded,
          ),
        ),
        _gap,
        _col(
          'Sex',
          _Dropdown(
            value: _selectedSex,
            hint: 'Select Sex',
            options: _sexOptions,
            hasError: _errors.contains('sex'),
            onChanged: (val) => setState(() => _selectedSex = val),
          ),
          required: true,
        ),
        _gap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLabel('Email', required: true),
            const Spacer(),
            GestureDetector(
              onTap: () => _showVerifyEmailModal(context),
              behavior: HitTestBehavior.opaque,
              child: const Text(
                'Verify',
                style: TextStyle(
                  color: _C.raisin,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Field(
          controller: _emailCtrl,
          hasError: _errors.contains('email'),
          hint: 'Enter email address',
          icon: Icons.mail_outline_rounded,
          keyboard: TextInputType.emailAddress,
        ),
        _gap,
        _row2(
          _col(
            'Birthday',
            _Field(
              controller: _birthdayCtrl,
              hasError: _errors.contains('birthday'),
              hint: 'mm/dd/yyyy',
              readOnly: true,
              suffix: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: _C.muted,
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(primary: _C.prune),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  _birthdayCtrl.text =
                      '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
                  _ageCtrl.text = (DateTime.now().year - picked.year)
                      .toString();
                  setState(() {});
                }
              },
            ),
            required: true,
          ),
          _col(
            'Age',
            _Field(
              controller: _ageCtrl,
              hint: '--',
              keyboard: TextInputType.number,
              readOnly: true,
            ),
            required: true,
          ),
        ),
        _gap,

        // ── ID Category ─────────────────────────────────────────
        _buildLabel('ID Category', required: true),
        const SizedBox(height: 8),
        _IdCategoryToggle(
          value: _idCategory,
          onChanged: (val) => setState(() {
            _idCategory = val;
            // clear the other category's data
            _primaryIdType = null;
            _validIdFileName = null;
            _secondaryId1Type = null;
            _secondaryId1FileName = null;
            _secondaryId2Type = null;
            _secondaryId2FileName = null;
          }),
        ),
        _hintText(
          'Primary: 1 government-issued ID · Secondary: 2 IDs required',
        ),
        const SizedBox(height: 14),

        // ── Primary ID ───────────────────────────────────────────
        if (_idCategory == 'primary') ...[
          _col(
            'ID Type',
            _Dropdown(
              value: _primaryIdType,
              options: _primaryIdTypes,
              hint: 'Select ID Type',
              hasError: _errors.contains('primaryIdType'),
              onChanged: (val) => setState(() => _primaryIdType = val),
            ),
            required: true,
          ),
          _gap,
          _col(
            'Upload ID',
            _UploadField(
              fileName: _validIdFileName,
              hint: 'Upload ID here',
              hasError: _errors.contains('validId'),
              onTap: () => _showImageSourceSheet(context, slot: 'primary'),
            ),
            required: true,
          ),
          _hintText('Accepted formats: JPEG, PNG, or PDF'),
        ],

        // ── Secondary IDs ────────────────────────────────────────
        if (_idCategory == 'secondary') ...[
          _col(
            'First Secondary ID Type',
            _Dropdown(
              value: _secondaryId1Type,
              options: _secondaryIdTypes,
              hint: 'Select First ID Type',
              hasError: _errors.contains('secondaryId1Type'),
              onChanged: (val) => setState(() => _secondaryId1Type = val),
            ),
            required: true,
          ),
          _gap,
          _col(
            'Upload First ID',
            _UploadField(
              fileName: _secondaryId1FileName,
              hint: 'Upload First ID here',
              hasError: _errors.contains('secondaryId1'),
              onTap: () => _showImageSourceSheet(context, slot: 'secondary1'),
            ),
            required: true,
          ),
          _hintText('Accepted formats: JPEG, PNG, or PDF'),
          _gap,
          _col(
            'Second Secondary ID Type',
            _Dropdown(
              value: _secondaryId2Type,
              options: _secondaryIdTypes,
              hint: 'Select Second ID Type',
              hasError: _errors.contains('secondaryId2Type'),
              onChanged: (val) => setState(() => _secondaryId2Type = val),
            ),
            required: true,
          ),
          _gap,
          _col(
            'Upload Second ID',
            _UploadField(
              fileName: _secondaryId2FileName,
              hint: 'Upload Second ID here',
              hasError: _errors.contains('secondaryId2'),
              onTap: () => _showImageSourceSheet(context, slot: 'secondary2'),
            ),
            required: true,
          ),
        ],

        const SizedBox(height: 28),
        const _SectionHeader(
          title: 'Account Security',
          subtitle: 'Set a password to secure your account.',
        ),
        const SizedBox(height: 18),
        _col(
          'Password',
          _Field(
            controller: _passwordCtrl,
            hasError: _errors.contains('password'),
            hint: 'Create a password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffix: _eye(
              _obscurePassword,
              () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          required: true,
        ),
        _hintText('Minimum 8 characters with letters and numbers'),
        _gap,
        _col(
          'Confirm Password',
          _Field(
            controller: _confirmPasswordCtrl,
            hasError: _errors.contains('confirmPassword'),
            hint: 'Confirm your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            suffix: _eye(
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          required: true,
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // STEP 2 — Contact & Address
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Contact & Address',
          subtitle: 'Tell us about your contact and where you live.',
        ),
        const SizedBox(height: 18),
        _col(
          'Phone Number',
          _Field(
            controller: _phoneCtrl,
            hasError: _errors.contains('phone'),
            hint: 'e.g. 09XX XXX XXXX',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
          ),
          required: true,
        ),
        _gap,
        _col(
          'Province',
          _locationDropdown(
            hint: 'Select province',
            icon: Icons.map_outlined,
            hasError: _errors.contains('province'),
            loading: _loadingProvinces,
            value: _province?.code,
            items: _provinces
                .map(
                  (province) => DropdownMenuItem(
                    value: province.code,
                    child: Text(province.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (code) {
              if (code == null) return;
              for (final province in _provinces) {
                if (province.code == code) {
                  setState(() {
                    _province = province;
                    _municipalities = province.cities;
                    _municipality = null;
                    _barangay = null;
                    _barangays = const [];
                  });
                }
              }
            },
          ),
          required: true,
        ),
        _gap,
        _col(
          'Municipality / City',
          _locationDropdown(
            hint: _province == null
                ? 'Select a province first'
                : 'Select municipality or city',
            icon: Icons.location_city_outlined,
            hasError: _errors.contains('municipality'),
            loading: false,
            value: _municipality?.code,
            items: _municipalities
                .map(
                  (city) => DropdownMenuItem(
                    value: city.code,
                    child: Text(city.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (code) {
              if (code == null) return;
              for (final city in _municipalities) {
                if (city.code == code) {
                  setState(() => _municipality = city);
                  _loadBarangays(city);
                }
              }
            },
          ),
          required: true,
        ),
        _gap,
        _col(
          'Barangay',
          _locationDropdown(
            hint: _municipality == null
                ? 'Select a city first'
                : 'Select barangay',
            icon: Icons.holiday_village_outlined,
            hasError: _errors.contains('barangay'),
            loading: _loadingBarangays,
            value: _barangay?.code,
            items: _barangays
                .map(
                  (barangay) => DropdownMenuItem(
                    value: barangay.code,
                    child: Text(barangay.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (code) {
              if (code == null) return;
              for (final barangay in _barangays) {
                if (barangay.code == code) {
                  setState(() => _barangay = barangay);
                }
              }
            },
          ),
          required: true,
        ),
        _gap,
        _col(
          'Street / House No.',
          _Field(
            controller: _streetCtrl,
            hasError: _errors.contains('street'),
            hint: 'Enter street or house number',
            icon: Icons.home_outlined,
          ),
          required: true,
        ),
        _gap,
        _col(
          'Zip Code',
          _Field(
            controller: _zipCodeCtrl,
            hasError: _errors.contains('zipCode'),
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
  // STEP 3 — Review & Submit
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    final mi = _middleInitialCtrl.text.trim();
    final fullName =
        '${_firstNameCtrl.text.trim()} ${mi.isNotEmpty ? '$mi. ' : ''}${_lastNameCtrl.text.trim()}'
            .trim();

    String val(String v) => v.trim().isEmpty ? '—' : v.trim();

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
          title: 'User Information',
          onEdit: () {
            setState(() => _currentStep = 0);
            _scrollToTop();
          },
          rows: [
            _ReviewRow4(
              item1: _RC(
                label: 'Full Name',
                value: fullName.isEmpty ? '—' : fullName,
              ),
              item2: _RC(label: 'Phone Number', value: val(_phoneCtrl.text)),
              item3: _RC(
                label: 'Province',
                value: val(_province?.name ?? ''),
              ),
              item4: _RC(
                label: 'Street/House No.',
                value: val(_streetCtrl.text),
              ),
            ),
            _ReviewRow4(
              item1: _RC(label: 'Sex', value: _selectedSex ?? '—'),
              item2: _RC(label: 'Birthday', value: val(_birthdayCtrl.text)),
              item3: _RC(
                label: 'Municipality',
                value: val(_municipality?.name ?? ''),
              ),
              item4: _RC(label: 'Zip Code', value: val(_zipCodeCtrl.text)),
            ),
            _ReviewRow4(
              item1: _RC(label: 'Email', value: val(_emailCtrl.text)),
              item2: _RC(label: 'Age', value: val(_ageCtrl.text)),
              item3: _RC(
                label: 'Barangay',
                value: val(_barangay?.name ?? ''),
              ),
              item4: _RC(
                label: 'ID Category',
                value: _idCategory == 'primary'
                    ? 'Primary ID'
                    : 'Secondary ID (2 IDs)',
              ),
            ),
            if (_idCategory == 'primary')
              _ReviewRow4(
                item1: _RC(label: 'ID Type', value: _primaryIdType ?? '—'),
                item2: _RC(
                  label: 'ID File',
                  value: _validIdFileName ?? '—',
                  isFile: _validIdFileName != null,
                ),
                item3: const _RC(label: '', value: ''),
                item4: const _RC(label: '', value: ''),
              )
            else
              _ReviewRow4(
                item1: _RC(
                  label: '1st ID Type',
                  value: _secondaryId1Type ?? '—',
                ),
                item2: _RC(
                  label: '1st ID File',
                  value: _secondaryId1FileName ?? '—',
                  isFile: _secondaryId1FileName != null,
                ),
                item3: _RC(
                  label: '2nd ID Type',
                  value: _secondaryId2Type ?? '—',
                ),
                item4: _RC(
                  label: '2nd ID File',
                  value: _secondaryId2FileName ?? '—',
                  isFile: _secondaryId2FileName != null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Please Review Carefully ────────────────────────────
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
                'Our team will review your application and you will be notified via email once your account is approved.',
                style: TextStyle(color: _C.muted, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
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
                          color: _agreedToTerms ? _C.prune : _C.muted,
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

  Widget _buildLabel(String text, {bool required = false}) {
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
  // Camera / gallery sheet
  // ────────────────────────────────────────────────────────────────
  void _showImageSourceSheet(BuildContext context, {String slot = 'primary'}) {
    final title = slot == 'secondary1'
        ? 'Upload First ID'
        : slot == 'secondary2'
        ? 'Upload Second ID'
        : 'Upload Valid ID';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Future<void> pick(ImageSource source) async {
          Navigator.pop(sheetContext);
          final file = await ImagePicker().pickImage(
            source: source,
            imageQuality: 85,
          );
          if (file == null) return;
          setState(() {
            if (slot == 'secondary1') {
              _secondaryId1FileName = file.name;
              _secondaryId1Path = file.path;
            } else if (slot == 'secondary2') {
              _secondaryId2FileName = file.name;
              _secondaryId2Path = file.path;
            } else {
              _validIdFileName = file.name;
              _validIdPath = file.path;
            }
          });
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
              const Text(
                'Choose how you want to upload your ID',
                style: TextStyle(color: _C.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _SourceTile(
                icon: Icons.camera_alt_outlined,
                title: 'Take a Photo',
                subtitle: 'Use your camera to capture your ID',
                onTap: () => pick(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from Gallery',
                subtitle: 'Select an existing photo from your device',
                onTap: () => pick(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showVerifyEmailModal(BuildContext context) {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email address first.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerifyEmailModal(
        email: email,
        onVerified: (token) {
          setState(() => _verificationToken = token);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vendo bag logo (replaces the rider picture in the header)
// ─────────────────────────────────────────────────────────────────────────────
class _VendoBagLogo extends StatelessWidget {
  final double width, height;

  const _VendoBagLogo({this.width = 78, this.height = 88});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        child: SizedBox(
          width: 78,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: const Size(78, 88), painter: _BagPainter()),
              const Positioned(
                bottom: 16,
                child: Text(
                  'v',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BagPainter extends CustomPainter {
  Path _roundedBox(double l, double t, double r, double b, double rad) {
    return Path()
      ..moveTo(l + rad, t)
      ..lineTo(r - rad, t)
      ..quadraticBezierTo(r, t, r, t + rad)
      ..lineTo(r, b - rad)
      ..quadraticBezierTo(r, b, r - rad, b)
      ..lineTo(l + rad, b)
      ..quadraticBezierTo(l, b, l, b - rad)
      ..lineTo(l, t + rad)
      ..quadraticBezierTo(l, t, l + rad, t)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      _roundedBox(w * 0.18, h * 0.28, w * 0.98, h * 0.98, 10),
      Paint()..color = _C.brique,
    );
    canvas.drawPath(
      _roundedBox(w * 0.10, h * 0.28, w * 0.90, h * 0.94, 10),
      Paint()..color = _C.lin,
    );

    final left = w * 0.02;
    final right = w * 0.82;
    final top = h * 0.28;
    final bottom = h * 0.90;
    canvas.drawPath(
      _roundedBox(left, top, right, bottom, 10),
      Paint()..color = const Color(0xFFF0EEF5),
    );

    final handleCenter = (left + right) / 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(handleCenter, top),
        width: (right - left) * 0.40,
        height: h * 0.22,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFFF0EEF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    final eyeY = top + (bottom - top) * 0.28;
    final eyeSpacing = (right - left) * 0.22;
    final dot = Paint()..color = _C.brique;
    canvas.drawCircle(Offset(handleCenter - eyeSpacing, eyeY), 3.5, dot);
    canvas.drawCircle(Offset(handleCenter + eyeSpacing, eyeY), 3.5, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure, readOnly, hasError;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final VoidCallback? onTap;

  const _Field({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.readOnly = false,
    this.hasError = false,
    this.keyboard,
    this.inputFormatters,
    this.suffix,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      readOnly: readOnly,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      onTap: onTap,
      cursorColor: _C.prune,
      style: const TextStyle(color: _C.ink, fontSize: 15),
      decoration: _decoration(
        hint: hint,
        icon: icon,
        suffix: suffix,
        error: hasError,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown (used for sex and ID types)
// ─────────────────────────────────────────────────────────────────────────────
class _Dropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool hasError;

  const _Dropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: hasError ? _C.errorSoft : _C.background,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: hasError ? _C.error : _C.border,
          width: hasError ? 1.6 : 1.2,
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
            color: hasError ? _C.error : _C.muted,
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
// ID category toggle (Primary / Secondary)
// ─────────────────────────────────────────────────────────────────────────────
class _IdCategoryToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _IdCategoryToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _toggle('primary', 'Primary ID', '1 ID required')),
        const SizedBox(width: 10),
        Expanded(child: _toggle('secondary', 'Secondary ID', '2 IDs required')),
      ],
    );
  }

  Widget _toggle(String key, String label, String sub) {
    final selected = value == key;
    return GestureDetector(
      onTap: () => onChanged(key),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _C.prune : _C.background,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: selected ? _C.prune : _C.border,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _C.lin : _C.muted,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.lin,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _C.ink,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: selected ? const Color(0xB3FFFFFF) : _C.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  final bool hasError;

  const _UploadField({
    required this.fileName,
    required this.hint,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final picked = fileName != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: hasError
              ? _C.errorSoft
              : picked
              ? _C.raisinSoft
              : _C.background,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: hasError
                ? _C.error
                : picked
                ? _C.raisin.withAlpha(90)
                : _C.border,
            width: hasError ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              picked ? Icons.insert_drive_file_outlined : Icons.attach_file,
              color: hasError ? _C.error : _C.raisin,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: picked ? _C.ink : (hasError ? _C.error : _C.muted),
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              picked ? Icons.check_circle_rounded : Icons.upload_outlined,
              color: picked
                  ? _C.success
                  : hasError
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
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final bool submitting;

  const _BottomNextBar({
    required this.currentStep,
    required this.onNext,
    this.onBack,
    this.submitting = false,
  });

  static const _nextLabels = [
    'Next: Contact & Address',
    'Next: Review & Submit',
    'Submit',
  ];

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == _nextLabels.length - 1;

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
                onPressed: submitting ? null : onBack,
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
                onPressed: submitting ? null : onNext,
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
                          SizedBox(width: 10),
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
// Verify email modal
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyEmailModal extends StatefulWidget {
  final String email;
  final ValueChanged<String> onVerified;

  const _VerifyEmailModal({required this.email, required this.onVerified});

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
    for (final c in _otpControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _errorMsg = null;
    });
    try {
      await BuyerApi.instance.sendOtp(widget.email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sending = false;
      });
    } on BuyerApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.message;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Could not send the code. Check your connection.';
        _sending = false;
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
      final token = await BuyerApi.instance.verifyOtp(widget.email, code);
      if (!mounted) return;
      widget.onVerified(token);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email verified.')));
    } on BuyerApiException catch (e) {
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
    // Auto-submit when all 6 digits entered
    if (_otpControllers.every((c) => c.text.length == 1)) {
      _verify();
    }
  }

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
              color: _C.border,
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
                  color: _C.raisinSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: _C.prune,
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
                    color: _C.prune,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: _C.lin, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const Text(
            'Verify Your Email',
            style: TextStyle(
              color: _C.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _sending
                ? 'Sending code to ${widget.email}…'
                : "We sent a 6-digit code to ${widget.email}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.muted, fontSize: 14, height: 1.4),
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
                  cursorColor: _C.prune,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _C.background,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: _border(_C.border, 1.2),
                    focusedBorder: _border(_C.prune, 1.8),
                    disabledBorder: _border(_C.border, 1.2),
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
              style: const TextStyle(color: _C.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 20),

          // Resend
          GestureDetector(
            onTap: _sending ? null : _sendCode,
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
                      color: _C.raisin,
                    ),
                  )
                else
                  const Icon(Icons.refresh_rounded, color: _C.raisin, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Resend Code',
                  style: TextStyle(
                    color: _C.raisin,
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
                backgroundColor: _C.prune,
                disabledBackgroundColor: _C.prune,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
              child: _verifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _C.lin,
                      ),
                    )
                  : const Text(
                      'Verify Email',
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
// Success modal
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessModal extends StatelessWidget {
  final VoidCallback onBackToLogin;

  const _SuccessModal({required this.onBackToLogin});

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

          // The bag logo on a purple card, with a green check badge
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
                const Center(child: _VendoBagLogo(width: 78, height: 88)),
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
          const Text(
            'You will receive an email once your account has\nbeen approved by the administrator',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.muted, fontSize: 14, height: 1.5),
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
      star.color = Colors.white.withAlpha(
        (25 + 105 * _hash(i * 3 + 4)).round(),
      );
      canvas.drawCircle(Offset(x, y), r, star);
    }
  }

  @override
  bool shouldRepaint(covariant _DecorPainter old) => false;
}
