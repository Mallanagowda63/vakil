import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// The signed-in client's details from registration, as the Profile tab shows them.
class UserProfile {
  const UserProfile({this.fullName = '', this.phone = '', this.email = '', this.gender = '', this.language = '', this.aadhaar = '', this.sosContact = '', this.photoUrl});
  final String fullName;
  final String phone;
  final String email;
  final String gender;
  final String language;
  final String aadhaar;
  final String sosContact;
  final String? photoUrl;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['fullName']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        gender: json['gender']?.toString() ?? '',
        language: json['language']?.toString() ?? '',
        aadhaar: json['aadhaar']?.toString() ?? '',
        sosContact: json['sosContact']?.toString() ?? '',
        photoUrl: json['photoUrl'] as String?,
      );
}

/// One rating given after a chat or call. [other] is the lawyer.
class FeedbackEntry {
  const FeedbackEntry({required this.requestId, required this.rating, required this.comment, required this.otherName, this.otherPhotoUrl, this.isCall = false, this.category, this.createdAt});
  final String requestId;
  final int rating;
  final String comment;
  final String otherName;
  final String? otherPhotoUrl;
  final bool isCall;
  final String? category;
  final DateTime? createdAt;

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) {
    final other = Map<String, dynamic>.from(json['other'] as Map? ?? const {});
    return FeedbackEntry(
      requestId: json['requestId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString() ?? '',
      otherName: other['name']?.toString() ?? 'Lawyer',
      otherPhotoUrl: other['photoUrl'] as String?,
      isCall: json['consultationType'] == 'call',
      category: json['category']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// A client's review on a lawyer's profile (first name only).
class LawyerReview {
  const LawyerReview({required this.clientName, required this.rating, required this.comment, this.clientPhotoUrl, this.isCall = false, this.createdAt});
  final String clientName;
  final int rating;
  final String comment;
  final String? clientPhotoUrl;
  final bool isCall;
  final DateTime? createdAt;

  factory LawyerReview.fromJson(Map<String, dynamic> json) => LawyerReview(
        clientName: json['clientName']?.toString() ?? 'Client',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        comment: json['comment']?.toString() ?? '',
        clientPhotoUrl: json['clientPhotoUrl'] as String?,
        isCall: json['consultationType'] == 'call',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

/// Profile details, the profile photo and feedback (GET/PATCH /api/profile, /api/feedback).
class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();
  final _api = ApiClient();
  String? get _token => AuthService.instance.token;

  /// The latest profile; screens (home avatar, Profile tab) rebuild when it changes.
  final profile = ValueNotifier<UserProfile?>(null);

  Future<UserProfile> load() async {
    final data = await _api.get('/api/profile', token: _token);
    return profile.value = UserProfile.fromJson(Map<String, dynamic>.from(data['profile'] as Map));
  }

  /// Saves the fields given; the name also changes on the lawyer's side.
  Future<UserProfile> update(Map<String, String> fields) async {
    final data = await _api.patch('/api/profile', fields, token: _token);
    return profile.value = UserProfile.fromJson(Map<String, dynamic>.from(data['profile'] as Map));
  }

  /// Uploads [image] as the new profile photo (lawyers see it on requests and chats).
  Future<UserProfile> uploadPhoto(XFile image) async {
    final bytes = await image.readAsBytes();
    final name = image.name.toLowerCase();
    final type = name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
    final data = await _api.post('/api/profile/photo', {'image': base64Encode(bytes), 'contentType': type}, token: _token);
    return profile.value = UserProfile.fromJson(Map<String, dynamic>.from(data['profile'] as Map));
  }

  Future<UserProfile> removePhoto() async {
    final data = await _api.delete('/api/profile/photo', token: _token);
    return profile.value = UserProfile.fromJson(Map<String, dynamic>.from(data['profile'] as Map));
  }

  /// Ratings I gave lawyers and the feedback lawyers gave me.
  Future<({List<FeedbackEntry> given, List<FeedbackEntry> received})> feedback() async {
    final data = await _api.get('/api/feedback', token: _token);
    List<FeedbackEntry> parse(Object? list) => (list as List? ?? const []).map((e) => FeedbackEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return (given: parse(data['given']), received: parse(data['received']));
  }

  Future<({List<LawyerReview> items, double? average, int count})> lawyerReviews(String lawyerId) async {
    final data = await _api.get('/api/feedback/lawyers/$lawyerId', token: _token);
    final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? const {});
    return (
      items: (data['items'] as List? ?? const []).map((e) => LawyerReview.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      average: (stats['average'] as num?)?.toDouble(),
      count: (stats['count'] as num?)?.toInt() ?? 0,
    );
  }

  void clear() => profile.value = null;
}
