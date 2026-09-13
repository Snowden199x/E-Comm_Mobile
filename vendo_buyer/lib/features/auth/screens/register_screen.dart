import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;

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
  String? _validIdFileName;

  // Step 2 controllers
  final _phoneCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _zipCodeCtrl = TextEditingController();

  // Step 3
  bool _agreedToTerms = false;

  final List<String> _sexOptions = ['Male', 'Female', 'Prefer not to say'];

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
    _provinceCtrl.dispose();
    _municipalityCtrl.dispose();
    _barangayCtrl.dispose();
    _streetCtrl.dispose();
    _zipCodeCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
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
        onBackToLogin: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

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
                      'Buyer Registration',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Create your buyer account',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _StepIndicator(currentStep: _currentStep),
                    const SizedBox(height: 24),
                    if (_currentStep == 0) _buildStep1(),
                    if (_currentStep == 1) _buildStep2(),
                    if (_currentStep == 2) _buildStep3(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNextBar(
        currentStep: _currentStep,
        onNext: _nextStep,
        onBack: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // STEP 1 — Personal Information
  // ──────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Personal Information',
          subtitle: 'Please provide your personal details',
        ),
        const SizedBox(height: 16),
        _buildLabel('Last Name', required: true),
        const SizedBox(height: 6),
        _RegInputField(controller: _lastNameCtrl, hint: 'Enter last name'),
        const SizedBox(height: 12),
        _buildLabel('First Name', required: true),
        const SizedBox(height: 6),
        _RegInputField(controller: _firstNameCtrl, hint: 'Enter first name'),
        const SizedBox(height: 12),
        _buildLabel('Middle Initial'),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _middleInitialCtrl,
          hint: 'Enter middle initial',
        ),
        const SizedBox(height: 12),
        _buildLabel('Sex', required: true),
        const SizedBox(height: 6),
        _SexDropdown(
          value: _selectedSex,
          options: _sexOptions,
          onChanged: (val) => setState(() => _selectedSex = val),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLabel('Email', required: true),
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
        _RegInputField(
          controller: _emailCtrl,
          hint: 'Enter email address',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Birthday', required: true),
                  const SizedBox(height: 6),
                  _RegInputField(
                    controller: _birthdayCtrl,
                    hint: 'mm/dd/yyyy',
                    readOnly: true,
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Color(0xFF888888),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF3B1F52),
                            ),
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
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Age', required: true),
                  const SizedBox(height: 6),
                  _RegInputField(
                    controller: _ageCtrl,
                    hint: '--',
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLabel('Valid ID', required: true),
        const SizedBox(height: 6),
        _UploadField(
          fileName: _validIdFileName,
          hint: 'Upload Valid ID here',
          onTap: () => _showImageSourceSheet(context),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Account Security',
          subtitle: 'Set a password to secure your account.',
        ),
        const SizedBox(height: 16),
        _buildLabel('Password', required: true),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _passwordCtrl,
          hint: 'Create a password',
          obscureText: _obscurePassword,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
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
        _buildLabel('Confirm Password', required: true),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _confirmPasswordCtrl,
          hint: 'Confirm your password',
          obscureText: _obscureConfirm,
          suffixIcon: GestureDetector(
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

  // ──────────────────────────────────────────────────────────────
  // STEP 2 — Contact & Address
  // ──────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Contact & Address',
          subtitle: 'Tell us about your contact and where you live.',
        ),
        const SizedBox(height: 16),
        _buildLabel('Phone Number', required: true),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _phoneCtrl,
          hint: 'e.g. 09XX XXX XXXX',
          keyboardType: TextInputType.phone,
          suffixIcon: const Icon(
            Icons.phone_outlined,
            size: 18,
            color: Color(0xFF888888),
          ),
        ),
        const SizedBox(height: 12),
        _buildLabel('Province', required: true),
        const SizedBox(height: 6),
        _RegInputField(controller: _provinceCtrl, hint: 'Enter province'),
        const SizedBox(height: 12),
        _buildLabel('Municipality / City', required: true),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _municipalityCtrl,
          hint: 'Enter municipality or city',
        ),
        const SizedBox(height: 12),
        _buildLabel('Barangay', required: true),
        const SizedBox(height: 6),
        _RegInputField(controller: _barangayCtrl, hint: 'Enter barangay'),
        const SizedBox(height: 12),
        _buildLabel('Street / House No.', required: true),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _streetCtrl,
          hint: 'Enter street or house number',
        ),
        const SizedBox(height: 12),
        _buildLabel('Zip Code', required: true),
        const SizedBox(height: 6),
        _RegInputField(
          controller: _zipCodeCtrl,
          hint: 'Enter zip code',
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────
  // STEP 3 — Review & Submit
  // ──────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    final mi = _middleInitialCtrl.text.trim();
    final fullName =
        '${_firstNameCtrl.text.trim()} ${mi.isNotEmpty ? '$mi. ' : ''}${_lastNameCtrl.text.trim()}'
            .trim();

    String val(String v) => v.trim().isEmpty ? '—' : v.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
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

        // ── User Information Card ──────────────────────────────
        Container(
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
              // Card header
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
                  const Text(
                    'User Information',
                    style: TextStyle(
                      color: Color(0xFF1A1A2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _currentStep = 0),
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

              // Row 1: Full Name | Phone Number | Province | Street/House No.
              _ReviewRow4(
                item1: _ReviewCell(
                  label: 'Full Name',
                  value: fullName.isEmpty ? '—' : fullName,
                ),
                item2: _ReviewCell(
                  label: 'Phone Number',
                  value: val(_phoneCtrl.text),
                ),
                item3: _ReviewCell(
                  label: 'Province',
                  value: val(_provinceCtrl.text),
                ),
                item4: _ReviewCell(
                  label: 'Street/House No.',
                  value: val(_streetCtrl.text),
                ),
              ),
              const SizedBox(height: 14),

              // Row 2: Sex | Birthday | Municipality | Zip Code
              _ReviewRow4(
                item1: _ReviewCell(label: 'Sex', value: _selectedSex ?? '—'),
                item2: _ReviewCell(
                  label: 'Birthday',
                  value: val(_birthdayCtrl.text),
                ),
                item3: _ReviewCell(
                  label: 'Municipality',
                  value: val(_municipalityCtrl.text),
                ),
                item4: _ReviewCell(
                  label: 'Zip Code',
                  value: val(_zipCodeCtrl.text),
                ),
              ),
              const SizedBox(height: 14),

              // Row 3: Email | Age | Barangay | Valid ID
              _ReviewRow4(
                item1: _ReviewCell(label: 'Email', value: val(_emailCtrl.text)),
                item2: _ReviewCell(label: 'Age', value: val(_ageCtrl.text)),
                item3: _ReviewCell(
                  label: 'Barangay',
                  value: val(_barangayCtrl.text),
                ),
                item4: _ReviewCell(
                  label: 'Valid ID',
                  value: _validIdFileName ?? '—',
                  isFile: _validIdFileName != null,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Please Review Carefully ────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0E8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDD0EE), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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

  void _showImageSourceSheet(BuildContext context) {
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
            // Handle
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
              'Upload Valid ID',
              style: TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you want to upload your ID',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Camera option
            _ImageSourceTile(
              icon: Icons.camera_alt_outlined,
              title: 'Take a Photo',
              subtitle: 'Use your camera to capture your ID',
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (file != null) {
                  setState(() => _validIdFileName = file.name);
                }
              },
            ),
            const SizedBox(height: 12),

            // Gallery option
            _ImageSourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              subtitle: 'Select an existing photo from your device',
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (file != null) {
                  setState(() => _validIdFileName = file.name);
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

  Widget _buildLabel(String text, {bool required = false}) {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 40,
      child: CustomPaint(painter: _SmallBagPainter()),
    );
  }
}

class _SmallBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawBag(
      double left,
      double right,
      double top,
      double bottom,
      Color color,
      double r,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(left + r, top)
        ..lineTo(right - r, top)
        ..quadraticBezierTo(right, top, right, top + r)
        ..lineTo(right, bottom - r)
        ..quadraticBezierTo(right, bottom, right - r, bottom)
        ..lineTo(left + r, bottom)
        ..quadraticBezierTo(left, bottom, left, bottom - r)
        ..lineTo(left, top + r)
        ..quadraticBezierTo(left, top, left + r, top)
        ..close();
      canvas.drawPath(path, paint);
    }

    drawBag(w * 0.18, w * 0.98, h * 0.28, h * 0.98, const Color(0xFFE8873A), 5);
    drawBag(w * 0.10, w * 0.90, h * 0.28, h * 0.94, const Color(0xFFB8860B), 5);
    drawBag(w * 0.02, w * 0.82, h * 0.28, h * 0.90, const Color(0xFFF0EEF5), 5);

    final cx = (w * 0.02 + w * 0.82) / 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * 0.28),
        width: (w * 0.82 - w * 0.02) * 0.40,
        height: h * 0.22,
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

    final eyeY = h * 0.28 + (h * 0.90 - h * 0.28) * 0.28;
    final dp = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - (w * 0.82 - w * 0.02) * 0.22, eyeY), 2, dp);
    canvas.drawCircle(Offset(cx + (w * 0.82 - w * 0.02) * 0.22, eyeY), 2, dp);

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
    tp.paint(canvas, Offset(cx - tp.width / 2 - 1, h * 0.50));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const List<String> _labels = [
    'Personal Information',
    'Contact & Address',
    'Review & Submit',
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == currentStep;
        final isDone = i < currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isActive || isDone)
                            ? const Color(0xFF2D1B3D)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (isActive || isDone)
                              ? const Color(0xFF2D1B3D)
                              : const Color(0xFFCCCCCC),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFFAAAAAA),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive
                            ? const Color(0xFF2D1B3D)
                            : const Color(0xFFAAAAAA),
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: i < currentStep
                        ? const Color(0xFF2D1B3D)
                        : const Color(0xFFDDDDDD),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
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
// Reusable Register Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _RegInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;

  const _RegInputField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.readOnly = false,
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
        obscureText: obscureText,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: Color(0xFF333333), fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.5),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: suffixIcon,
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
// Sex Dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _SexDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _SexDropdown({
    required this.value,
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
          hint: const Text(
            'Select Sex',
            style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13.5),
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
// Review Row — 4 equal columns matching the reference image layout
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewRow4 extends StatelessWidget {
  final _ReviewCell item1;
  final _ReviewCell item2;
  final _ReviewCell item3;
  final _ReviewCell item4;

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
        Expanded(child: _buildCell(item1)),
        const SizedBox(width: 8),
        Expanded(child: _buildCell(item2)),
        const SizedBox(width: 8),
        Expanded(child: _buildCell(item3)),
        const SizedBox(width: 8),
        Expanded(child: _buildCell(item4)),
      ],
    );
  }

  Widget _buildCell(_ReviewCell item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          style: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
          ),
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

class _ReviewCell {
  final String label;
  final String value;
  final bool isFile;
  const _ReviewCell({
    required this.label,
    required this.value,
    this.isFile = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Bar — Back (outlined) + Next/Submit (filled dark)
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNextBar extends StatelessWidget {
  final int currentStep;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const _BottomNextBar({
    required this.currentStep,
    required this.onNext,
    this.onBack,
  });

  static const List<String> _nextLabels = [
    'Next: Contact & Address',
    'Next: Review & Submit',
    'Submit',
  ];

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentStep == 2;

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
        mainAxisAlignment: isLastStep
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
          if (isLastStep)
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
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

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

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 28 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Mail icon with check badge
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

          // Title
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
                  onChanged: (val) => _onOtpChanged(val, i),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Resend Code
          GestureDetector(
            onTap: () {
              // resend code logic
            },
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

          // Verify Email button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                // verify OTP logic
                Navigator.pop(context);
              },
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
// Registration Success Modal
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
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Vendo bag illustration with green checkmark + decorative dots
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Decorative scattered shapes
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

                // Big Vendo bag
                SizedBox(
                  width: 140,
                  height: 155,
                  child: CustomPaint(painter: _SuccessBagPainter()),
                ),

                // Green checkmark badge
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

          // Title
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

          // Subtitle bold
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

          // Description
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

          // Back to Login button
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

// ─────────────────────────────────────────────────────────────────────────────
// Success Bag Painter — large colored vendo bag for the success modal
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessBagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void drawBag(
      double l,
      double r,
      double t,
      double b,
      Color color,
      double radius,
    ) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(l + radius, t)
        ..lineTo(r - radius, t)
        ..quadraticBezierTo(r, t, r, t + radius)
        ..lineTo(r, b - radius)
        ..quadraticBezierTo(r, b, r - radius, b)
        ..lineTo(l + radius, b)
        ..quadraticBezierTo(l, b, l, b - radius)
        ..lineTo(l, t + radius)
        ..quadraticBezierTo(l, t, l + radius, t)
        ..close();
      canvas.drawPath(path, paint);
    }

    // Tan/yellow back layer
    drawBag(w * 0.22, w * 1.0, h * 0.30, h * 1.0, const Color(0xFFE8C97A), 14);
    // Brown/orange middle layer
    drawBag(
      w * 0.12,
      w * 0.90,
      h * 0.30,
      h * 0.96,
      const Color(0xFFC0663A),
      14,
    );
    // Dark purple main bag
    drawBag(
      w * 0.02,
      w * 0.78,
      h * 0.30,
      h * 0.92,
      const Color(0xFF2D1B3D),
      14,
    );

    // Handle
    final cx = (w * 0.02 + w * 0.78) / 2;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * 0.30),
        width: (w * 0.78 - w * 0.02) * 0.44,
        height: h * 0.26,
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

    // Eyes
    final eyeY = h * 0.30 + (h * 0.92 - h * 0.30) * 0.22;
    final eyePaint = Paint()
      ..color = const Color(0xFFE8873A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(cx - (w * 0.78 - w * 0.02) * 0.18, eyeY),
      5,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(cx + (w * 0.78 - w * 0.02) * 0.18, eyeY),
      5,
      eyePaint,
    );

    // "V" letter
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
    tp.paint(canvas, Offset(cx - tp.width / 2, h * 0.44));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Source Tile
// ─────────────────────────────────────────────────────────────────────────────
class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImageSourceTile({
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
