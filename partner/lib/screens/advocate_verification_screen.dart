import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/registration_data.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import '../widgets/upload_dropzone.dart';
import 'bank_upi_screen.dart';
import '../widgets/app_loader.dart';

class AdvocateVerificationScreen extends StatefulWidget {
  const AdvocateVerificationScreen({super.key});

  @override
  State<AdvocateVerificationScreen> createState() => _AdvocateVerificationScreenState();
}

class _AdvocateVerificationScreenState extends State<AdvocateVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barCouncilCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _courtCtrl;
  late final TextEditingController _languagesCtrl;
  String? _practiceArea;
  PlatformFile? _licenseFile;
  bool _sendingCode = false;
  late int _price = context.read<RegistrationData>().pricePer10Minutes;

  RegistrationData get _data => context.read<RegistrationData>();
  bool get _barVerified => _data.isBarNumberVerified(_barCouncilCtrl.text);
  String get _email => _data.email.trim().isNotEmpty ? _data.email.trim() : (PartnerAuthService.instance.email ?? '');

  /// "Verify": emails a code for this number, then asks for it.
  Future<void> _verifyBarNumber() async {
    final number = _barCouncilCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (number.length < 3) { messenger.showSnackBar(const SnackBar(content: Text('Enter your Bar Council registration number first'))); return; }
    if (_email.isEmpty) { messenger.showSnackBar(const SnackBar(content: Text('Add your email in Personal Details first'))); return; }
    setState(() => _sendingCode = true);
    String? devCode;
    try {
      final res = await PartnerAuthService.instance.sendBarCode(_email, number);
      devCode = kDebugMode ? res['devCode']?.toString() : null;
    } on PartnerNetworkException catch (e) {
      if (mounted) { setState(() => _sendingCode = false); messenger.showSnackBar(SnackBar(content: Text(e.message))); }
      return;
    }
    if (!mounted) return;
    setState(() => _sendingCode = false);
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BarCodeDialog(email: _email, number: number, devCode: devCode),
    );
    if (verified == true && mounted) {
      _data.markBarNumberVerified(number);
      setState(() {});
      messenger.showSnackBar(const SnackBar(content: Text('Bar Council number verified')));
    }
  }

  /// Clients see this price and buy chat time at it. ₹100–₹500 for 10 minutes, in ₹10 steps.
  Widget _priceCard() {
    const min = RegistrationData.minPricePer10Minutes, max = RegistrationData.maxPricePer10Minutes;
    final perMinute = _price / 10;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCBDBFC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹$_price', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          const SizedBox(width: 6),
          const Padding(padding: EdgeInsets.only(bottom: 5), child: Text('for 10 minutes', style: TextStyle(fontSize: 13.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600))),
          const Spacer(),
          Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('₹${perMinute % 1 == 0 ? perMinute.toInt() : perMinute.toStringAsFixed(1)}/min', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        ]),
        Slider(
          value: _price.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ 10,
          label: '₹$_price',
          onChanged: (v) => setState(() => _price = v.round()),
        ),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('₹$min', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text('₹$max', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        const Text('Clients pay this for each 10 minutes of chat. A client's very first chat on Vakil is a free 1-minute trial. You can ask the Vakil team to change it later.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.35)),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _barSuffix() {
    if (_barVerified) {
      return const Padding(
        padding: EdgeInsets.only(right: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, color: AppColors.success, size: 18),
          SizedBox(width: 4),
          Text('Verified', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: _sendingCode
          ? const Padding(padding: EdgeInsets.all(12), child: DotsLoader(size: 6))
          : TextButton(onPressed: _verifyBarNumber, child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700))),
    );
  }

  static const _practiceAreas = [
    'Civil & Family Law',
    'Criminal Law',
    'Corporate Law',
    'Property Law',
    'Labour & Service Law',
    'Tax Law',
    'Constitutional Law',
    'Consumer Protection',
    'Intellectual Property',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final data = context.read<RegistrationData>();
    _barCouncilCtrl = TextEditingController(text: data.barCouncilRegNo);
    _cityCtrl = TextEditingController(text: data.city);
    _courtCtrl = TextEditingController(text: data.primaryCourt);
    _languagesCtrl = TextEditingController(text: data.languagesSpoken);
    _practiceArea = data.primaryPracticeArea.isEmpty ? null : data.primaryPracticeArea;
    _licenseFile = data.advocateLicenseFile;
  }

  @override
  void dispose() {
    _barCouncilCtrl.dispose();
    _cityCtrl.dispose();
    _courtCtrl.dispose();
    _languagesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLicense() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (file == null) return;
    const maxBytes = 5 * 1024 * 1024;
    final size = await file.length() ?? 0;
    if (!mounted) return;
    if (size > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File must be 5MB or smaller')),
      );
      return;
    }
    setState(() => _licenseFile = file);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_barVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap Verify next to your Bar Council number and enter the code we email you')),
      );
      return;
    }
    if (_practiceArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your primary practice area')),
      );
      return;
    }
    if (_licenseFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your advocate license')),
      );
      return;
    }

    context.read<RegistrationData>().savePrice(_price);
    context.read<RegistrationData>().saveAdvocateDetails(
          barCouncilRegNo: _barCouncilCtrl.text.trim(),
          primaryPracticeArea: _practiceArea!,
          city: _cityCtrl.text.trim(),
          primaryCourt: _courtCtrl.text.trim(),
          languagesSpoken: _languagesCtrl.text.trim(),
          licenseFile: _licenseFile,
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BankUpiScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressHeader(
              step: 3,
              totalSteps: 5,
              title: 'Advocate Verification',
              subtitle: 'Please provide your professional credentials to verify your '
                  'identity and enable secure client payments.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(Icons.badge_outlined, 'Professional Credentials'),
                      const SizedBox(height: 4),
                      LabeledTextField(
                        label: 'Bar Council Registration No.',
                        required: true,
                        controller: _barCouncilCtrl,
                        hint: 'e.g. DL-12345/2023',
                        textCapitalization: TextCapitalization.characters,
                        suffixIcon: _barSuffix(),
                        // Editing the number after verifying it needs a new code.
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Registration number is required' : null,
                      ),
                      const Text('Primary Practice Area', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _practiceArea,
                        decoration: const InputDecoration(hintText: 'Select area of law'),
                        items: _practiceAreas
                            .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                            .toList(),
                        onChanged: (v) => setState(() => _practiceArea = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LabeledTextField(
                              label: 'City',
                              required: true,
                              controller: _cityCtrl,
                              hint: 'New Delhi',
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LabeledTextField(
                              label: 'Primary Court',
                              required: true,
                              controller: _courtCtrl,
                              hint: 'High Court',
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      LabeledTextField(
                        label: 'Languages Spoken',
                        required: true,
                        controller: _languagesCtrl,
                        hint: 'English, Hindi, etc.',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      _sectionLabel(Icons.currency_rupee, 'Your Consultation Price'),
                      const SizedBox(height: 4),
                      _priceCard(),
                      const SizedBox(height: 20),
                      _sectionLabel(Icons.verified_user_outlined, 'Identity & License'),
                      const SizedBox(height: 12),
                      UploadDropzone(
                        title: 'Upload Advocate License',
                        subtitle: 'PDF, JPG or PNG (Max 5MB)',
                        icon: Icons.cloud_upload_outlined,
                        fileName: _licenseFile?.name,
                        onTap: _pickLicense,
                        onRemove: () => setState(() => _licenseFile = null),
                      ),
                      const SizedBox(height: 20),
                      const Text.rich(
                        TextSpan(
                          text: 'By clicking submit, you agree to our ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          children: [
                            TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            TextSpan(text: ' and '),
                            TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            TextSpan(text: '.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(label: 'Submit for Verification', onPressed: _submit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}

/// Asks for the 6-digit code emailed for the Bar Council number. Pops true once verified.
class _BarCodeDialog extends StatefulWidget {
  const _BarCodeDialog({required this.email, required this.number, this.devCode});
  final String email;
  final String number;
  final String? devCode;

  @override
  State<_BarCodeDialog> createState() => _BarCodeDialogState();
}

class _BarCodeDialogState extends State<_BarCodeDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _checking = false;
  int _resendIn = 30;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _devCode = widget.devCode;
    _tick();
  }

  void _tick() => Future.delayed(const Duration(seconds: 1), () {
        if (!mounted || _resendIn == 0) return;
        setState(() => _resendIn--);
        _tick();
      });

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_code.text.trim().length != 6) { setState(() => _error = 'Enter the 6-digit code'); return; }
    setState(() { _checking = true; _error = null; });
    try {
      await PartnerAuthService.instance.checkBarCode(widget.email, widget.number, _code.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() { _checking = false; _error = e.message; });
    }
  }

  Future<void> _resend() async {
    setState(() { _error = null; _resendIn = 30; });
    _tick();
    try {
      final res = await PartnerAuthService.instance.sendBarCode(widget.email, widget.number);
      if (mounted) setState(() => _devCode = kDebugMode ? res['devCode']?.toString() : null);
    } on PartnerNetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Check your email'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4), children: [
          const TextSpan(text: 'We sent a code to '),
          TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const TextSpan(text: ' to verify Bar Council number '),
          TextSpan(text: widget.number, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const TextSpan(text: '.'),
        ])),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8),
          decoration: InputDecoration(counterText: '', hintText: '------', errorText: _error, border: const OutlineInputBorder()),
          onSubmitted: (_) => _check(),
        ),
        if (_devCode != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Test code: $_devCode', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _resendIn > 0 || _checking ? null : _resend, child: Text(_resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code')),
        ),
      ]),
      actions: [
        TextButton(onPressed: _checking ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _checking ? null : _check, child: Text(_checking ? 'Checking...' : 'Verify')),
      ],
    );
  }
}
