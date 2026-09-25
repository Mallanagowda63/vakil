import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../services/realtime_service.dart';

/// The advocate's profile: the details given at registration (name, email,
/// DOB, gender, Bar Council number, practice area, city, court, languages)
/// plus photo and bio, loaded from the server after sign-in. The name and
/// photo are what clients see on the lawyer list, requests and chats.
class ProfileController extends ChangeNotifier {
  ProfileController() {
    // Loads after every sign-in / reconnect; clears on sign-out.
    RealtimeService.instance.connected.addListener(_onConnection);
    _onConnection();
  }

  final _service = PartnerConsultationService();
  bool loaded = false;
  bool loading = false;
  String? error;

  /// A photo just picked, shown until the upload finishes.
  File? photo;
  String? photoUrl;
  String name = '';
  String email = '';
  String phone = '';
  String gender = '';
  String dateOfBirth = '';
  String barCouncilRegNo = '';
  String practiceArea = '';
  String location = '';
  String court = '';
  String languages = '';
  String bio = '';
  List<String> categories = const [];
  String verificationStatus = '';

  String get title => 'Advocate';
  String get specialization => categories.isEmpty ? practiceArea : categories.join(', ');

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  String get locationCity => location.split(',').first.trim();

  /// The picked file while uploading, else the saved photo, else null (show initials).
  ImageProvider? get avatarImage {
    if (photo != null) return FileImage(photo!);
    final url = ApiConfig.mediaUrl(photoUrl);
    return url == null ? null : NetworkImage(url);
  }

  void _onConnection() {
    if (PartnerAuthService.instance.token == null) {
      if (loaded) _reset();
    } else if (RealtimeService.instance.connected.value && !loading) {
      load();
    }
  }

  void _reset() {
    loaded = false;
    photo = null;
    photoUrl = null;
    name = email = phone = gender = dateOfBirth = barCouncilRegNo = practiceArea = location = court = languages = bio = verificationStatus = '';
    categories = const [];
    notifyListeners();
  }

  void _apply(Map<String, dynamic> p) {
    photoUrl = p['photoUrl'] as String?;
    name = p['fullName']?.toString() ?? '';
    email = p['email']?.toString() ?? '';
    phone = p['phone']?.toString() ?? '';
    gender = p['gender']?.toString() ?? '';
    dateOfBirth = p['dateOfBirth']?.toString() ?? '';
    barCouncilRegNo = p['barCouncilRegNo']?.toString() ?? '';
    practiceArea = p['practiceArea']?.toString() ?? '';
    location = p['city']?.toString() ?? '';
    court = p['court']?.toString() ?? '';
    languages = p['languages']?.toString() ?? '';
    bio = p['bio']?.toString() ?? '';
    categories = (p['categories'] as List? ?? const []).map((c) => c.toString()).toList();
    verificationStatus = p['verificationStatus']?.toString() ?? '';
    loaded = true;
    error = null;
  }

  Future<void> load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    loading = true;
    try {
      _apply(await _service.profile(token));
    } on PartnerNetworkException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Saves one or more fields (fullName, email, gender, bio, city, languages).
  /// Throws [PartnerNetworkException] with the server's message on failure.
  Future<void> update(Map<String, String> fields) async {
    final token = PartnerAuthService.instance.token;
    if (token == null) throw const PartnerNetworkException('Please sign in again');
    _apply(await _service.updateProfile(token, fields));
    notifyListeners();
  }

  Future<void> uploadPhoto(XFile image) async {
    final token = PartnerAuthService.instance.token;
    if (token == null) throw const PartnerNetworkException('Please sign in again');
    photo = File(image.path);
    notifyListeners();
    try {
      final lower = image.name.toLowerCase();
      final type = lower.endsWith('.png') ? 'image/png' : lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
      _apply(await _service.uploadPhoto(token, base64Encode(await image.readAsBytes()), type));
    } finally {
      photo = null;
      notifyListeners();
    }
  }

  Future<void> removePhoto() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    _apply(await _service.removePhoto(token));
    notifyListeners();
  }

  @override
  void dispose() {
    RealtimeService.instance.connected.removeListener(_onConnection);
    super.dispose();
  }
}
