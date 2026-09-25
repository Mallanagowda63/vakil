import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';
import 'connected_call_screen.dart';

class ConnectingCallScreen extends StatefulWidget {
  final ConsultationRequest request;
  const ConnectingCallScreen({super.key, required this.request});

  @override
  State<ConnectingCallScreen> createState() => _ConnectingCallScreenState();
}

class _ConnectingCallScreenState extends State<ConnectingCallScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1, milliseconds: 200),
  )..repeat(reverse: true);
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _cancelled) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ConnectedCallScreen(request: widget.request)),
      );
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.callSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.callBorder),
                ),
                child: const Text(
                  'SECURE VAKIL CONNECTION',
                  style: TextStyle(color: AppColors.callTextSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.phone_in_talk_outlined, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'CONNECTING SECURE LINE...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generating temporary encrypted channel ID',
                style: TextStyle(color: AppColors.callTextSecondary, fontSize: 12.5),
              ),
              const Spacer(),
              Column(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _cancelled = true;
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
