import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/registration_data.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import '../widgets/summary_card.dart';
import '../services/registration_sync.dart';
import 'activation_pending_screen.dart';
import 'personal_details_screen.dart';
import 'advocate_verification_screen.dart';
import 'bank_upi_screen.dart';

class ReviewSubmitScreen extends StatefulWidget {
  const ReviewSubmitScreen({super.key});

  @override
  State<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends State<ReviewSubmitScreen> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    // Goes to the Admin Panel for verification (after sign-in if not signed in yet).
    await RegistrationSync.submit(context.read<RegistrationData>());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ActivationPendingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<RegistrationData>();

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressHeader(
              step: 5,
              totalSteps: 5,
              title: 'Review & Submit',
              subtitle: 'Review every detail below before we send your application for final verification.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SummaryCard(
                      title: 'Personal Details',
                      icon: Icons.badge_outlined,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()),
                      ),
                      rows: [
                        SummaryRow('Full Name', data.fullName),
                        SummaryRow('Mobile Number', data.mobileNumber),
                        SummaryRow('Email Address', data.email),
                        SummaryRow('Date of Birth', data.formattedDob),
                        SummaryRow('Gender', data.gender),
                      ],
                    ),
                    SummaryCard(
                      title: 'Professional Credentials',
                      icon: Icons.gavel_outlined,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AdvocateVerificationScreen()),
                      ),
                      rows: [
                        SummaryRow('Bar Council Registration No.', data.barCouncilRegNo),
                        SummaryRow('Primary Practice Area', data.primaryPracticeArea),
                        SummaryRow('City', data.city),
                        SummaryRow('Primary Court', data.primaryCourt),
                        SummaryRow('Languages Spoken', data.languagesSpoken),
                        SummaryRow(
                          'Advocate License',
                          data.advocateLicenseFile != null ? 'Uploaded successfully' : '',
                        ),
                      ],
                    ),
                    SummaryCard(
                      title: 'Bank & UPI Details',
                      icon: Icons.account_balance_outlined,
                      onEdit: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BankUpiScreen()),
                      ),
                      rows: [
                        SummaryRow('Bank Account Holder Name', data.bankAccountHolderName),
                        SummaryRow('IFSC Code', data.ifscCode),
                        SummaryRow('Bank Account Number', data.maskedAccountNumber),
                        SummaryRow('UPI ID', data.upiId),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "We'll securely verify your identity, license, and payout "
                              'details before activating your partner account.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.primaryDark, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Submit for Verification',
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()),
                            ),
                    child: const Text('Edit Details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
