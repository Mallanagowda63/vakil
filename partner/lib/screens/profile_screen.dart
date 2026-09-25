import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/profile_data.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import 'feedback_screen.dart';
import 'settings_screen.dart';

/// The lawyer's registration details and photo, saved on the server. The
/// name and photo are what clients see; Bar Council number, date of birth
/// and practice area are verified by the admin and can't be changed here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.read<ProfileController>().load(); });
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickPhoto() async {
    final profile = context.read<ProfileController>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheetContext, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheetContext, 'gallery')),
          if (profile.photoUrl != null)
            ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.danger), title: const Text('Remove photo', style: TextStyle(color: AppColors.danger)), onTap: () => Navigator.pop(sheetContext, 'remove')),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      if (choice == 'remove') {
        await profile.removePhoto();
      } else {
        final img = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
        if (img == null) return;
        await profile.uploadPhoto(img);
        if (mounted) _snack('Profile photo updated — clients will see it');
      }
    } on PartnerNetworkException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Could not open the camera or gallery. Check the app permissions.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Edits one field and saves it to the server.
  Future<void> _edit({required String title, required String field, required String initialValue, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) async {
    final ctrl = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: keyboardType, maxLines: maxLines, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result == initialValue || !mounted) return;
    try {
      await context.read<ProfileController>().update({field: result});
      if (mounted) _snack('$title saved');
    } on PartnerNetworkException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final avatar = profile.avatarImage;
    final verified = profile.verificationStatus == 'approved';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: profile.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (Navigator.of(context).canPop()) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Your registration details and photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    ]),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
                ]),
                if (profile.loading && !profile.loaded) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                if (profile.error != null && !profile.loaded)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Expanded(child: Text(profile.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))), TextButton(onPressed: profile.load, child: const Text('Retry'))])),
                const SizedBox(height: 18),
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      GestureDetector(
                        onTap: _uploading ? null : _pickPhoto,
                        onLongPress: profile.photoUrl == null ? null : () => _showPhoto(context, profile.photoUrl!),
                        child: Stack(children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: AppColors.infoBg,
                            foregroundImage: avatar,
                            onForegroundImageError: avatar == null ? null : (_, __) {},
                            child: Text(profile.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 20)),
                          ),
                          if (_uploading) const Positioned.fill(child: CircularProgressIndicator()),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(color: AppColors.primaryDark, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(profile.name.isEmpty ? 'Your name' : 'Adv. ${profile.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                            if (verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 16, color: AppColors.success)),
                          ]),
                          const SizedBox(height: 2),
                          Text([if (profile.practiceArea.isNotEmpty) profile.practiceArea, if (profile.locationCity.isNotEmpty) profile.locationCity].join(' • '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                          const SizedBox(height: 8),
                          _statusChip(profile.verificationStatus),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Text(profile.bio.isEmpty ? 'Add a short bio — clients see it on your profile.' : profile.bio, style: TextStyle(fontSize: 13, height: 1.5, color: profile.bio.isEmpty ? AppColors.textSecondary : null)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 10, runSpacing: 8, children: [
                      _pill(Icons.photo_camera_outlined, profile.photoUrl == null ? 'Add photo' : 'Change photo', _uploading ? null : _pickPhoto),
                      _pill(Icons.edit_outlined, 'Edit bio', () => _edit(title: 'Bio', field: 'bio', initialValue: profile.bio, maxLines: 4)),
                      _pill(Icons.star_outline_rounded, 'Feedback', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackScreen()))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 22),
                const Text('Personal details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                _detailRow(icon: Icons.person_outline, label: 'Full name (shown to clients)', value: profile.name, onEdit: () => _edit(title: 'Full name', field: 'fullName', initialValue: profile.name)),
                _detailRow(icon: Icons.phone_outlined, label: 'Mobile (sign-in number)', value: profile.phone),
                _detailRow(icon: Icons.email_outlined, label: 'Email', value: profile.email, onEdit: () => _edit(title: 'Email', field: 'email', initialValue: profile.email, keyboardType: TextInputType.emailAddress)),
                _detailRow(icon: Icons.wc_outlined, label: 'Gender', value: profile.gender, onEdit: () => _edit(title: 'Gender', field: 'gender', initialValue: profile.gender)),
                _detailRow(icon: Icons.cake_outlined, label: 'Date of birth', value: profile.dateOfBirth),
                const SizedBox(height: 22),
                const Text('Practice details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                _detailRow(icon: Icons.badge_outlined, label: 'Bar Council registration no.', value: profile.barCouncilRegNo),
                _detailRow(icon: Icons.business_center_outlined, label: 'Practice areas', value: profile.specialization),
                _detailRow(icon: Icons.account_balance_outlined, label: 'Primary court', value: profile.court),
                _detailRow(icon: Icons.location_on_outlined, label: 'City', value: profile.location, onEdit: () => _edit(title: 'City', field: 'city', initialValue: profile.location)),
                _detailRow(icon: Icons.language_outlined, label: 'Languages', value: profile.languages, onEdit: () => _edit(title: 'Languages', field: 'languages', initialValue: profile.languages)),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Bar Council number, date of birth, court and practice areas are verified by the Vakil team. Contact support to change them.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showPhoto(BuildContext context, String photoUrl) {
    final url = ApiConfig.mediaUrl(photoUrl);
    if (url == null) return;
    showDialog(context: context, builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(onTap: () => Navigator.pop(dialogContext), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)))),
    ));
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'approved' => ('Verified', AppColors.success),
      'under_review' => ('Under review', const Color(0xFFB5751B)),
      _ => ('Not verified yet', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: .5))),
      child: Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback? onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      );

  Widget _detailRow({required IconData icon, required String label, required String value, VoidCallback? onEdit}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: const BoxDecoration(color: AppColors.infoBg, shape: BoxShape.circle), child: Icon(icon, size: 16, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value.isEmpty ? 'Not added' : value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: value.isEmpty ? AppColors.textSecondary : null)),
          ]),
        ),
        if (onEdit != null)
          TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 14), label: const Text('Edit', style: TextStyle(fontSize: 12.5)), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)))
        else
          const Icon(Icons.lock_outline, size: 15, color: AppColors.textSecondary),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: child,
      );
}
