import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'app_keys.dart';
import 'partner_auth_service.dart';

/// The Rapido/Uber-style bubble: while the lawyer is online (Chat or Voice
/// switched on) and leaves the app, a round Legally Talk logo floats on the
/// screen edge; tapping it brings the app back. Hidden again when the app
/// comes back, the lawyer goes offline or signs out. Android side:
/// android/.../OnlineBubble.kt (needs "Display over other apps").
class OnlineBubble with WidgetsBindingObserver {
  OnlineBubble._();
  static final instance = OnlineBubble._();
  static const _channel = MethodChannel('vakil/online_bubble');
  static const _askedKey = 'online_bubble_permission_asked';

  bool _online = false;
  bool _started = false;
  bool _inBackground = false;

  void _start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called whenever the Chat / Voice switches change.
  void setOnline(bool online) {
    _start();
    final wentOnline = online && !_online;
    _online = online;
    if (!online) _hide();
    if (wentOnline) _offerPermission();
  }

  /// Signing out hides it for good.
  void signedOut() { _online = false; _hide(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _inBackground = false; _hide(); return; }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_inBackground) return;
      _inBackground = true;
      if (_online && PartnerAuthService.instance.token != null) _show();
    }
  }

  Future<void> _show() async { try { await _channel.invokeMethod('show'); } catch (_) {} }
  Future<void> _hide() async { try { await _channel.invokeMethod('hide'); } catch (_) {} }

  /// Asks once, with an explanation, for "Display over other apps".
  Future<void> _offerPermission() async {
    try {
      if (await _channel.invokeMethod<bool>('canDraw') == true) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) == true) return;
      await prefs.setBool(_askedKey, true);
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.infoBg, shape: BoxShape.circle),
            child: const Icon(Icons.bubble_chart_outlined, color: AppColors.primary, size: 28),
          ),
          title: const Text('Stay one tap away', textAlign: TextAlign.center),
          content: const Text(
            'While you are online, a small Legally Talk Partner bubble can stay on the side of your screen when you use other apps. Tap it to come straight back when a client needs you.\n\n'
            'On the next screen, turn on "Allow display over other apps".',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Turn on')),
          ],
        ),
      );
      if (allow == true) await _channel.invokeMethod('openSettings');
    } catch (_) {}
  }
}
