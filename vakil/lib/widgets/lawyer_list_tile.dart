import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LawyerListTile extends StatelessWidget {
  const LawyerListTile({
    super.key,
    required this.lawyer,
    required this.onTap,
    this.onChat,
    this.onCall,
  });

  final Lawyer lawyer;
  final VoidCallback onTap;
  final VoidCallback? onChat;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final statusColor = lawyer.status == LawyerStatus.live
        ? AppColors.greenAccent
        : AppColors.connectedBadgeFg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightStroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.blueSoft,
                  child: Icon(Icons.person,
                      size: 24, color: AppColors.blueAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(lawyer.name,
                                style: AppText.bodyMedium(
                                    AppColors.textDark),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(lawyer.statusLabel,
                              style: AppText.caption(statusColor)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('${lawyer.specialty} • ${lawyer.experience}',
                          style: AppText.bodySmall(AppColors.textGray)),
                    ],
                  ),
                ),
                if (lawyer.paid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.paidBadgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Paid',
                        style: AppText.caption(AppColors.paidBadgeFg)
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.star, size: 14, color: AppColors.starGold),
                const SizedBox(width: 3),
                Text('${lawyer.rating} (${lawyer.reviews} reviews)',
                    style: AppText.bodySmall(AppColors.textGray)),
                const Spacer(),
                Text(lawyer.rate,
                    style: AppText.bodyMedium(AppColors.textDark)),
                const SizedBox(width: 10),
                _RoundIconButton(icon: Icons.chat_bubble_outline, onTap: onChat),
                const SizedBox(width: 6),
                _RoundIconButton(icon: Icons.call_outlined, onTap: onCall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: AppColors.textDark),
      ),
    );
  }
}
