import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_data.dart';
import '../theme/app_theme.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/primary_button.dart';

const _popularHandles = ['@oksbi', '@okhdfcbank', '@paytm', '@ybl'];

class ConnectUpiScreen extends StatefulWidget {
  const ConnectUpiScreen({super.key});

  @override
  State<ConnectUpiScreen> createState() => _ConnectUpiScreenState();
}

class _ConnectUpiScreenState extends State<ConnectUpiScreen> {
  late final _vpaCtrl = TextEditingController();
  String? _verifiedName;
  bool _verifying = false;

  bool get _looksValid => RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(_vpaCtrl.text.trim());

  void _appendHandle(String handle) {
    final current = _vpaCtrl.text.split('@').first;
    setState(() {
      _vpaCtrl.text = '$current$handle';
      _verifiedName = null;
    });
  }

  Future<void> _verifyAndLink() async {
    if (!_looksValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid UPI ID')),
      );
      return;
    }
    setState(() => _verifying = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verifiedName = 'RAJESH KUMAR SHARMA';
    });
    context.read<WalletController>().linkUpi(_vpaCtrl.text.trim(), _verifiedName!);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI ID linked successfully')),
    );
  }

  @override
  void dispose() {
    _vpaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect UPI ID')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your settlements are securely processed via certified payment partners.',
                        style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LabeledTextField(
                label: 'Enter Virtual Payment Address (VPA) / UPI ID',
                required: true,
                controller: _vpaCtrl,
                hint: 'yourname@bank',
                onChanged: (_) => setState(() => _verifiedName = null),
              ),
              const Text('Popular handles:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _popularHandles
                    .map((h) => ActionChip(
                          label: Text(h),
                          onPressed: () => _appendHandle(h),
                          backgroundColor: AppColors.background,
                          side: const BorderSide(color: AppColors.border),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              if (_verifiedName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB7E4CC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('VPA HOLDER NAME', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.3)),
                          Text(_verifiedName!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Verify & Link UPI',
                loading: _verifying,
                onPressed: _verifying ? null : _verifyAndLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
