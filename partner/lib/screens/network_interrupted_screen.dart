import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown when the active call's network connection drops. Watches real
/// device connectivity and also retries on a timer; pops `true` if the
/// connection comes back so the call can resume, or `false` if the retry
/// attempts are exhausted or the lawyer disconnects manually.
class NetworkInterruptedScreen extends StatefulWidget {
  const NetworkInterruptedScreen({super.key});

  @override
  State<NetworkInterruptedScreen> createState() => _NetworkInterruptedScreenState();
}

class _NetworkInterruptedScreenState extends State<NetworkInterruptedScreen> {
  static const _maxAttempts = 3;
  int _attempt = 1;
  bool _resolved = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) _resolve(true);
    });
    _retryLoop();
  }

  Future<void> _retryLoop() async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (_resolved) return;
      if (mounted) setState(() => _attempt = attempt);
      await Future.delayed(const Duration(seconds: 4));
      if (_resolved) return;
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        _resolve(true);
        return;
      }
    }
    _resolve(false);
  }

  void _resolve(bool reconnected) {
    if (_resolved || !mounted) return;
    _resolved = true;
    _sub?.cancel();
    Navigator.of(context).pop(reconnected);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.callBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A1C1C),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF6B2C2C)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE85C5C), size: 38),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Network Interrupted',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Reconnecting call secure line (Attempt $_attempt/$_maxAttempts)...',
                  style: const TextStyle(color: AppColors.callTextSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.callSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.callBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Resuming encrypted session...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 60),
                Column(
                  children: [
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _resolve(false),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Disconnect', style: TextStyle(color: Colors.white, fontSize: 12)),
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
