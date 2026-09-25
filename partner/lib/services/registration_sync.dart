import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/registration_data.dart';
import 'consultation_service.dart';
import 'partner_auth_service.dart';

/// Sends the partner registration (personal, advocate and bank details) to
/// the server for the Admin Panel's verification. Registration happens before
/// sign-in, so it is kept on the phone and sent right after the next sign-in.
class RegistrationSync {
  RegistrationSync._();
  static const _key = 'pending_partner_registration';

  static Map<String, dynamic> toJson(RegistrationData d) => {
        'personal': {'fullName': d.fullName, 'email': d.email, 'dateOfBirth': d.dateOfBirth?.toIso8601String().substring(0, 10) ?? '', 'gender': d.gender, 'faceVerified': d.faceVerified, 'mobile': d.mobileNumber},
        'advocate': {'barCouncilRegNo': d.barCouncilRegNo, 'practiceArea': d.primaryPracticeArea, 'city': d.city, 'court': d.primaryCourt, 'languages': d.languagesSpoken, 'licenseFileName': d.advocateLicenseFile?.name ?? ''},
        'bank': {'holderName': d.bankAccountHolderName, 'ifsc': d.ifscCode, 'accountNumber': d.bankAccountNumber, 'upi': d.upiId},
      };

  /// Sends now when signed in, otherwise keeps it for [flush] after sign-in.
  static Future<void> submit(RegistrationData data) async {
    final body = toJson(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(body));
    final token = PartnerAuthService.instance.token;
    if (token != null) await flush(token);
  }

  /// Called after sign-in; sends a waiting registration once.
  static Future<void> flush(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == null) return;
      await PartnerConsultationService().submitRegistration(token, Map<String, dynamic>.from(jsonDecode(saved) as Map));
      await prefs.remove(_key);
    } on PartnerNetworkException catch (error) {
      // 409: filled in for another mobile number; 400: incomplete. Don't retry those.
      if (error.statusCode == 409 || error.statusCode == 400) await (await SharedPreferences.getInstance()).remove(_key);
      debugPrint('Registration not sent: ${error.message}');
    } catch (error) {
      debugPrint('Registration not sent yet: $error');
    }
  }
}
