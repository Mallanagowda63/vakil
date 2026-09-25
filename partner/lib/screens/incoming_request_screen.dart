import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../services/app_keys.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'active_consultation_chat_screen.dart';

class IncomingRequestScreen extends StatefulWidget {
  final ConsultationRequest request;
  const IncomingRequestScreen({super.key, required this.request});

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen> {
  late int _secondsLeft = widget.request.secondsLeft;
  Timer? _timer;
  bool _resolved = false;
  late final DashboardController _controller = context.read<DashboardController>();

  @override
  void initState() {
    super.initState();
    OpenScreens.incomingRequestId = widget.request.id;
    _controller.addListener(_onRequestsChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      // Counts down to the server's expiry (60 s from when the client asked).
      setState(() => _secondsLeft = widget.request.expiresAt != null ? widget.request.secondsLeft : _secondsLeft - 1);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _resolve(accepted: false, auto: true);
      }
    });
  }

  @override
  void dispose() {
    if (OpenScreens.incomingRequestId == widget.request.id) OpenScreens.incomingRequestId = null;
    _controller.removeListener(_onRequestsChanged);
    _timer?.cancel();
    super.dispose();
  }

  /// The client cancelled or the request expired on the server: close quietly.
  void _onRequestsChanged() {
    if (_resolved || !mounted || _controller.requests.any((r) => r.id == widget.request.id)) return;
    _resolved = true;
    _timer?.cancel();
    Navigator.of(context).pop();
    messengerKey.currentState?.showSnackBar(SnackBar(content: Text('${widget.request.clientName}\'s request is no longer available')));
  }

  Future<void> _resolve({required bool accepted, bool auto = false}) async {
    if (_resolved) return;
    _resolved = true;
    _timer?.cancel();

    var stillAvailable = true;
    try {
      if (accepted) {
        stillAvailable = await _controller.acceptRequest(widget.request.id);
      } else if (!auto) {
        await _controller.rejectRequest(widget.request.id);
      }
    } catch (error) {
      _resolved = false;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }

    if (!mounted) return;
    if (accepted && stillAvailable) {
      // The chat opens on both phones the moment the request is accepted.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ActiveConsultationChatScreen(requestId: widget.request.id, title: widget.request.clientName)),
      );
      return;
    }
    if (accepted) {
      Navigator.of(context).pop();
      messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('This request is no longer available')));
      return;
    }

    context.read<DashboardController>().removeRequest(widget.request.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          auto
              ? 'Request from ${widget.request.clientName} timed out'
              : 'Declined ${widget.request.clientName}\'s request',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final urgent = _secondsLeft <= 15;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _resolve(accepted: false),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                ],
              ),
              const Text(
                'Vakil Partner',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Text(
                'Incoming consultation request',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: urgent ? const Color(0xFFFDECEC) : const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: urgent ? const Color(0xFFF5C2C2) : const Color(0xFFF5DCC0)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_filled, size: 18, color: urgent ? AppColors.danger : const Color(0xFFB5751B)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REQUEST EXPIRES',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.4,
                            color: urgent ? AppColors.danger : const Color(0xFFB5751B),
                          ),
                        ),
                        Text(
                          '${_secondsLeft}s left to respond',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: urgent ? AppColors.danger : const Color(0xFFB5751B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClientAvatar(name: r.clientName, photoUrl: r.photoUrl, radius: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                          r.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('PROBLEM', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 0.4)),
              const SizedBox(height: 8),
              Text(r.problemSummary, style: const TextStyle(fontSize: 13.5, height: 1.5)),
              if (r.type == ConsultationType.voice) ...[
                const SizedBox(height: 18),
                const CallRequestBadge(),
              ],
              if (r.isTrial) ...[
                const SizedBox(height: 18),
                const TrialBadge(),
              ] else if (r.pricePerMinute > 0) ...[
                const SizedBox(height: 14),
                Text(
                  '${r.type == ConsultationType.voice ? 'Voice call' : 'Chat'} · ₹${r.pricePerMinute}/min${r.maxMinutes > 0 ? ' · ${r.maxMinutes} min prepaid' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primaryDark),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBDBFC)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Personal documents stay hidden until you accept this request.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.primaryDark, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Accept',
                icon: Icons.check,
                onPressed: () => _resolve(accepted: true),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _resolve(accepted: false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// The client asked for a voice call: after Accept the chat opens and the client calls.
class CallRequestBadge extends StatelessWidget {
  const CallRequestBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(10)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.call, size: 16, color: AppColors.primary),
        SizedBox(width: 8),
        Text('VOICE CALL REQUEST', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.primary, letterSpacing: 0.3)),
      ]),
    );
  }
}

/// "FREE TRIAL – 1 min" marker for a client's first chat.
class TrialBadge extends StatelessWidget {
  const TrialBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFE7F6EC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB9E4C7))),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.card_giftcard, size: 16, color: AppColors.success),
        SizedBox(width: 8),
        Text('FREE TRIAL – 1 min', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.success, letterSpacing: 0.3)),
      ]),
    );
  }
}
