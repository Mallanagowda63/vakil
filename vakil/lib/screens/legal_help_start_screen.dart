import 'package:flutter/material.dart';
import '../state/app_route_observer.dart';
import '../state/free_trial_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_widgets.dart';
import 'home_shell.dart';

class LegalHelpStartScreen extends StatefulWidget {
  const LegalHelpStartScreen({super.key});

  @override
  State<LegalHelpStartScreen> createState() => _LegalHelpStartScreenState();
}

class _LegalHelpStartScreenState extends State<LegalHelpStartScreen>
    with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // A route pushed on top of this one (e.g. the paywall) was popped —
    // re-read FreeTrialState so a session consumed there is reflected here.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final trialUsed = FreeTrialState.used;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconChip(
                    icon: Icons.forum_rounded,
                    background: AppColors.blueAccent,
                    foreground: Colors.white,
                    size: 34,
                    iconSize: 17,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('LegalHelp',
                        style: AppText.h3(AppColors.textDark)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeShell()),
                      (route) => false,
                    ),
                    icon: Icon(Icons.close, color: AppColors.textGray),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: trialUsed ? AppColors.lightSurface : AppColors.blueSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trialUsed ? Icons.lock_outline : Icons.access_time,
                      size: 14,
                      color: trialUsed
                          ? AppColors.textGray
                          : AppColors.blueAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trialUsed
                          ? 'Free chat already used'
                          : '1-minute free chat',
                      style: AppText.bodySmall(
                        trialUsed ? AppColors.textGray : AppColors.blueAccent,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Talk to a lawyer now',
                  style: AppText.h1(AppColors.textDark)),
              const SizedBox(height: 8),
              Text(
                trialUsed
                    ? 'Your free 1-minute chat has already been used. '
                        'Upgrade to keep talking with a specialist.'
                    : 'Choose your issue below. We\'ll connect you with a '
                        'specialist in under 60 seconds.',
                style: AppText.body(AppColors.textGray),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
                children: const [
                  _IssueButton(icon: Icons.directions_car_filled_outlined, label: 'Accident'),
                  _IssueButton(icon: Icons.local_police_outlined, label: 'Police'),
                  _IssueButton(icon: Icons.gavel_outlined, label: 'Arrest'),
                  _IssueButton(icon: Icons.more_horiz, label: 'Other'),
                ],
              ),
              const SizedBox(height: 28),
              Text('How it works', style: AppText.h3(AppColors.textDark)),
              const SizedBox(height: 16),
              const _StepRow(
                number: '1',
                title: 'Choose your issue',
                description:
                    'Select one of the quick actions above to start your guided chat.',
              ),
              const SizedBox(height: 16),
              const _StepRow(
                number: '2',
                title: 'Answer 3 quick questions',
                description:
                    'We\'ll ask for the location and a brief summary of what happened.',
              ),
              const SizedBox(height: 16),
              const _StepRow(
                number: '3',
                title: 'Get connected',
                description:
                    'A specialist lawyer will join the chat to provide immediate guidance.',
              ),
              const SizedBox(height: 28),
              SolidButton(
                label: trialUsed ? 'Find a lawyer' : 'Start free 1-minute chat',
                background: trialUsed ? Colors.black : AppColors.blueAccent,
                icon: trialUsed ? Icons.arrow_forward : null,
                onTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeShell(initialIndex: 2)),
                  (route) => false,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeShell()),
                    (route) => false,
                  ),
                  child: Text('I\'ll do this later',
                      style: AppText.body(AppColors.textGray)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueButton extends StatelessWidget {
  const _IssueButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.blueAccent),
          const SizedBox(width: 8),
          Text(label, style: AppText.bodyMedium(AppColors.textDark)),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.blueSoft,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(number,
                style: AppText.bodyMedium(AppColors.blueAccent)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.bodyMedium(AppColors.textDark)),
              const SizedBox(height: 3),
              Text(description,
                  style: AppText.bodySmall(AppColors.textGray)),
            ],
          ),
        ),
      ],
    );
  }
}
