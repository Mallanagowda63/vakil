import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class LabeledTextField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.required = false,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
            children: required
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 19, color: AppColors.textSecondary)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
