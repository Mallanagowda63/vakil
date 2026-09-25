import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/registration_data.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import '../widgets/upload_dropzone.dart';
import 'bank_upi_screen.dart';

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
