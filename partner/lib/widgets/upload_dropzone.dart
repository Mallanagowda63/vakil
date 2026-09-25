import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dashed-look upload box used for document uploads (e.g. Advocate License).
class UploadDropzone extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? fileName;
  final VoidCallback? onRemove;

  const UploadDropzone({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon = Icons.cloud_upload_outlined,
    this.fileName,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final uploaded = fileName != null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: uploaded ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        decoration: BoxDecoration(
          color: uploaded ? const Color(0xFFF0FBF5) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded ? AppColors.success : AppColors.border,
            width: 1.2,
          ),
        ),
        child: uploaded
            ? Column(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    fileName!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Uploaded successfully',
                    style: TextStyle(color: AppColors.success, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onRemove,
                    child: const Text('Change file'),
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(icon, color: AppColors.textSecondary, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
      ),
    );
  }
}
