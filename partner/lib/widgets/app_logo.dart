import 'package:flutter/material.dart';

/// The Legally Talk logo. [light] is the white version for dark backgrounds.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.width = 220, this.light = false});
  final double width;
  final bool light;

  /// Splash screen background, matching the Android launch screen.
  static const splashBackground = Color(0xFFECEEF4);

  @override
  Widget build(BuildContext context) => Image.asset(
        light ? 'assets/images/legally_logo_white.png' : 'assets/images/legally_logo.png',
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Legally Talk',
      );
}
