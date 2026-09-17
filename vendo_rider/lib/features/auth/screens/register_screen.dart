import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vendo_rider/features/auth/services/license_ocr_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0; // 0,1,2,3

  // ── Step 1: Personal Information ──────────────────────────────
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleInitialCtrl = TextEditingController();
  String? _selectedSex;
  final _emailCtrl = TextEditingController();
  final _birthdayCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _validIdFileName;

  // ── Step 2: Vehicle Details ────────────────────────────────────
  String? _vehicleType;
  final _plateNumberCtrl = TextEditingController();
  String? _driversLicenseFile;
  String? _orCrFile;

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

  static const int _totalSteps = 4;

  final List<String> _sexOptions = ['Male', 'Female', 'Prefer not to say'];
  final List<String> _vehicleOptions = [
    'Motorcycle',
    'Bicycle',
    'Tricycle',
    'Car',
  ];

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleInitialCtrl.dispose();
    _emailCtrl.dispose();
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
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _showSuccessModal(context);
    }
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessModal(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FB),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onLoginTap: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      'Rider Registration',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Create your rider account',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // ── Progress stepper ──────────────────────────
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
          ],
        ),
      ),
      bottomNavigationBar: _BottomNextBar(
        currentStep: _currentStep,
        totalSteps: _totalSteps,
        onNext: _nextStep,
        onBack: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
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
        _SectionHeader(
          title: 'Personal Information',
          subtitle: 'Please provide your personal details',
        ),
        const SizedBox(height: 16),

        _label('Last Name', required: true),
        const SizedBox(height: 6),
        _Field(controller: _lastNameCtrl, hint: 'Enter last name'),
        const SizedBox(height: 12),

        _label('First Name', required: true),
        const SizedBox(height: 6),
        _Field(controller: _firstNameCtrl, hint: 'Enter first name'),
        const SizedBox(height: 12),

        _label('Middle Initial'),
        const SizedBox(height: 6),
        _Field(controller: _middleInitialCtrl, hint: 'Enter middle initial'),
        const SizedBox(height: 12),

        _label('Sex', required: true),
        const SizedBox(height: 6),
        _Dropdown(
          value: _selectedSex,
          hint: 'Select Sex',
          options: _sexOptions,
          onChanged: (v) => setState(() => _selectedSex = v),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            _label('Email', required: true),
            const Spacer(),
            GestureDetector(
              onTap: () => _showVerifyEmailModal(context),
              child: const Text(
                'Verify',
                style: TextStyle(
                  color: Color(0xFF7B2FBE),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _Field(
          controller: _emailCtrl,
          hint: 'Enter email address',
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Birthday', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _birthdayCtrl,
                    hint: 'mm/dd/yyyy',
                    readOnly: true,
                    suffix: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF888888),
                    ),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF3B1F52),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (p != null) {
                        _birthdayCtrl.text =
                            '${p.month.toString().padLeft(2, '0')}/${p.day.toString().padLeft(2, '0')}/${p.year}';
                        _ageCtrl.text = (DateTime.now().year - p.year)
                            .toString();
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Age', required: true),
                  const SizedBox(height: 6),
                  _Field(controller: _ageCtrl, hint: '--', readOnly: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _label('Valid ID', required: true),
        const SizedBox(height: 6),
        _UploadField(
          fileName: _validIdFileName,
          hint: 'Upload Valid ID here',
          onTap: () => _showImageSourceSheet(
            context,
            (n) => setState(() => _validIdFileName = n),
          ),
        ),
        const SizedBox(height: 24),

        _SectionHeader(
          title: 'Account Security',
          subtitle: 'Set a password to secure your account.',
        ),
        const SizedBox(height: 16),

        _label('Password', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _passwordCtrl,
          hint: 'Create a password',
          obscure: _obscurePass,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePass = !_obscurePass),
            child: Icon(
              _obscurePass
                  ? Icons.remove_red_eye_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: const Color(0xFF888888),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Text(
            'Minimum 8 characters with letters and numbers',
            style: TextStyle(color: Color(0xFF999999), fontSize: 11),
          ),
        ),
        const SizedBox(height: 12),

        _label('Confirm Password', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _confirmPassCtrl,
          hint: 'Confirm your password',
          obscure: _obscureConfirm,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            child: Icon(
              _obscureConfirm
                  ? Icons.remove_red_eye_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: const Color(0xFF888888),
            ),
          ),
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
        _SectionHeader(
          title: 'Vehicle Details',
          subtitle: 'Provide your vehicle and license information',
        ),
        const SizedBox(height: 16),

        _label('Type of Vehicle', required: true),
        const SizedBox(height: 6),
        _Dropdown(
          value: _vehicleType,
          hint: 'Select vehicle type',
          options: _vehicleOptions,
          onChanged: (v) => setState(() => _vehicleType = v),
        ),
        const SizedBox(height: 12),

        _label('Plate Number', required: true),
        const SizedBox(height: 6),
        _Field(controller: _plateNumberCtrl, hint: 'e.g. ABC 1234'),
        const SizedBox(height: 12),

        _label("Driver's License", required: true),
        const SizedBox(height: 6),
        _UploadField(
          fileName: _driversLicenseFile,
          hint: "Upload Driver's License",
          onTap: () => _showLicenseSourceSheet(context),
        ),
        // Scanning indicator
        if (_scanningLicense)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8F8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD0EE)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2D1B3D),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Scanning license, please wait…',
                  style: TextStyle(
                    color: Color(0xFF2D1B3D),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // ── Driver's License Information ───────────────────────
        _SectionHeader(
          title: "Driver's License Information",
          subtitle: 'Fill in the details as shown on your license',
        ),
        const SizedBox(height: 16),

        // Last Name / First Name side by side
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Last Name', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _dlLastNameCtrl,
                    hint: 'Last name on license',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('First Name', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _dlFirstNameCtrl,
                    hint: 'First name on license',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _label('Middle Name'),
        const SizedBox(height: 6),
        _Field(controller: _dlMiddleNameCtrl, hint: 'Middle name on license'),
        const SizedBox(height: 12),

        _label('Address', required: true),
        const SizedBox(height: 6),
        _Field(controller: _dlAddressCtrl, hint: 'Address as shown on license'),
        const SizedBox(height: 12),

        // License No. / Expiration Date side by side
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('License No.', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _dlLicenseNoCtrl,
                    hint: 'e.g. N01-23-456789',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Expiration Date', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _dlExpirationCtrl,
                    hint: 'mm/dd/yyyy',
                    readOnly: true,
                    suffix: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF888888),
                    ),
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2060),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF3B1F52),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (p != null) {
                        _dlExpirationCtrl.text =
                            '${p.month.toString().padLeft(2, '0')}/${p.day.toString().padLeft(2, '0')}/${p.year}';
                        setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Nationality / Blood Type side by side
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Nationality', required: true),
                  const SizedBox(height: 6),
                  _Field(controller: _dlNationalityCtrl, hint: 'e.g. Filipino'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Blood Type'),
                  const SizedBox(height: 6),
                  _Dropdown(
                    value: _dlBloodTypeCtrl.text.isEmpty
                        ? null
                        : _dlBloodTypeCtrl.text,
                    hint: 'Select',
                    options: const [
                      'A+',
                      'A-',
                      'B+',
                      'B-',
                      'AB+',
                      'AB-',
                      'O+',
                      'O-',
                    ],
                    onChanged: (v) =>
                        setState(() => _dlBloodTypeCtrl.text = v ?? ''),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _label('Driver\'s License Code', required: true),
        const SizedBox(height: 4),
        const Text(
          'Vehicle classification you are authorized to drive',
          style: TextStyle(color: Color(0xFF999999), fontSize: 11),
        ),
        const SizedBox(height: 6),
        _Dropdown(
          value: _dlRestrictionCode,
          hint: 'Select license code',
          options: const [
            'A — Motorcycle',
            'A1 — Tricycle',
            'B — Up to 4,500 KGS GVW / 8 seats',
          ],
          onChanged: (v) => setState(() => _dlRestrictionCode = v),
        ),

        const SizedBox(height: 24),

        _label('OR / CR', required: true),
        const SizedBox(height: 4),
        const Text(
          'Official Receipt / Certificate of Registration',
          style: TextStyle(color: Color(0xFF999999), fontSize: 11),
        ),
        const SizedBox(height: 6),
        _UploadField(
          fileName: _orCrFile,
          hint: 'Upload OR / CR',
          onTap: () => _showImageSourceSheet(
            context,
            (n) => setState(() => _orCrFile = n),
          ),
        ),
        const SizedBox(height: 20),

        // ── OR / CR Information ────────────────────────────────
        _SectionHeader(
          title: 'OR / CR Information',
          subtitle: 'Fill in the details as shown on your OR / CR',
        ),
        const SizedBox(height: 16),

        // MV File No. + Plate No.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('MV File No.', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _orCrMVFileNoCtrl,
                    hint: 'e.g. 1234567890',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Plate No.', required: true),
                  const SizedBox(height: 6),
                  _Field(controller: _orCrPlateNoCtrl, hint: 'e.g. ABC 1234'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Make / Series (model name)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Make', required: true),
                  const SizedBox(height: 6),
                  _Field(controller: _orCrMakeCtrl, hint: 'e.g. Honda, Yamaha'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Series / Model'),
                  const SizedBox(height: 6),
                  _Field(controller: _orCrSeriesCtrl, hint: 'e.g. Click 125i'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Body Type + Color
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Body Type', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _orCrBodyTypeCtrl,
                    hint: 'e.g. Motorcycle',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Color'),
                  const SizedBox(height: 6),
                  _Field(controller: _orCrColorCtrl, hint: 'e.g. Black'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Year Model + Engine No.
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Year Model', required: true),
                  const SizedBox(height: 6),
                  _Field(
                    controller: _orCrYearModelCtrl,
                    hint: 'e.g. 2022',
                    keyboard: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Engine No.', required: true),
                  const SizedBox(height: 6),
                  _Field(controller: _orCrEngineNoCtrl, hint: 'Engine number'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _label('Chassis No.', required: true),
        const SizedBox(height: 6),
        _Field(controller: _orCrChassisNoCtrl, hint: 'Chassis / VIN number'),
        const SizedBox(height: 12),

        _label('Registered Owner', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _orCrOwnerCtrl,
          hint: 'Full name of registered owner',
        ),
        const SizedBox(height: 12),

        _label('Owner\'s Address', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _orCrAddressCtrl,
          hint: 'Address of registered owner',
        ),
        const SizedBox(height: 12),

        _label('Registration Expiration', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _orCrExpirationCtrl,
          hint: 'mm/dd/yyyy',
          readOnly: true,
          suffix: const Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: Color(0xFF888888),
          ),
          onTap: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 365)),
              firstDate: DateTime.now(),
              lastDate: DateTime(2060),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF3B1F52),
                  ),
                ),
                child: child!,
              ),
            );
            if (p != null) {
              _orCrExpirationCtrl.text =
                  '${p.month.toString().padLeft(2, '0')}/${p.day.toString().padLeft(2, '0')}/${p.year}';
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // STEP 3 — Contact & Address
  // ────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Contact & Address',
          subtitle: 'Tell us about your contact and where you live.',
        ),
        const SizedBox(height: 16),

        _label('Phone Number', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _phoneCtrl,
          hint: 'e.g. 09XX XXX XXXX',
          keyboard: TextInputType.phone,
          suffix: const Icon(
            Icons.phone_outlined,
            size: 18,
            color: Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 12),

        _label('Province', required: true),
        const SizedBox(height: 6),
        _Field(controller: _provinceCtrl, hint: 'Enter province'),
        const SizedBox(height: 12),

        _label('Municipality / City', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _municipalityCtrl,
          hint: 'Enter municipality or city',
        ),
        const SizedBox(height: 12),

        _label('Barangay', required: true),
        const SizedBox(height: 6),
        _Field(controller: _barangayCtrl, hint: 'Enter barangay'),
        const SizedBox(height: 12),

        _label('Street / House No.', required: true),
        const SizedBox(height: 6),
        _Field(controller: _streetCtrl, hint: 'Enter street or house number'),
        const SizedBox(height: 12),

        _label('Zip Code', required: true),
        const SizedBox(height: 6),
        _Field(
          controller: _zipCodeCtrl,
          hint: 'Enter zip code',
          keyboard: TextInputType.number,
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
        const Text(
          'Review your Information',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Please review all the details below before submitting your registration',
          style: TextStyle(color: Color(0xFF888888), fontSize: 12.5),
        ),
        const SizedBox(height: 20),

        _ReviewCard(
          title: 'Rider Information',
          onEdit: () => setState(() => _currentStep = 0),
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
            color: const Color(0xFFF0E8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDD0EE), width: 1),
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
                      color: Color(0xFF2D1B3D),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
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
                      color: Color(0xFF1A1A2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'By submitting this registration, you confirm that all information provided is true and correct. '
                'Our team will review your application and you will be notified via email once your account is approved.',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _agreedToTerms
                            ? const Color(0xFF2D1B3D)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: const Color(0xFF888888),
                          width: 1.2,
                        ),
                      ),
                      child: _agreedToTerms
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 11,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms and Conditions',
                              style: TextStyle(
                                color: Color(0xFF2D1B3D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Color(0xFF2D1B3D),
                                fontWeight: FontWeight.w700,
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFE53935)),
                ),
              ]
            : [],
      ),
    );
  }

  void _showLicenseSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          20 + MediaQuery.of(context).padding.bottom,
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
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Scan Driver's License",
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Take or upload a photo — fields will be auto-filled',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 20),
            _SourceTile(
              icon: Icons.document_scanner_outlined,
              title: 'Scan with Camera',
              subtitle: 'Point camera at your license to auto-fill',
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  imageQuality: 90,
                );
                if (file != null) {
                  await _runLicenseOcr(file.path, file.name);
                }
              },
            ),
            const SizedBox(height: 12),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Select a photo of your license from gallery',
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                );
                if (file != null) {
                  await _runLicenseOcr(file.path, file.name);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _runLicenseOcr(String path, String fileName) async {
    setState(() {
      _driversLicenseFile = fileName;
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
            backgroundColor: filled > 0
                ? const Color(0xFF2D1B3D)
                : const Color(0xFFCC4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan failed. Please fill in the fields manually.'),
            backgroundColor: Color(0xFFCC4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _scanningLicense = false);
      }
    }
  }

  void _showImageSourceSheet(
    BuildContext context,
    void Function(String) onPicked,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          20 + MediaQuery.of(context).padding.bottom,
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
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Document',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you want to upload',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 20),
            _SourceTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take a Photo',
              subtitle: 'Use your camera to capture the document',
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker().pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (file != null) {
                  onPicked(file.name);
                }
              },
            ),
            const SizedBox(height: 12),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Select an existing photo from your device',
              onTap: () async {
                Navigator.pop(context);
                final file = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (file != null) {
                  onPicked(file.name);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showVerifyEmailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerifyEmailModal(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Step Bar — card-style active step with icon + label + progress line
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
        // Active step card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D1B3D),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icons[currentStep], color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${currentStep + 1} of $totalSteps',
                      style: const TextStyle(
                        color: Color(0xAAFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[currentStep],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Next step preview
              if (currentStep < totalSteps - 1)
                Text(
                  'Next: ${labels[currentStep + 1]}',
                  style: const TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

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
                        color: (isDone || isActive)
                            ? const Color(0xFF2D1B3D)
                            : const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        color: (isDone || isActive)
                            ? const Color(0xFF2D1B3D)
                            : const Color(0xFFBBBBBB),
                        fontWeight: (isDone || isActive)
                            ? FontWeight.w700
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
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onLoginTap;
  const _TopBar({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1F52), Color(0xFF2A1440)],
        ),
      ),
      child: Row(
        children: [
          _SmallBagLogo(),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'vendo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                'BUY. SELL. DELIVERED',
                style: TextStyle(
                  color: Color(0xFFE8873A),
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Already have an account?  ',
            style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
          ),
          GestureDetector(
            onTap: onLoginTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

class _SmallBagLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 40,
    child: CustomPaint(painter: _SmallBagPainter()),
  );
}

class _SmallBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void draw(double l, double r, double t, double b, Color c, double rad) {
      final p = Paint()
        ..color = c
        ..style = PaintingStyle.fill;
      final path = Path()
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
      canvas.drawPath(path, p);
    }

    draw(w * .18, w * .98, h * .28, h * .98, const Color(0xFFE8873A), 5);
    draw(w * .10, w * .90, h * .28, h * .94, const Color(0xFFB8860B), 5);
    draw(w * .02, w * .82, h * .28, h * .90, const Color(0xFFF0EEF5), 5);
    final cx = (w * .02 + w * .82) / 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * .28),
        width: (w * .80) * .40,
        height: h * .22,
      ),
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = const Color(0xFFF0EEF5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final eyeY = h * .28 + (h * .62) * .28;
    final dp = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - w * .18, eyeY), 2, dp);
    canvas.drawCircle(Offset(cx + w * .18, eyeY), 2, dp);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'v',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2 - 1, h * .50));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
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
            color: Color(0xFF1A1A2E),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xFFE0E0E0), thickness: 1),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure, readOnly;
  final TextInputType? keyboard;
  final Widget? suffix;
  final VoidCallback? onTap;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.readOnly = false,
    this.keyboard,
    this.suffix,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        readOnly: readOnly,
        keyboardType: keyboard,
        onTap: onTap,
        style: const TextStyle(color: Color(0xFF333333), fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.5),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
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
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.5),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF888888),
            size: 20,
          ),
          items: options
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 13.5,
                    ),
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
// Upload Field
// ─────────────────────────────────────────────────────────────────────────────
class _UploadField extends StatelessWidget {
  final String? fileName;
  final String hint;
  final VoidCallback onTap;
  const _UploadField({
    required this.fileName,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fileName ?? hint,
                style: TextStyle(
                  color: fileName != null
                      ? const Color(0xFF333333)
                      : const Color(0xFFBBBBBB),
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(
              Icons.upload_outlined,
              color: Color(0xFF888888),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source Tile
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F5FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFEEE6F5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF2D1B3D), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFAAAAAA), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review Card
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
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
                  color: Color(0xFFEEE6F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF7B2FBE),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFAAAAAA),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFF0F0F0), height: 1),
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

// ─────────────────────────────────────────────────────────────────────────────
// Review Row 4-col
// ─────────────────────────────────────────────────────────────────────────────
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
          style: const TextStyle(color: Color(0xFF999999), fontSize: 10.5),
        ),
        const SizedBox(height: 3),
        item.isFile
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 12,
                      color: Color(0xFF555555),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        item.value,
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
                  color: Color(0xFF1A1A2E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
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
// Bottom Bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNextBar extends StatelessWidget {
  final int currentStep, totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  const _BottomNextBar({
    required this.currentStep,
    required this.totalSteps,
    required this.onNext,
    this.onBack,
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
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F5FB),
        border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: isLast
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (onBack != null) ...[
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2D1B3D), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  color: Color(0xFF2D1B3D),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (isLast)
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D1B3D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            )
          else
            Expanded(
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D1B3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _nextLabels[currentStep],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verify Email Modal
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyEmailModal extends StatefulWidget {
  @override
  State<_VerifyEmailModal> createState() => _VerifyEmailModalState();
}

class _VerifyEmailModalState extends State<_VerifyEmailModal> {
  final List<TextEditingController> _ctrl = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrl) {
      c.dispose();
    }
    for (final f in _nodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0E8F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFF2D1B3D),
                  size: 38,
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D1B3D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Verify Your Email',
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "We've sent a 6-digit code to your email.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (i) => SizedBox(
                width: 46,
                height: 56,
                child: TextField(
                  controller: _ctrl[i],
                  focusNode: _nodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFCCCCCC),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2D1B3D),
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.length == 1 && i < 5) {
                      _nodes[i + 1].requestFocus();
                    } else if (val.isEmpty && i > 0) {
                      _nodes[i - 1].requestFocus();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.refresh_rounded, color: Color(0xFFCC2222), size: 18),
                SizedBox(width: 6),
                Text(
                  'Resend Code',
                  style: TextStyle(
                    color: Color(0xFFCC2222),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D1B3D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Verify Email',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Modal
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
        28,
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
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 18,
                  right: 28,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF9B59B6),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 28,
                  right: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D1B3D),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 48,
                  right: 4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8873A),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 42,
                  right: 18,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8B84B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 155,
                  child: CustomPaint(painter: _SuccessBagPainter()),
                ),
                Positioned(
                  top: 38,
                  right: 22,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2ECC71),
                      shape: BoxShape.circle,
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
          const SizedBox(height: 24),
          const Text(
            'Thank you for Registering',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your registration is pending review',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You will receive an email once your account has\nbeen approved by the administrator',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onBackToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D1B3D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Back to Login',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SuccessBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void draw(double l, double r, double t, double b, Color c, double rad) {
      final p = Paint()
        ..color = c
        ..style = PaintingStyle.fill;
      final path = Path()
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
      canvas.drawPath(path, p);
    }

    draw(w * .22, w * 1.0, h * .30, h * 1.0, const Color(0xFFE8C97A), 14);
    draw(w * .12, w * .90, h * .30, h * .96, const Color(0xFFC0663A), 14);
    draw(w * .02, w * .78, h * .30, h * .92, const Color(0xFF2D1B3D), 14);
    final cx = (w * .02 + w * .78) / 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * .30),
        width: (w * .76) * .44,
        height: h * .26,
      ),
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = const Color(0xFF2D1B3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    final eyeY = h * .30 + (h * .62) * .22;
    final ep = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - (w * .76) * .18, eyeY), 5, ep);
    canvas.drawCircle(Offset(cx + (w * .76) * .18, eyeY), 5, ep);
    final tp = TextPainter(
      text: const TextSpan(
        text: 'V',
        style: TextStyle(
          color: Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, h * .44));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
