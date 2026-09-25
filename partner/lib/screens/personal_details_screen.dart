import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/registration_data.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import 'face_verification_screen.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _dobCtrl;
  File? _photo;
  String? _gender;

  static const _genderOptions = ['Male', 'Female', 'Trans', 'Non-binary', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    final data = context.read<RegistrationData>();
    _nameCtrl = TextEditingController(text: data.fullName);
    _mobileCtrl = TextEditingController(text: data.mobileNumber);
    _emailCtrl = TextEditingController(text: data.email);
    _dobCtrl = TextEditingController(text: data.formattedDob);
    _photo = data.profilePhoto;
    _gender = data.gender.isEmpty ? null : data.gender;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (img != null) setState(() => _photo = File(img.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (img != null) setState(() => _photo = File(img.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Select date of birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _dobCtrl.text = '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
      context.read<RegistrationData>().dateOfBirth = picked;
    }
  }

  void _next() {
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gender')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final data = context.read<RegistrationData>();
    data.savePersonalDetails(
      photo: _photo,
      fullName: _nameCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      dob: data.dateOfBirth,
      gender: _gender!,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FaceVerificationScreen()),
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
              step: 1,
              totalSteps: 5,
              title: 'Personal Details',
              subtitle: 'Help patients identify you when you arrive at the scene.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: const Color(0xFFE9ECF3),
                                backgroundImage: _photo != null ? FileImage(_photo!) : null,
                                child: _photo == null
                                    ? const Icon(Icons.person_outline, size: 40, color: AppColors.textSecondary)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickPhoto,
                              icon: const Icon(Icons.upload_outlined, size: 16),
                              label: const Text('Upload Profile Photo'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      LabeledTextField(
                        label: 'Full Name (as per documents)',
                        required: true,
                        controller: _nameCtrl,
                        hint: 'e.g. John Doe',
                        textCapitalization: TextCapitalization.words,
                        prefixIcon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                      ),
                      LabeledTextField(
                        label: 'Mobile Number',
                        required: true,
                        controller: _mobileCtrl,
                        hint: 'e.g. +1 234 567 890',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                          if (v.trim().length < 7) return 'Enter a valid mobile number';
                          return null;
                        },
                      ),
                      LabeledTextField(
                        label: 'Email Address',
                        required: true,
                        controller: _emailCtrl,
                        hint: 'e.g. john.doe@email.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          final ok = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v.trim());
                          return ok ? null : 'Enter a valid email address';
                        },
                      ),
                      LabeledTextField(
                        label: 'Date of Birth',
                        required: true,
                        controller: _dobCtrl,
                        hint: 'DD/MM/YYYY',
                        readOnly: true,
                        onTap: _pickDob,
                        prefixIcon: Icons.calendar_today_outlined,
                        validator: (v) => (v == null || v.isEmpty) ? 'Date of birth is required' : null,
                      ),
                      const Text(
                        'Gender',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _genderOptions.map((g) {
                          final selected = _gender == g;
                          return ChoiceChip(
                            label: Text(g),
                            selected: selected,
                            onSelected: (_) => setState(() => _gender = g),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.card,
                            side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(label: 'Next', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}
