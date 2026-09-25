import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';
import '../widgets/photo_picker.dart';
import 'feedback_screen.dart';
import 'lawyer_profile_screen.dart';
import 'lawyers_screen.dart';
import 'login_otp_screen.dart';

/// The client's details from registration (name, language, phone, gender,
/// Aadhaar, email, emergency contact) and profile photo, all editable. The
/// name and photo are what lawyers see on requests and chats.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _service = ProfileService.instance;
  final _nameController = TextEditingController();
  final _languageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _emailController = TextEditingController();
  final _sosController = TextEditingController();

  String _gender = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = _service.profile.value;
    if (cached != null) _fill(cached);
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nameController, _languageController, _phoneController, _aadhaarController, _emailController, _sosController]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.load();
      if (mounted) setState(() { _fill(profile); _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(UserProfile p) {
    _nameController.text = p.fullName;
    _languageController.text = p.language;
    _phoneController.text = p.phone.isNotEmpty ? p.phone : AuthService.instance.phone ?? '';
    _aadhaarController.text = p.aadhaar;
    _emailController.text = p.email;
    _sosController.text = p.sosContact;
    _gender = p.gender;
  }

  bool get _aadhaarValid => _aadhaarController.text.replaceAll(' ', '').length == 12;

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return _snack('Enter your full legal name');
    if (_aadhaarController.text.trim().isNotEmpty && !_aadhaarValid) return _snack('Enter a valid 12-digit Aadhaar number');
    setState(() => _saving = true);
    try {
      final profile = await _service.update({
        'fullName': _nameController.text.trim(),
        'language': _languageController.text.trim(),
        'gender': _gender,
        'aadhaar': _aadhaarController.text.trim(),
        'email': _emailController.text.trim(),
        'sosContact': _sosController.text.trim(),
      });
      if (!mounted) return;
      setState(() => _fill(profile));
      _snack('Profile saved');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final hasPhoto = _service.profile.value?.photoUrl != null;
    final photo = await pickProfilePhoto(context, onRemove: hasPhoto ? _removePhoto : null);
    if (photo == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await _service.uploadPhoto(photo);
      if (mounted) _snack('Profile photo updated');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    try {
      await _service.removePhoto();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again with your mobile number to come back to your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('Cancel', style: AppText.bodyMedium(AppColors.textGray))),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('Log Out', style: AppText.bodyMedium(AppColors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginOtpScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Profile', textAlign: TextAlign.center, style: AppText.h3(AppColors.textDark)),
              if (_loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Expanded(child: Text(_error!, style: AppText.bodySmall(AppColors.redAccent))),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                ),
              const SizedBox(height: 18),
              ValueListenableBuilder<UserProfile?>(
                valueListenable: _service.profile,
                builder: (context, profile, _) => Column(children: [
                  GestureDetector(
                    onTap: _uploading ? null : _changePhoto,
                    onLongPress: profile?.photoUrl == null ? null : () => showPhoto(context, profile!.photoUrl!, profile.fullName),
                    child: Stack(children: [
                      LawyerAvatar(name: profile?.fullName ?? '', photoUrl: profile?.photoUrl, radius: 44),
                      if (_uploading) const Positioned.fill(child: CircularProgressIndicator()),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: AppColors.textDark, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Your name', style: AppText.h3(AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(profile?.photoUrl == null ? 'Tap the photo to add one — lawyers will see it' : 'Tap the photo to change it', style: AppText.caption(AppColors.textGray)),
                ]),
              ),
              const SizedBox(height: 16),
              OutlineButton(
                label: 'My Feedback & Ratings',
                leading: const Icon(Icons.star_outline_rounded, size: 18, color: AppColors.starGold),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen())),
              ),
              const SizedBox(height: 22),
              Text('REGISTRATION DETAILS', style: AppText.h3(AppColors.textDark)),
              const SizedBox(height: 14),
              FieldLabel('FULL LEGAL NAME (As per Aadhar/PAN)'),
              const SizedBox(height: 8),
              EditableField(icon: Icons.person_outline, controller: _nameController, hint: 'Enter your full legal name'),
              const SizedBox(height: 18),
              FieldLabel('LANGUAGE'),
              const SizedBox(height: 8),
              EditableField(icon: Icons.language, controller: _languageController, hint: 'e.g. Hindi, English, Tamil'),
              const SizedBox(height: 18),
              FieldLabel('PHONE NUMBER (sign-in number)'),
              const SizedBox(height: 8),
              EditableField(icon: Icons.phone_outlined, controller: _phoneController, hint: '+91', readOnly: true, trailing: const Icon(Icons.lock_outline, size: 16, color: AppColors.textGraySoft)),
              const SizedBox(height: 18),
              FieldLabel('GENDER'),
              const SizedBox(height: 8),
              Row(children: [
                for (final (i, g) in const ['Male', 'Female', 'Other'].indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _GenderChip(label: g, selected: _gender.toLowerCase() == g.toLowerCase(), onTap: () => setState(() => _gender = g))),
                ],
              ]),
              const SizedBox(height: 18),
              FieldLabel('AADHAAR CARD NUMBER'),
              const SizedBox(height: 8),
              EditableField(
                icon: Icons.badge_outlined,
                controller: _aadhaarController,
                hint: 'XXXX XXXX XXXX',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                trailing: _aadhaarValid ? const Icon(Icons.check_circle, size: 16, color: AppColors.greenAccent) : null,
              ),
              const SizedBox(height: 18),
              FieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 8),
              EditableField(icon: Icons.mail_outline, controller: _emailController, hint: 'name@example.com', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 18),
              FieldLabel('EMERGENCY (SOS) CONTACT'),
              const SizedBox(height: 8),
              EditableField(icon: Icons.emergency_outlined, controller: _sosController, hint: 'Name or phone number'),
              const SizedBox(height: 22),
              SolidButton(label: _saving ? 'Saving…' : 'Save Profile', background: Colors.black, onTap: _saving ? null : _save),
              const SizedBox(height: 12),
              OutlineButton(
                label: 'Log Out',
                foreground: AppColors.redAccent,
                borderColor: AppColors.redSoft,
                leading: Icon(Icons.logout, size: 16, color: AppColors.redAccent),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.label, required this.selected, required this.onTap});
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
          border: Border.all(color: selected ? AppColors.textDark : AppColors.lightStroke),
        ),
        child: Text(label, style: AppText.bodyMedium(selected ? Colors.white : AppColors.textDark)),
      ),
    );
  }
}
