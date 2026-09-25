import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/photo_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';
import 'legal_help_start_screen.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key, this.phoneNumber});

  final String? phoneNumber;

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  late final _nameController = TextEditingController();
  late final _languageController = TextEditingController();
  late final _phoneController =
      TextEditingController(text: widget.phoneNumber ?? '');
  late final _aadhaarController = TextEditingController();
  late final _emailController = TextEditingController();
  late final _sosNameController = TextEditingController();

  String? _gender;
  /// Optional; uploaded right after the profile is saved.
  XFile? _photo;
  bool _phoneLocked = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _languageController.dispose();
    _phoneController.dispose();
    _aadhaarController.dispose();
    _emailController.dispose();
    _sosNameController.dispose();
    super.dispose();
  }

  bool get _aadhaarValid =>
      _aadhaarController.text.replaceAll(' ', '').length == 12;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Enter your full legal name');
      return;
    }
    if (_gender == null) {
      _showSnack('Select your gender');
      return;
    }
    if (!_aadhaarValid) {
      _showSnack('Enter a valid 12-digit Aadhaar number');
      return;
    }
    if (!_emailController.text.contains('@')) {
      _showSnack('Enter a valid email address');
      return;
    }

    setState(() => _saving = true);
    try {
      await AuthService.instance.saveProfile(
        fullName: _nameController.text.trim(),
        language: _languageController.text.trim(),
        gender: _gender!,
        aadhaar: _aadhaarController.text.trim(),
        email: _emailController.text.trim(),
        sosContact: _sosNameController.text.trim(),
      );
      final photo = _photo;
      if (photo != null) {
        try { await ProfileService.instance.uploadPhoto(photo); } catch (_) { _showSnack('Profile saved. The photo could not be uploaded; add it from the Profile tab.'); }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LegalHelpStartScreen()),
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Could not reach the server. Is the backend running?');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await pickProfilePhoto(context, onRemove: _photo == null ? null : () => setState(() => _photo = null));
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textDark),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Create Profile',
                        style: AppText.h3(AppColors.textDark)),
                  ),
                  Icon(Icons.help_outline,
                      size: 20, color: AppColors.textGray),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  'Your legal identity card. Crucial during state/police\ninteractions.',
                  style: AppText.bodySmall(AppColors.textGray),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.lightSurface,
                        foregroundImage: _photo == null ? null : FileImage(File(_photo!.path)),
                        child: Icon(Icons.person,
                            size: 34, color: AppColors.textGraySoft),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.textDark,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(_photo == null ? 'Add Profile Photo' : 'Change Profile Photo',
                    style: AppText.bodyMedium(AppColors.textDark)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Crucial for verification at police checkpoints',
                  style: AppText.bodySmall(AppColors.textGray),
                ),
              ),
              const SizedBox(height: 26),
              FieldLabel('FULL LEGAL NAME (As per Aadhar/PAN)'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.person_outline,
                controller: _nameController,
                hint: 'Enter your full legal name',
              ),
              const SizedBox(height: 18),
              FieldLabel('PRIMARY LANGUAGE'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.language,
                controller: _languageController,
                hint: 'e.g. Hindi, English, Tamil',
              ),
              const SizedBox(height: 18),
              FieldLabel('PHONE NUMBER'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.phone_outlined,
                controller: _phoneController,
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone,
                readOnly: _phoneLocked,
                trailing: EditLink(
                  onTap: () => setState(() => _phoneLocked = !_phoneLocked),
                ),
              ),
              const SizedBox(height: 26),
              Text('PROFILE REQUIREMENTS',
                  style: AppText.h3(AppColors.textDark)),
              const SizedBox(height: 16),
              FieldLabel('GENDER'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _GenderChip(
                      label: 'Male',
                      selected: _gender == 'Male',
                      onTap: () => setState(() => _gender = 'Male'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderChip(
                      label: 'Female',
                      selected: _gender == 'Female',
                      onTap: () => setState(() => _gender = 'Female'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderChip(
                      label: 'Other',
                      selected: _gender == 'Other',
                      onTap: () => setState(() => _gender = 'Other'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FieldLabel('AADHAAR CARD NUMBER'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.badge_outlined,
                controller: _aadhaarController,
                hint: 'XXXX XXXX XXXX',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                trailing: _aadhaarValid
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 15, color: AppColors.greenAccent),
                          const SizedBox(width: 4),
                          Text('Verified',
                              style: AppText.bodySmall(AppColors.greenAccent)
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ],
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              FieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.mail_outline,
                controller: _emailController,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: AppColors.redAccent),
                        const SizedBox(width: 6),
                        Text('SOS Emergency Contacts',
                            style: AppText.bodyMedium(AppColors.redAccent)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These contacts will instantly receive your live GPS '
                      'coordinate track when you activate the SOS alarm.',
                      style: AppText.bodySmall(AppColors.textGray),
                    ),
                    const SizedBox(height: 14),
                    FieldLabel('CONTACT 1 (e.g. Spouse/Parent)',
                        color: AppColors.textGray),
                    const SizedBox(height: 8),
                    EditableField(
                      icon: Icons.phone_outlined,
                      controller: _sosNameController,
                      hint: 'Name (Relation) — +91 XXXXX XXXXX',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SolidButton(
                label: _saving ? 'Saving…' : 'Save Legal Identity',
                background: Colors.black,
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.textDark : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.textDark : AppColors.lightStroke,
          ),
        ),
        child: Text(
          label,
          style: AppText.bodyMedium(selected ? Colors.white : AppColors.textDark),
        ),
      ),
    );
  }
}
