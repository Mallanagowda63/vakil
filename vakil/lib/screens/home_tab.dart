import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/consultation_service.dart';
import '../services/profile_service.dart';
import '../services/realtime_service.dart';
import '../state/home_nav.dart';
import '../widgets/wallet_widgets.dart';
import 'lawyers_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'lawyer_profile_screen.dart';
import 'lawyer_search_screen.dart';
import 'legal_help_start_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.aiCardStart, AppColors.aiCardEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vakil', style: AppText.h3(AppColors.textDark)),
                      Text('Let\'s Talk Our Rights',
                          style: AppText.caption(AppColors.textGray)),
                    ],
                  ),
                ),
                const WalletButton(),
                const SizedBox(width: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none, color: AppColors.textDark),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                const _MyAvatar(),
              ],
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: AppText.h1(AppColors.textDark),
                children: [
                  const TextSpan(text: 'Hi, Need '),
                  TextSpan(
                      text: 'Legal Help?',
                      style: AppText.h1(AppColors.blueAccent)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Connect with verified lawyers anytime, anywhere.',
                style: AppText.bodySmall(AppColors.textGray)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lightStroke),
              ),
              // Opens the lawyer search (name, practice area, city, language).
              child: TextField(
                readOnly: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LawyerSearchScreen())),
                style: AppText.input(AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Search lawyers by name, area or city...',
                  hintStyle: AppText.body(AppColors.textGray),
                  prefixIcon:
                      Icon(Icons.search, size: 20, color: AppColors.textGray),
                  suffixIcon:
                      Icon(Icons.tune, size: 20, color: AppColors.blueAccent),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _HeroBanner(),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Browse by specialty',
                    style: AppText.h3(AppColors.textDark)),
                GestureDetector(
                  onTap: () => HomeNav.openLawyers(),
                  child: Row(
                    children: [
                      Text('See all',
                          style: AppText.bodySmall(AppColors.blueAccent)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward,
                          size: 14, color: AppColors.blueAccent),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: const [
                _SpecialtyCard(
                  speciality: Speciality.all,
                  icon: Icons.balance,
                  label: 'Legal\nSpecialist',
                  background: AppColors.blueSoft,
                  foreground: AppColors.blueAccent,
                ),
                _SpecialtyCard(
                  speciality: Speciality.criminal,
                  icon: Icons.gavel,
                  label: 'Criminal\nLaw',
                  background: AppColors.redSoft,
                  foreground: AppColors.redAccent,
                ),
                _SpecialtyCard(
                  speciality: Speciality.family,
                  icon: Icons.diversity_1,
                  label: 'Family\nLaw',
                  background: Color(0xFFE3F6EA),
                  foreground: AppColors.greenAccent,
                ),
                _SpecialtyCard(
                  speciality: Speciality.business,
                  icon: Icons.business_center_outlined,
                  label: 'Business\nLaw',
                  background: AppColors.amberSoft,
                  foreground: AppColors.amber,
                ),
                _SpecialtyCard(
                  speciality: Speciality.realEstate,
                  icon: Icons.home_outlined,
                  label: 'Real\nEstate',
                  background: AppColors.blueSoft,
                  foreground: AppColors.blueAccent,
                ),
                _SpecialtyCard(
                  speciality: Speciality.medical,
                  icon: Icons.medical_services_outlined,
                  label: 'Medical\nMalpractice',
                  background: AppColors.redSoft,
                  foreground: AppColors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('App at a Glance',
                                style: AppText.h3(AppColors.textDark)),
                            const SizedBox(height: 2),
                            Text(
                              'Live legal support, trusted by thousands',
                              style: AppText.caption(AppColors.textGray),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              AppColors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text('Live Now',
                                style: AppText.label(AppColors.greenAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Expanded(
                        child: _GlanceStat(
                          icon: Icons.groups_outlined,
                          value: '248',
                          label: 'Lawyers\nAvailable',
                        ),
                      ),
                      Expanded(
                        child: _GlanceStat(
                          icon: Icons.star_border,
                          value: '4.9',
                          label: 'Avg\nRating',
                        ),
                      ),
                      Expanded(
                        child: _GlanceStat(
                          icon: Icons.call_outlined,
                          value: '56',
                          label: 'Currently\nConnected',
                        ),
                      ),
                      Expanded(
                        child: _GlanceStat(
                          icon: Icons.description_outlined,
                          value: '12.4k',
                          label: 'Cases\nClosed',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.aiCardStart, AppColors.aiCardEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.smart_toy_outlined,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Legal Saathi',
                                    style: AppText.h3(Colors.white)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('AI',
                                      style: AppText.caption(Colors.white)
                                          .copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ask questions, get instant legal guidance, '
                              'summaries, and next steps.',
                              style: AppText.caption(
                                  Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AiTag(icon: Icons.bolt, label: 'Explain Laws'),
                      _AiTag(
                          icon: Icons.description_outlined,
                          label: 'Draft Documents'),
                      _AiTag(
                          icon: Icons.chat_bubble_outline,
                          label: 'Case Guidance'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LegalHelpStartScreen()),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Start Chat',
                              style: AppText.bodyMedium(AppColors.aiCardEnd)),
                          const SizedBox(width: 5),
                          Icon(Icons.arrow_forward,
                              size: 15, color: AppColors.aiCardEnd),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Featured Lawyers', style: AppText.h3(AppColors.textDark)),
                GestureDetector(
                  onTap: () => HomeNav.openLawyers(),
                  child: Row(
                    children: [
                      Text('See all',
                          style: AppText.bodySmall(AppColors.blueAccent)),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward,
                          size: 14, color: AppColors.blueAccent),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _FeaturedLawyers(),
            const SizedBox(height: 26),
            Text('Trust essentials', style: AppText.h3(AppColors.textDark)),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: _TrustItem(
                      icon: Icons.shield_outlined, label: 'Private &\nSecure'),
                ),
                Expanded(
                  child: _TrustItem(
                      icon: Icons.verified_outlined,
                      label: 'Verified\nLawyer'),
                ),
                Expanded(
                  child: _TrustItem(
                      icon: Icons.lock_outline, label: 'Secure\nPayment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The signed-in user's photo (or initials); opens the Profile tab.
class _MyAvatar extends StatefulWidget {
  const _MyAvatar();
  @override
  State<_MyAvatar> createState() => _MyAvatarState();
}

class _MyAvatarState extends State<_MyAvatar> {
  @override
  void initState() {
    super.initState();
    if (ProfileService.instance.profile.value == null) ProfileService.instance.load().catchError((_) => const UserProfile());
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<UserProfile?>(
        valueListenable: ProfileService.instance.profile,
        builder: (_, profile, _) => GestureDetector(
          onTap: () => HomeNav.tab.value = HomeNav.profile,
          child: LawyerAvatar(name: profile?.fullName ?? '', photoUrl: profile?.photoUrl, radius: 17),
        ),
      );
}

class _HeroBanner extends StatefulWidget {
  const _HeroBanner();

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blueSoft,
            AppColors.purpleAccent.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEGAL SUPPORT, SIMPLIFIED',
                        style: AppText.label(AppColors.blueAccent)),
                    const SizedBox(height: 8),
                    Text('Your Rights,\nOur Priority',
                        style: AppText.h1(AppColors.textDark)
                            .copyWith(fontSize: 24)),
                    const SizedBox(height: 8),
                    Text(
                      'Get expert legal advice through chat, '
                      'call or our AI assistant.',
                      style: AppText.bodySmall(AppColors.textGray),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const LegalHelpStartScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.navyDeep,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Get Started',
                                style: AppText.bodyMedium(Colors.white)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward,
                                size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _ScalesIllustration(),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final active = i == 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.blueAccent
                        : AppColors.blueAccent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lightweight stand-in for a scales-of-justice illustration, built from
/// plain shapes since the app ships no image assets.
class _ScalesIllustration extends StatelessWidget {
  const _ScalesIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.balance, size: 56, color: AppColors.gold),
          const SizedBox(height: 6),
          _bookBar('JUSTICE', AppColors.navyDeep, 84),
          const SizedBox(height: 2),
          _bookBar('KNOWLEDGE', AppColors.splashBlue, 90),
          const SizedBox(height: 2),
          _bookBar('RIGHTS', AppColors.blueAccent, 78),
        ],
      ),
    );
  }

  Widget _bookBar(String label, Color color, double width) {
    return Container(
      width: width,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: AppText.caption(Colors.white)
            .copyWith(fontSize: 7, fontWeight: FontWeight.w700, height: 1),
      ),
    );
  }
}

class _AiTag extends StatelessWidget {
  const _AiTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: AppText.caption(Colors.white)),
        ],
      ),
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({
    required this.speciality,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final Speciality speciality;
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    // Opens the Lawyers tab filtered to this speciality.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => HomeNav.openLawyers(speciality),
      child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 26, color: foreground),
        ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: AppText.bodySmall(AppColors.textDark)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
    );
  }
}

class _GlanceStat extends StatelessWidget {
  const _GlanceStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.blueAccent),
        const SizedBox(height: 6),
        Text(value, style: AppText.h3(AppColors.textDark)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: AppText.caption(AppColors.textGray)),
      ],
    );
  }
}

/// Lawyers from the server, online first, with their price or the free-trial badge.
class _FeaturedLawyers extends StatefulWidget {
  const _FeaturedLawyers();
  @override
  State<_FeaturedLawyers> createState() => _FeaturedLawyersState();
}

class _FeaturedLawyersState extends State<_FeaturedLawyers> {
  final _service = ConsultationService();
  StreamSubscription<SocketEvent>? _events;
  Timer? _debounce;
  List<LawyerSummary>? _lawyers;

  @override
  void initState() {
    super.initState();
    _events = RealtimeService.instance.events.stream.listen((event) {
      final lawyers = _lawyers;
      if (event.name == 'lawyer_status_changed' && lawyers != null && lawyers.any((l) => l.id == event.data['id']?.toString())) {
        if (mounted) setState(() => _lawyers = applyLawyerStatus(lawyers, event.data));
      } else if (event.name == 'lawyer_status_changed' || event.name == 'connect') {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), _load);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lawyers = sortLawyers(await _service.lawyers());
      if (mounted) setState(() => _lawyers = lawyers.take(8).toList());
    } catch (_) {
      if (mounted) setState(() => _lawyers ??= const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lawyers = _lawyers;
    if (lawyers == null) return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator()));
    if (lawyers.isEmpty) return SizedBox(height: 60, child: Center(child: Text('No lawyers available right now.', style: AppText.bodySmall(AppColors.textGray))));
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lawyers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _FeaturedLawyerCard(lawyer: lawyers[i]),
      ),
    );
  }
}

class _FeaturedLawyerCard extends StatelessWidget {
  const _FeaturedLawyerCard({required this.lawyer});
  final LawyerSummary lawyer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LawyerProfileScreen(lawyer: lawyer))),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightStroke)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LawyerAvatar(name: lawyer.name, photoUrl: lawyer.photoUrl, online: lawyer.online, radius: 20),
            const SizedBox(height: 8),
            LawyerChannels(lawyer: lawyer),
            const SizedBox(height: 10),
            Text(lawyer.name, style: AppText.bodyMedium(AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(lawyer.category, style: AppText.caption(AppColors.textGray), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            PriceTag(ratePerMinute: lawyer.ratePerMinute),
            const Spacer(),
            Row(children: [
              Expanded(child: _MiniAction(label: 'Chat', icon: Icons.chat_bubble_outline, dark: false, onTap: lawyer.chatOnline ? () => requestLawyer(context, lawyer) : null)),
              const SizedBox(width: 6),
              Expanded(child: _MiniAction(label: 'Call', icon: Icons.call, dark: true, onTap: lawyer.callOnline ? () => requestLawyer(context, lawyer, call: true) : null)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.icon, required this.dark, this.onTap});
  final String label;
  final IconData icon;
  final bool dark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = !enabled ? AppColors.lightSurface : dark ? AppColors.navyDeep : AppColors.lightSurface;
    final fg = !enabled ? AppColors.textGraySoft : dark ? Colors.white : AppColors.textDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: AppText.caption(fg).copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.textDark),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: AppText.caption(AppColors.textGray)),
      ],
    );
  }
}
