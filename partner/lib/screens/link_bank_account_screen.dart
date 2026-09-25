import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/wallet_data.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';

/// A tiny built-in demo directory of IFSC codes so the "Verify" step can look
/// up a real-looking branch name without calling an external API.
const _ifscDirectory = {
  'HDFC0000124': 'HDFC Bank, Kasturba Gandhi Marg, New Delhi',
  'SBIN0001234': 'State Bank of India, Connaught Place, New Delhi',
  'ICIC0000456': 'ICICI Bank, Bandra West, Mumbai',
};

class LinkBankAccountScreen extends StatefulWidget {
  const LinkBankAccountScreen({super.key});

  @override
  State<LinkBankAccountScreen> createState() => _LinkBankAccountScreenState();
}

class _LinkBankAccountScreenState extends State<LinkBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _holderCtrl = TextEditingController(text: 'Adv. Rajesh Kumar Sharma');
  final _ifscCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _confirmAccountCtrl = TextEditingController();
  String? _branch;
  bool _verifying = false;

  @override
  void dispose() {
    _holderCtrl.dispose();
    _ifscCtrl.dispose();
    _accountCtrl.dispose();
    _confirmAccountCtrl.dispose();
    super.dispose();
  }

  void _onIfscChanged(String value) {
    final upper = value.trim().toUpperCase();
    setState(() => _branch = _ifscDirectory[upper]);
  }

  Future<void> _verifyAndLink() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountCtrl.text.trim() != _confirmAccountCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account numbers do not match')),
      );
      return;
    }
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    context.read<WalletController>().linkBankAccount(
          holderName: _holderCtrl.text.trim(),
          ifsc: _ifscCtrl.text.trim().toUpperCase(),
          branch: _branch ?? 'Bank branch on record',
          accountNumber: _accountCtrl.text.trim(),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank account linked successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ifscVerified = _branch != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Link Bank Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledTextField(
                  label: "Account Holder's Name",
                  required: true,
                  controller: _holderCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const Text('IFSC Code', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _ifscCtrl,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _onIfscChanged,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: 'e.g. HDFC0000124',
                    suffixIcon: ifscVerified
                        ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                        : null,
                  ),
                  validator: (v) {
                    final value = v?.trim().toUpperCase() ?? '';
                    if (value.isEmpty) return 'Required';
                    return RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(value) ? null : 'Enter a valid IFSC code';
                  },
                ),
                if (_branch != null) ...[
                  const SizedBox(height: 6),
                  Text('✓ $_branch', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                LabeledTextField(
                  label: 'Account Number',
                  required: true,
                  controller: _accountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
                  validator: (v) => (v == null || v.trim().length < 9) ? 'Enter a valid account number' : null,
                ),
                LabeledTextField(
                  label: 'Confirm Account Number',
                  required: true,
                  controller: _confirmAccountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'We will deposit ₹1.00 to verify this account instantly.',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Verify & Link Bank Account',
                  loading: _verifying,
                  onPressed: _verifying ? null : _verifyAndLink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
