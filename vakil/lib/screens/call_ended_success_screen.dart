import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import '../widgets/app_widgets.dart';
import 'home_shell.dart';

class CallEndedSuccessScreen extends StatelessWidget {
  const CallEndedSuccessScreen({
    super.key,
    required this.lawyer,
    required this.elapsedSeconds,
    required this.totalCost,
  });

  final Lawyer lawyer;
  final int elapsedSeconds;
  final double totalCost;

  void _backToDashboard(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  void _leaveReview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ReviewDialog(lawyer: lawyer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Consultation Ended',
                        style: AppText.bodySmall(AppColors.textGray)),
                  ),
                  Icon(Icons.more_vert, size: 18, color: AppColors.textGray),
                ],
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.greenAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle,
                            size: 34, color: AppColors.greenAccent),
                      ),
                      const SizedBox(height: 16),
                      Text('Consultation Completed',
                          style: AppText.h2(AppColors.textDark)),
                      const SizedBox(height: 6),
                      Text(
                        'Your session with Advisor ${lawyer.name} has ended.',
                        textAlign: TextAlign.center,
                        style: AppText.bodySmall(AppColors.textGray),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightStroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldLabel('SESSION SUMMARY'),
                            const SizedBox(height: 12),
                            _Row('Duration', formatMinutesSeconds(elapsedSeconds)),
                            const SizedBox(height: 8),
                            _Row('Base Rate', lawyer.rate),
                            const SizedBox(height: 10),
                            Divider(color: AppColors.lightStroke),
                            const SizedBox(height: 8),
                            _Row('Total Cost', formatCurrency(totalCost),
                                bold: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightStroke),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.blueSoft,
                              child: Text(lawyer.initials,
                                  style:
                                      AppText.bodyMedium(AppColors.blueAccent)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lawyer.name,
                                      style:
                                          AppText.bodyMedium(AppColors.textDark)),
                                  Text(lawyer.specialty,
                                      style: AppText.bodySmall(
                                          AppColors.textGray)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SolidButton(
                label: 'Leave a Review',
                background: AppColors.blueAccent,
                onTap: () => _leaveReview(context),
              ),
              const SizedBox(height: 10),
              OutlineButton(
                label: 'Back to Dashboard',
                onTap: () => _backToDashboard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.bodySmall(AppColors.textGray)),
        Text(value,
            style: bold
                ? AppText.h3(AppColors.textDark)
                : AppText.bodyMedium(AppColors.textDark)),
      ],
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.lawyer});
  final Lawyer lawyer;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _stars = 5;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rate ${widget.lawyer.name}',
                style: AppText.h3(AppColors.textDark)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _stars;
                return GestureDetector(
                  onTap: () => setState(() => _stars = i + 1),
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: AppColors.starGold,
                    size: 30,
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            SolidButton(
              label: 'Submit Review',
              background: Colors.black,
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thanks for your feedback!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
