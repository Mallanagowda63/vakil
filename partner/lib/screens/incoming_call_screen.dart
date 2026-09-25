import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';
import 'connecting_call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final ConsultationRequest request;
  const IncomingCallScreen({super.key, required this.request});

  void _decline(BuildContext context) {
    context.read<DashboardController>().removeRequest(request.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Declined ${request.clientName}\'s call')),
    );
  }

  void _accept(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ConnectingCallScreen(request: request)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.callSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.callBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: AppColors.callTextSecondary),
                    SizedBox(width: 6),
                    Text(
                      'SECURE VAKIL CONNECTION',
                      style: TextStyle(color: AppColors.callTextSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary,
                child: Text(
                  request.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                request.clientName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Client ID: ${request.clientRef} · ${request.category}',
                style: const TextStyle(color: AppColors.callTextSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Rate: ₹${request.pricePerMinute}/min (Prepaid)',
                style: const TextStyle(color: AppColors.callTextSecondary, fontSize: 12.5),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _callButton(
                    color: AppColors.danger,
                    icon: Icons.call_end,
                    label: 'Decline',
                    onTap: () => _decline(context),
                  ),
                  _callButton(
                    color: AppColors.success,
                    icon: Icons.call,
                    label: 'Accept & Record',
                    onTap: () => _accept(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.callSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.callBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 15, color: Colors.white70),
                        SizedBox(width: 8),
                        Text('Privacy & Secure Modes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Recording is controlled by administrators and is not available in this view. '
                      'The following protected modes are currently enabled for this consultation.',
                      style: TextStyle(color: AppColors.callTextSecondary, fontSize: 11.5, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    _modeRow('Privacy mode enabled'),
                    _modeRow('Secure mode enabled'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callButton({required Color color, required IconData icon, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _modeRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColors.success),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
