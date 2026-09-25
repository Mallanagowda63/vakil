import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

OverlayEntry? _activeBanner;

/// Shows a dismissible in-app notification banner sliding down from the top
/// of the screen, above whatever is currently on display.
void showNotificationBanner(
  BuildContext context, {
  required String title,
  required String time,
  required String message,
  required VoidCallback onView,
  String viewLabel = 'View',
  String laterLabel = 'Later',
}) {
  _activeBanner?.remove();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  void dismiss() {
    entry.remove();
    if (identical(_activeBanner, entry)) _activeBanner = null;
  }

  entry = OverlayEntry(
    builder: (overlayContext) => Positioned(
      top: MediaQuery.of(overlayContext).padding.top + 8,
      left: 16,
      right: 16,
      child: _AnimatedBanner(
        title: title,
        time: time,
        message: message,
        viewLabel: viewLabel,
        laterLabel: laterLabel,
        onView: () {
          dismiss();
          onView();
        },
        onDismiss: dismiss,
      ),
    ),
  );

  _activeBanner = entry;
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 8), () {
    if (identical(_activeBanner, entry)) dismiss();
  });
}

class _AnimatedBanner extends StatefulWidget {
  final String title;
  final String time;
  final String message;
  final String viewLabel;
  final String laterLabel;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const _AnimatedBanner({
    required this.title,
    required this.time,
    required this.message,
    required this.viewLabel,
    required this.laterLabel,
    required this.onView,
    required this.onDismiss,
  });

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _controller,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.infoBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_outlined, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text(widget.time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(widget.message, style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: widget.onView,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(widget.viewLabel),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: widget.onDismiss,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.background,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(widget.laterLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
