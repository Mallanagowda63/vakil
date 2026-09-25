import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

/// Holds every field collected across the multi-step partner onboarding
/// wizard so later steps (and the review screen) can read/edit earlier
/// answers without re-asking the user.
class RegistrationData extends ChangeNotifier {
  // ---- Step 1: Personal details ----
  File? profilePhoto;
  String fullName = '';
  String mobileNumber = '';
  String email = '';
  DateTime? dateOfBirth;
  String gender = '';

  void savePersonalDetails({
    required File? photo,
    required String fullName,
    required String mobile,
    required String email,
    required DateTime? dob,
    required String gender,
  }) {
    profilePhoto = photo;
    this.fullName = fullName;
    mobileNumber = mobile;
    this.email = email;
    dateOfBirth = dob;
    this.gender = gender;
    notifyListeners();
  }

  // ---- Step 2: Face verification ----
  File? facePhoto;
  bool faceVerified = false;

  void saveFaceVerification(File photo) {
    facePhoto = photo;
    faceVerified = true;
    notifyListeners();
  }

  // ---- Step 3: Advocate verification ----
  String barCouncilRegNo = '';
  String primaryPracticeArea = '';
  String city = '';
  String primaryCourt = '';
  String languagesSpoken = '';
  PlatformFile? advocateLicenseFile;

  void saveAdvocateDetails({
    required String barCouncilRegNo,
    required String primaryPracticeArea,
    required String city,
    required String primaryCourt,
    required String languagesSpoken,
    required PlatformFile? licenseFile,
  }) {
    this.barCouncilRegNo = barCouncilRegNo;
    this.primaryPracticeArea = primaryPracticeArea;
    this.city = city;
    this.primaryCourt = primaryCourt;
    this.languagesSpoken = languagesSpoken;
    advocateLicenseFile = licenseFile;
    notifyListeners();
  }

  // ---- Step 4: Bank & UPI details ----
  String bankAccountHolderName = '';
  String ifscCode = '';
  String bankAccountNumber = '';
  String upiId = '';

  void saveBankDetails({
    required String holderName,
    required String ifsc,
    required String accountNumber,
    required String upi,
  }) {
    bankAccountHolderName = holderName;
    ifscCode = ifsc;
    bankAccountNumber = accountNumber;
    upiId = upi;
    notifyListeners();
  }

  String get formattedDob {
    if (dateOfBirth == null) return '';
    final d = dateOfBirth!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get maskedAccountNumber {
    if (bankAccountNumber.length <= 4) return bankAccountNumber;
    final last4 = bankAccountNumber.substring(bankAccountNumber.length - 4);
    return '${'X' * (bankAccountNumber.length - 4)}$last4';
  }
}
