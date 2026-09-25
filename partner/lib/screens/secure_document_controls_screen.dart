import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class SecureDocumentControlsScreen extends StatelessWidget {
  const SecureDocumentControlsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secure Document Sharing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Plain-language privacy notice', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Sharing controls in place', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'You can upload images and PDFs. Downloads stay restricted, and personal '
                      'documents remain unavailable until a consultation is accepted.',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('SHARING CONTROLS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.4)),
              const SizedBox(height: 10),
              _controlRow(Icons.image_outlined, 'Image and PDF upload', 'ENABLED', AppColors.success),
              _controlRow(Icons.timer_outlined, 'Screenshot blocking', 'LIMITED', const Color(0xFFB5751B)),
              _controlRow(Icons.lock_outline, 'Encrypted message storage', 'ENCRYPTED', AppColors.primary),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 15, color: AppColors.textPrimary),
                        SizedBox(width: 8),
                        Text('Before consultation acceptance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Personal documents are unavailable before consultation acceptance. Admin access is '
                      'limited to controlled dispute workflows, and no absolute privacy guarantee can be made.',
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '* Screenshot blocking is available only where the device and operating system allow it.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Return to Secure Chat', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controlRow(IconData icon, String label, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
