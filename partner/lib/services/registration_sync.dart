import 'dart:convert';
import 'dart:io';
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
  static const _docsKey = 'pending_partner_documents';

  static Map<String, dynamic> toJson(RegistrationData d) => {
        'personal': {'fullName': d.fullName, 'email': d.email, 'dateOfBirth': d.dateOfBirth?.toIso8601String().substring(0, 10) ?? '', 'gender': d.gender, 'faceVerified': d.faceVerified, 'mobile': d.mobileNumber},
        'advocate': {'barCouncilRegNo': d.barCouncilRegNo, 'practiceArea': d.primaryPracticeArea, 'city': d.city, 'court': d.primaryCourt, 'languages': d.languagesSpoken, 'licenseFileName': d.advocateLicenseFile?.name ?? ''},
        'bank': {'holderName': d.bankAccountHolderName, 'ifsc': d.ifscCode, 'accountNumber': d.bankAccountNumber, 'upi': d.upiId},
      };

  static String _contentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ext == 'pdf' ? 'application/pdf' : ext == 'png' ? 'image/png' : 'image/jpeg';
  }

  /// Copies the face photo and licence into the app's own storage, so they can
  /// still be uploaded after sign-in, and lists them for [flush].
  static Future<List<Map<String, String>>> _keepDocuments(RegistrationData d) async {
    final docs = <Map<String, String>>[];
    Future<void> keep(String kind, String fileName, Future<List<int>> Function() read) async {
      try {
        final file = File('${Directory.systemTemp.path}/vakil_registration_$kind.${fileName.split('.').last.toLowerCase()}');
        await file.writeAsBytes(await read(), flush: true);
        docs.add({'kind': kind, 'path': file.path, 'fileName': fileName, 'contentType': _contentType(fileName)});
      } catch (error) {
        debugPrint('Could not keep the $kind document: $error');
      }
    }
    final face = d.facePhoto;
    if (face != null) await keep('face', 'face-verification.${face.path.split('.').last}', face.readAsBytes);
    final license = d.advocateLicenseFile;
    if (license != null) await keep('license', license.name, license.readAsBytes);
    return docs;
  }

  /// Sends now when signed in, otherwise keeps it for [flush] after sign-in.
  static Future<void> submit(RegistrationData data) async {
    final body = toJson(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(body));
    await prefs.setString(_docsKey, jsonEncode(await _keepDocuments(data)));
    final token = PartnerAuthService.instance.token;
    if (token != null) await flush(token);
  }

  /// Called after sign-in; sends a waiting registration once, then its documents.
  static Future<void> flush(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        await PartnerConsultationService().submitRegistration(token, Map<String, dynamic>.from(jsonDecode(saved) as Map));
        await prefs.remove(_key);
      }
      await _flushDocuments(token, prefs);
    } on PartnerNetworkException catch (error) {
      // 409: filled in for another email address; 400: incomplete. Don't retry those.
      if (error.statusCode == 409 || error.statusCode == 400) await (await SharedPreferences.getInstance()).remove(_key);
      debugPrint('Registration not sent: ${error.message}');
    } catch (error) {
      debugPrint('Registration not sent yet: $error');
    }
  }

  /// Uploads the kept documents; one that fails stays for the next try.
  static Future<void> _flushDocuments(String token, SharedPreferences prefs) async {
    final saved = prefs.getString(_docsKey);
    if (saved == null) return;
    final left = <Map<String, dynamic>>[];
    for (final doc in (jsonDecode(saved) as List).map((d) => Map<String, dynamic>.from(d as Map))) {
      final file = File(doc['path'] as String);
      if (!await file.exists()) continue;
      try {
        await PartnerConsultationService().uploadDocument(token, kind: doc['kind'] as String, base64File: base64Encode(await file.readAsBytes()), contentType: doc['contentType'] as String, fileName: doc['fileName'] as String);
        await file.delete().catchError((_) => file);
      } on PartnerNetworkException catch (error) {
        // 4xx: the server won't take this file; don't retry it.
        if ((error.statusCode ?? 500) >= 500) left.add(doc);
        debugPrint('Document not sent: ${error.message}');
      }
    }
    left.isEmpty ? await prefs.remove(_docsKey) : await prefs.setString(_docsKey, jsonEncode(left));
  }
}
