import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "STEP X OF N ... % Complete" bar + progress line + title/subtitle
/// block that appears at the top of every wizard screen.
class StepProgressHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;

  const StepProgressHeader({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final percent = ((step / totalSteps) * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP $step OF $totalSteps',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$percent% Complete',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: step / totalSteps,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
