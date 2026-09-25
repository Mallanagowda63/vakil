import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/registration_data.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import 'review_submit_screen.dart';

class BankUpiScreen extends StatefulWidget {
  const BankUpiScreen({super.key});

  @override
  State<BankUpiScreen> createState() => _BankUpiScreenState();
}

class _BankUpiScreenState extends State<BankUpiScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _holderCtrl;
  late final TextEditingController _ifscCtrl;
  late final TextEditingController _accountCtrl;
  late final TextEditingController _upiCtrl;

  @override
  void initState() {
    super.initState();
    final data = context.read<RegistrationData>();
    _holderCtrl = TextEditingController(text: data.bankAccountHolderName);
    _ifscCtrl = TextEditingController(text: data.ifscCode);
    _accountCtrl = TextEditingController(text: data.bankAccountNumber);
    _upiCtrl = TextEditingController(text: data.upiId);
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _ifscCtrl.dispose();
    _accountCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;

    context.read<RegistrationData>().saveBankDetails(
          holderName: _holderCtrl.text.trim(),
          ifsc: _ifscCtrl.text.trim().toUpperCase(),
          accountNumber: _accountCtrl.text.trim(),
          upi: _upiCtrl.text.trim(),
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewSubmitScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const StepProgressHeader(
              step: 4,
              totalSteps: 5,
              title: 'Bank & UPI Details',
              subtitle: 'Payments will be settled directly to this account.',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LabeledTextField(
                        label: 'Bank Account Holder Name',
                        required: true,
                        controller: _holderCtrl,
                        hint: 'e.g. Johnathan Doe',
                        textCapitalization: TextCapitalization.words,
                        prefixIcon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      LabeledTextField(
                        label: 'IFSC Code',
                        required: true,
                        controller: _ifscCtrl,
                        hint: 'e.g. SBIN0012345',
                        prefixIcon: Icons.numbers_outlined,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (v) {
                          final value = v?.trim().toUpperCase() ?? '';
                          if (value.isEmpty) return 'Required';
                          final ok = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value);
                          return ok ? null : 'Enter a valid 11-character IFSC code';
                        },
                      ),
                      LabeledTextField(
                        label: 'Bank Account Number',
                        required: true,
                        controller: _accountCtrl,
                        hint: 'e.g. 1234567890123',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.account_balance_outlined,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(18),
                        ],
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Required';
                          if (value.length < 9) return 'Enter a valid account number';
                          return null;
                        },
                      ),
                      LabeledTextField(
                        label: 'UPI ID (For instant payouts)',
                        required: true,
                        controller: _upiCtrl,
                        hint: 'e.g. johndoe@upi',
                        prefixIcon: Icons.alternate_email,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Required';
                          final ok = RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(value);
                          return ok ? null : 'Enter a valid UPI ID';
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(label: 'Next', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}
