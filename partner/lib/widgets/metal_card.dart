import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/profile_data.dart';
import '../services/partner_auth_service.dart';
import 'lt_ui.dart';

/// The brushed-metal partner card (Home and Profile). Stays metal in both
/// themes. Drag across it to tilt; tap the photo to change it. Everything on
/// it comes from the lawyer's profile.
class MetalCard extends StatefulWidget {
  const MetalCard({super.key, required this.online});
  final bool online;
  @override
  State<MetalCard> createState() => _MetalCardState();
}

class _MetalCardState extends State<MetalCard> {
  double _rx = 0.14, _ry = -0.17, _shine = 0.5;
  bool _dragging = false;

  void _move(Offset local, Size size) {
    final x = (local.dx / size.width).clamp(0.0, 1.0), y = (local.dy / size.height).clamp(0.0, 1.0);
    setState(() { _dragging = true; _ry = (x - 0.5) * 0.45; _rx = (0.5 - y) * 0.35; _shine = x; });
  }

  void _reset() => setState(() { _dragging = false; _rx = 0.14; _ry = -0.17; _shine = 0.5; });

  Future<void> _pickPhoto(ProfileController profile) async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
      ])),
    );
    if (choice == null) return;
    final image = await ImagePicker().pickImage(source: choice, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (image == null) return;
    try {
      await profile.uploadPhoto(image);
      if (mounted) toast(context, 'Profile photo updated');
    } on PartnerNetworkException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProfileController>();
    const ink = Color(0xFF363C3E);
    final emb = [const Shadow(color: Color(0xBFFFFFFF), offset: Offset(0, 1)), const Shadow(color: Color(0x47000000), offset: Offset(0, -1))];
    TextStyle t(double size, {FontWeight w = FontWeight.w500, double ls = 0}) => TextStyle(fontSize: size, fontWeight: w, color: ink, letterSpacing: ls, shadows: emb);
    final areas = p.categories.isNotEmpty ? p.categories.take(3).join(', ') : p.practiceArea;
    final verified = p.barCouncilVerified || p.verificationStatus == 'approved';

    return Column(children: [
      LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, box.maxWidth / 1.586);
        return GestureDetector(
          onPanDown: (d) => _move(d.localPosition, size),
          onPanUpdate: (d) => _move(d.localPosition, size),
          onPanEnd: (_) => _reset(),
          onPanCancel: _reset,
          child: AnimatedContainer(
            duration: Duration(milliseconds: _dragging ? 60 : 500),
            curve: Curves.easeOutCubic,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateX(_rx)..rotateY(_ry),
            width: size.width,
            height: size.height,
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFFA4A8AA), Color(0xFFD6D8D9), Color(0xFFEEEFEF), Color(0xFFCDD0D1), Color(0xFF9A9EA0)], stops: [0, .2, .46, .7, 1]),
              boxShadow: const [BoxShadow(color: Color(0x40081816), blurRadius: 18, offset: Offset(0, 12))],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              // Light sweep that follows the finger, like brushed metal.
              gradient: LinearGradient(
                begin: const Alignment(-1, -0.3), end: const Alignment(1, 0.3),
                colors: [Colors.transparent, Colors.white.withValues(alpha: 0.55), Colors.transparent],
                stops: [math.max(0, _shine - 0.22), _shine, math.min(1, _shine + 0.2)],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('LEGALLY TALK', style: sora(13, weight: FontWeight.w700, color: ink, letterSpacing: 2.6).copyWith(shadows: emb)),
                  Text('ADVOCATE PARTNER', style: t(8.5, w: FontWeight.w600, ls: 2.7)),
                ]),
                const Spacer(),
                if (verified) const Row(children: [
                  Icon(Icons.verified, size: 17, color: Color(0xFF0E4D45)),
                  SizedBox(width: 4),
                  Text('BAR VERIFIED', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Color(0xFF0E4D45))),
                ]),
              ]),
              const Spacer(),
              Row(children: [
                GestureDetector(
                  onTap: () => _pickPhoto(p),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFF7F8F8), Color(0xFF8F9496), Color(0xFFE3E5E6)]), boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))]),
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFFCFD8D6),
                        backgroundImage: p.avatarImage,
                        child: p.avatarImage == null ? Text(Initials.of(p.name), style: sora(18, weight: FontWeight.w700, color: const Color(0xFF1F2B2A))) : null,
                      ),
                    ),
                    Positioned(right: -2, bottom: -2, child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: const Color(0xFF0E4D45), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE6E8E8), width: 2)),
                      child: const Icon(Icons.photo_camera, size: 11, color: Colors.white),
                    )),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ADV. ${p.name.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sora(13.5, color: ink, letterSpacing: 0.8).copyWith(shadows: emb)),
                  if (areas.isNotEmpty) Text('Advocate · $areas', maxLines: 1, overflow: TextOverflow.ellipsis, style: t(10.5)),
                  if (p.barCouncilRegNo.isNotEmpty) Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text.rich(TextSpan(children: [TextSpan(text: 'ENROL. ', style: t(8.5, ls: 1.2)), TextSpan(text: p.barCouncilRegNo, style: mono(11, color: ink))])),
                  ),
                ])),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.online ? const Color(0xFF1F8A5B) : const Color(0xFF7A8082))),
                  const SizedBox(width: 5),
                  Text(widget.online ? 'ONLINE' : 'OFFLINE', style: t(9, w: FontWeight.w700, ls: 1.2)),
                ]),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.only(top: 7),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1F000000)))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (p.address.isNotEmpty || p.court.isNotEmpty) _line(Icons.place_outlined, p.address.isNotEmpty ? p.address : p.court, t(10)),
                  if (p.phone.isNotEmpty) _line(Icons.phone_outlined, p.phone, t(10)),
                  if (p.email.isNotEmpty) _line(Icons.mail_outline, p.email, t(10)),
                ]),
              ),
            ]),
          ),
        );
      }),
      Container(height: 18, margin: const EdgeInsets.fromLTRB(26, 2, 26, 0), decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: RadialGradient(colors: [const Color(0xFF081816).withValues(alpha: 0.25), Colors.transparent]))),
      Text('Tap the photo to change it', style: TextStyle(fontSize: 11.5, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93A4A0) : const Color(0xFF5D6B68))),
    ]);
  }

  Widget _line(IconData icon, String text, TextStyle style) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [Icon(icon, size: 11, color: const Color(0xFF363C3E)), const SizedBox(width: 6), Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style))]),
      );
}
