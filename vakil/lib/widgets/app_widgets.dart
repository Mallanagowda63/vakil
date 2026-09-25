import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A full-width pill/rounded button with solid background.
class SolidButton extends StatelessWidget {
  const SolidButton({
    super.key,
    required this.label,
    required this.onTap,
    this.background = const Color(0xFF14141F),
    this.foreground = Colors.white,
    this.icon,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppText.button(foreground)),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: foreground),
            ],
          ],
        ),
      ),
    );
  }
}

/// An outlined pill button, typically for social sign-in on light surfaces.
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
    this.background = Colors.white,
    this.foreground = const Color(0xFF14141F),
    this.borderColor,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          side: BorderSide(color: borderColor ?? const Color(0xFFE2E2EA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Text(label, style: AppText.bodyMedium(foreground)),
          ],
        ),
      ),
    );
  }
}

/// Uppercase small field label used above inputs.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppText.label(color ?? AppColors.textGray));
  }
}

/// A rounded input-like container with a leading icon, primary text and
/// optional trailing widget (Edit link, verified check, etc). Read-only
/// look to match the static mockups.
class InfoField extends StatelessWidget {
  const InfoField({
    super.key,
    required this.icon,
    required this.value,
    this.trailing,
    this.dark = false,
  });

  final IconData icon;
  final String value;
  final Widget? trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppColors.darkInputBg : AppColors.lightSurface;
    final stroke = dark ? AppColors.darkStroke : AppColors.lightStroke;
    final textColor = dark ? AppColors.textWhite : AppColors.textDark;
    final iconColor = dark ? AppColors.textMuted : AppColors.textGray;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: AppText.input(textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A real, user-editable text field styled like [InfoField] — no baked-in
/// default value, just an icon, a hint, and whatever the user types.
class EditableField extends StatelessWidget {
  const EditableField({
    super.key,
    required this.icon,
    required this.controller,
    required this.hint,
    this.trailing,
    this.dark = false,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.focusNode,
    this.onChanged,
  });

  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final Widget? trailing;
  final bool dark;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppColors.darkInputBg : AppColors.lightSurface;
    final stroke = dark ? AppColors.darkStroke : AppColors.lightStroke;
    final textColor = dark ? AppColors.textWhite : AppColors.textDark;
    final iconColor = dark ? AppColors.textMuted : AppColors.textGray;
    final hintColor = dark ? AppColors.textFaint : AppColors.textGraySoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              keyboardType: keyboardType,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              style: AppText.input(textColor),
              cursorColor: textColor,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle:
                    AppText.input(hintColor).copyWith(fontWeight: FontWeight.w400),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small "Edit" text link.
class EditLink extends StatelessWidget {
  const EditLink({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text('Edit', style: AppText.bodyMedium(AppColors.blueAccent)),
    );
  }
}

/// Circular badge used for numbered "How it works" steps and icon chips.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 40,
    this.iconSize = 20,
    this.radius = 12,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}
