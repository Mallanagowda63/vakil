import 'package:flutter/material.dart';
import '../models/lawyer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'consultation_chat_screen.dart';
import 'voice_call_screen.dart';

/// Single entry point into a lawyer consultation — every "Call" or "Chat"
/// affordance anywhere in the app (Home, Available Lawyers, Lawyer
/// Profile) should call this instead of pushing routes directly, so the
/// flow is guaranteed identical no matter which lawyer or screen it
/// started from.
void startLawyerCall(
  BuildContext context,
  Lawyer lawyer, {
  required bool isVoiceCall,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          CallConnectingScreen(lawyer: lawyer, isVoiceCall: isVoiceCall),
    ),
  );
}

/// The first step of every lawyer consultation, regardless of which
/// lawyer or entry point (Home, Available Lawyers, Lawyer Profile)
/// started it — keeps the whole call flow identical for any lawyer.
class CallConnectingScreen extends StatefulWidget {
  const CallConnectingScreen({
    super.key,
    required this.lawyer,
    required this.isVoiceCall,
  });

  final Lawyer lawyer;
  final bool isVoiceCall;

  @override
  State<CallConnectingScreen> createState() => _CallConnectingScreenState();
}

class _CallConnectingScreenState extends State<CallConnectingScreen> {
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted || _cancelled) return;
      final next = widget.isVoiceCall
          ? VoiceCallScreen(lawyer: widget.lawyer)
          : ConsultationChatScreen(lawyer: widget.lawyer);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _cancelled = true;
                      Navigator.of(context).maybePop();
                    },
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textDark),
                  ),
                  Expanded(
                    child: Text('Call Settings',
                        textAlign: TextAlign.center,
                        style: AppText.h3(AppColors.textDark)),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.blueSoft,
                      child: Icon(Icons.person,
                          size: 44, color: AppColors.blueAccent),
                    ),
                    const SizedBox(height: 24),
                    Text('Connecting…', style: AppText.h1(AppColors.textDark)),
                    const SizedBox(height: 8),
                    Text(
                      'Setting up a secure connection with ${widget.lawyer.name}',
                      textAlign: TextAlign.center,
                      style: AppText.body(AppColors.textGray),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: const LinearProgressIndicator(
                          minHeight: 5,
                          backgroundColor: AppColors.lightSurface,
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('INITIALIZING SECURE TUNNEL',
                        style: AppText.label(AppColors.textGraySoft)),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _cancelled = true;
                            Navigator.of(context).maybePop();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.redSoft,
                            foregroundColor: AppColors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.lightStroke),
                          ),
                          child: Icon(Icons.question_mark,
                              size: 16, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
