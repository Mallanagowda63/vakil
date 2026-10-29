import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../services/consultation_service.dart';
import '../services/realtime_service.dart';
import '../state/home_nav.dart';
import '../widgets/app_logo.dart';
import '../widgets/wallet_widgets.dart';
import 'lawyers_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'lawyer_profile_screen.dart';
import 'lawyer_search_screen.dart';
import 'legal_help_start_screen.dart';
import 'legal_saathi_screen.dart';

// Colours of the home design (Legally Talk).
const _pageTop = Color(0xFFE8EFFD);
const _pageBg = Color(0xFFF6F7FB);
const _navy = Color(0xFF0B1130);
const _blue = Color(0xFF3B82F6);
const _blueTint = Color(0xFFEAF2FE);
const _stroke = Color(0xFFE4E7EE);
const _dotOff = Color(0xFFD5D9E2);

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_pageTop, _pageBg], stops: [0, 0.35]),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const AppLogo(width: 112),
                    const Spacer(),
                    _CircleButton(
                      icon: Icons.search,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LawyerSearchScreen())),
                    ),
                    const SizedBox(width: 10),
                    _CircleButton(icon: Icons.account_balance_wallet_outlined, onTap: () => openWallet(context)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _HeroCarousel(),
              const SizedBox(height: 20),
              const _Specialties(),
              const SizedBox(height: 22),
              _SectionTitle('Offers for you', action: 'View all', onAction: () => HomeNav.openLawyers()),
              const SizedBox(height: 12),
              const _Offers(),
              const SizedBox(height: 18),
              const _MissionTicker(),
              const SizedBox(height: 18),
              const _SectionTitle('Choose how to connect'),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                    child: _ConnectCard(
                      icon: Icons.chat_bubble_outline,
                      color: _blue,
                      title: 'Chat',
                      subtitle: 'Quick answers in real time',
                      onTap: () => HomeNav.openLawyers(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ConnectCard(
                      icon: Icons.auto_awesome,
                      color: AppColors.aiCardStart,
                      title: 'Ask AI',
                      subtitle: 'Instant guidance from Legal Saathi',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalSaathiScreen())),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              _SectionTitle('Top lawyers online', action: 'View all', onAction: () => HomeNav.openLawyers()),
              const SizedBox(height: 12),
              const _FeaturedLawyers(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(side: BorderSide(color: _stroke)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: AppColors.textDark)),
      ),
    );
  }
}

/// A section heading with an optional "View all ›" link.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.h3(AppColors.textDark).copyWith(fontSize: 19))),
        if (action != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Row(children: [
              Text(action!, style: AppText.bodyMedium(_blue)),
              const Icon(Icons.chevron_right, size: 18, color: _blue),
            ]),
          ),
      ]),
    );
  }
}

/// Page dots under a carousel; the current one is a wider pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count, active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == active ? _blue : _dotOff, borderRadius: BorderRadius.circular(3)),
          )),
    );
  }
}

class _HeroData {
  const _HeroData({required this.tag, required this.title, required this.subtitle, required this.button, required this.icon, required this.colors, required this.open});
  final String tag, title, subtitle, button;
  final IconData icon;
  final List<Color> colors;
  final void Function(BuildContext) open;
}

final _heroes = [
  _HeroData(
    tag: 'PROPERTY CHECK',
    title: 'Buying a home? Verify first',
    subtitle: 'Title and document review by property lawyers.',
    button: 'Book a review',
    icon: Icons.home_work_outlined,
    colors: const [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
    open: (_) => HomeNav.openLawyers(Speciality.realEstate),
  ),
  _HeroData(
    tag: 'FIRST CHAT OFFER',
    title: 'First minute on us',
    subtitle: 'Chat with a verified lawyer in under 2 minutes.',
    button: 'Start chat',
    icon: Icons.mark_chat_read_outlined,
    colors: const [Color(0xFF16A34A), Color(0xFF065F46)],
    open: (context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalHelpStartScreen())),
  ),
  _HeroData(
    tag: 'NEW · LEGAL SAATHI AI',
    title: 'Ask Vakil, 24×7',
    subtitle: 'Instant AI answers on rent, FIR, divorce and more. Then talk to a real lawyer.',
    button: 'Try it now',
    icon: Icons.auto_awesome,
    colors: const [Color(0xFF2563EB), Color(0xFF1E3A8A)],
    open: (context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalSaathiScreen())),
  ),
];

/// The big banner at the top: swipeable, moves on by itself every few seconds.
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _pages = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pages.hasClients) _pages.animateToPage((_page + 1) % _heroes.length, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 178,
        child: PageView.builder(
          controller: _pages,
          itemCount: _heroes.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _HeroCard(data: _heroes[i])),
        ),
      ),
      const SizedBox(height: 10),
      _Dots(count: _heroes.length, active: _page),
    ]);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data});
  final _HeroData data;

  @override
  Widget build(BuildContext context) {
    final translucent = Colors.white.withValues(alpha: 0.16);
    return GestureDetector(
      onTap: () => data.open(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.colors),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: data.colors.last.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: -50, top: -30, child: _Glow(size: 190, alpha: 0.10)),
          Positioned(
            right: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: translucent, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                child: Icon(data.icon, color: Colors.white, size: 28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 92, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tag(data.tag, background: translucent),
                const SizedBox(height: 8),
                Text(data.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h3(Colors.white).copyWith(fontSize: 21, height: 1.15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(data.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption(Colors.white.withValues(alpha: 0.85)).copyWith(height: 1.3)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: translucent, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(data.button, style: AppText.caption(Colors.white).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// A soft white circle used as decoration on the coloured cards.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});
  final double size, alpha;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white.withValues(alpha: alpha), shape: BoxShape.circle));
}

/// Small upper-case label on a coloured card ("PROPERTY CHECK", "TAX").
class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.background});
  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
      child: Text(text, style: AppText.caption(Colors.white).copyWith(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
    );
  }
}

class _SpecialtyChipData {
  const _SpecialtyChipData(this.speciality, this.icon, this.label);
  final Speciality speciality;
  final IconData icon;
  final String label;
}

const _specialties = [
  _SpecialtyChipData(Speciality.all, Icons.balance, 'Legal Specialist'),
  _SpecialtyChipData(Speciality.criminal, Icons.shield_outlined, 'Criminal'),
  _SpecialtyChipData(Speciality.family, Icons.diversity_1, 'Family'),
  _SpecialtyChipData(Speciality.business, Icons.business_center_outlined, 'Business'),
  _SpecialtyChipData(Speciality.realEstate, Icons.home_outlined, 'Real Estate'),
  _SpecialtyChipData(Speciality.medical, Icons.medical_services_outlined, 'Medical'),
];

/// "Browse by specialty": one scrolling row of chips; "See all" shows them all.
class _Specialties extends StatefulWidget {
  const _Specialties();
  @override
  State<_Specialties> createState() => _SpecialtiesState();
}

class _SpecialtiesState extends State<_Specialties> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final chips = [for (final s in _specialties) _SpecialtyChip(data: s, highlighted: s.speciality == Speciality.all)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('Browse by specialty', action: _expanded ? 'See less' : 'See all', onAction: () => setState(() => _expanded = !_expanded)),
        const SizedBox(height: 12),
        if (_expanded)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Wrap(spacing: 8, runSpacing: 8, children: chips))
        else
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => chips[i],
            ),
          ),
      ],
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.data, this.highlighted = false});
  final _SpecialtyChipData data;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? Colors.white : AppColors.textDark;
    // Opens the Lawyers tab filtered to this speciality.
    return Material(
      color: highlighted ? _blue : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: highlighted ? BorderSide.none : const BorderSide(color: _stroke)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => HomeNav.openLawyers(data.speciality),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(data.icon, size: 16, color: highlighted ? Colors.white : _blue),
            const SizedBox(width: 7),
            Text(data.label, style: AppText.body(fg).copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _OfferData {
  const _OfferData(this.tag, this.title, this.subtitle, this.colors, this.speciality);
  final String tag, title, subtitle;
  final List<Color> colors;
  final Speciality speciality;
}

const _offers = [
  _OfferData('TENANCY', 'Rent rules differ by state', 'Check what applies to you before you sign.', [Color(0xFF1E3A8A), Color(0xFF0B1130)], Speciality.realEstate),
  _OfferData('TAX', 'Got a GST notice?', 'Know your next step before you reply.', [Color(0xFF15803D), Color(0xFF064E3B)], Speciality.business),
  _OfferData('FAMILY', 'Divorce or custody questions?', 'Talk privately to a family lawyer.', [Color(0xFFBE185D), Color(0xFF6B1238)], Speciality.family),
];

/// "Offers for you": a row of smaller coloured cards, each opening its lawyers.
class _Offers extends StatefulWidget {
  const _Offers();
  @override
  State<_Offers> createState() => _OffersState();
}

class _OffersState extends State<_Offers> {
  final _pages = PageController(viewportFraction: 0.82);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 140,
        child: PageView.builder(
          controller: _pages,
          padEnds: false,
          itemCount: _offers.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => Padding(
            padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
            child: _OfferCard(data: _offers[i]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _Dots(count: _offers.length, active: _page),
    ]);
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.data});
  final _OfferData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HomeNav.openLawyers(data.speciality),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: data.colors),
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(right: -40, top: -40, child: _Glow(size: 150, alpha: 0.12)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tag(data.tag, background: Colors.white.withValues(alpha: 0.14)),
                const SizedBox(height: 6),
                Text(data.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.h3(Colors.white).copyWith(fontSize: 17, height: 1.15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(Colors.white.withValues(alpha: 0.8))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Ask a Lawyer', style: AppText.caption(_navy).copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
                    const SizedBox(width: 3),
                    const Icon(Icons.chevron_right, size: 14, color: _navy),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// A dark strip with the app's promises scrolling past, like a news ticker.
class _MissionTicker extends StatefulWidget {
  const _MissionTicker();
  @override
  State<_MissionTicker> createState() => _MissionTickerState();
}

class _MissionTickerState extends State<_MissionTicker> with SingleTickerProviderStateMixin {
  static const _items = [
    (Icons.flag_outlined, 'Our Mission.'),
    (Icons.verified_user_outlined, 'Trust Is Our Promise.'),
    (Icons.lock_outline, 'Privacy Is Our Mission.'),
    (Icons.balance, 'Verified Lawyers Only.'),
  ];
  static const _pixelsPerSecond = 32.0;
  final _scroll = ScrollController();
  late final _ticker = createTicker((elapsed) {
    if (_scroll.hasClients) _scroll.jumpTo(elapsed.inMilliseconds / 1000 * _pixelsPerSecond);
  });

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      color: _navy,
      // Endless list: item i repeats the promises in order.
      child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, i) {
          final (icon, text) = _items[i % _items.length];
          return Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Row(children: [
              Icon(icon, size: 13, color: Colors.white70),
              const SizedBox(width: 6),
              Text(text, style: AppText.caption(Colors.white).copyWith(fontWeight: FontWeight.w700)),
            ]),
          );
        },
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _stroke)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.textGray),
              ]),
              const SizedBox(height: 14),
              Text(title, style: AppText.h3(AppColors.textDark).copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, style: AppText.caption(AppColors.textGray).copyWith(height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lawyers from the server, online first, in a swipeable row with page dots.
class _FeaturedLawyers extends StatefulWidget {
  const _FeaturedLawyers();
  @override
  State<_FeaturedLawyers> createState() => _FeaturedLawyersState();
}

class _FeaturedLawyersState extends State<_FeaturedLawyers> {
  static const _cardWidth = 160.0, _gap = 12.0;
  final _service = ConsultationService();
  final _scroll = ScrollController();
  StreamSubscription<SocketEvent>? _events;
  Timer? _debounce;
  List<LawyerSummary>? _lawyers;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final page = (_scroll.offset / (_cardWidth + _gap)).round();
      if (page != _page) setState(() => _page = page);
    });
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
    _scroll.dispose();
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
    if (lawyers == null) return const SizedBox(height: 170, child: Center(child: CircularProgressIndicator()));
    if (lawyers.isEmpty) return SizedBox(height: 60, child: Center(child: Text('No lawyers available right now.', style: AppText.bodySmall(AppColors.textGray))));
    final active = _page.clamp(0, lawyers.length - 1);
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: lawyers.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) => SizedBox(width: _cardWidth, child: _FeaturedLawyerCard(lawyer: lawyers[i])),
          ),
        ),
        if (lawyers.length > 1) ...[
          const SizedBox(height: 12),
          _Dots(count: lawyers.length, active: active),
        ],
      ],
    );
  }
}

class _FeaturedLawyerCard extends StatelessWidget {
  const _FeaturedLawyerCard({required this.lawyer});
  final LawyerSummary lawyer;

  @override
  Widget build(BuildContext context) {
    // Voice calls are hidden for now, so the card only offers Chat.
    final onPressed = lawyer.online && lawyer.chatOnline ? () => requestLawyer(context, lawyer) : null;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LawyerProfileScreen(lawyer: lawyer))),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _stroke),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SquarePhoto(name: lawyer.name, photoUrl: lawyer.photoUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_shortCategory(lawyer.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(AppColors.textGray).copyWith(fontSize: 10.5)),
                      const SizedBox(height: 2),
                      Text(lawyer.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppText.caption(AppColors.textDark).copyWith(fontWeight: FontWeight.w800, fontSize: 13, height: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 5, children: [
              if (lawyer.ratingAverage != null)
                _Pill(icon: Icons.star_rounded, iconColor: AppColors.starGold, text: lawyer.ratingAverage!.toStringAsFixed(1), fg: AppColors.textDark, bg: AppColors.goldSoft, border: AppColors.gold.withValues(alpha: 0.5)),
              lawyer.online
                  ? _Pill(dot: AppColors.greenAccent, text: 'Live', fg: AppColors.greenAccent, bg: const Color(0xFFE6F7EE), border: AppColors.greenAccent.withValues(alpha: 0.35))
                  : _Pill(dot: AppColors.textGraySoft, text: 'Offline', fg: AppColors.textGray, bg: AppColors.lightSurface, border: _stroke),
            ]),
            const SizedBox(height: 6),
            Text('${lawyer.consultationsDone} done', style: AppText.caption(AppColors.textGray).copyWith(fontSize: 11)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.chat_bubble_outline, size: 14),
                label: const Text('Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.lightSurface,
                  disabledForegroundColor: AppColors.textGraySoft,
                  textStyle: AppText.bodyMedium(Colors.white),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Criminal Law" → "Criminal", so the label fits the card.
  static String _shortCategory(String category) => category.replaceAll(RegExp(r'\s+Law$', caseSensitive: false), '');
}

/// The lawyer's photo in a rounded square (initials until it loads).
class _SquarePhoto extends StatelessWidget {
  const _SquarePhoto({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.mediaUrl(photoUrl);
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = Center(child: Text(initials.isEmpty ? '?' : initials, style: AppText.h3(_blue).copyWith(fontSize: 16)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        color: _blueTint,
        child: url == null ? fallback : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}

/// A small rounded tag on the lawyer card (rating, Live).
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fg, required this.bg, required this.border, this.icon, this.iconColor, this.dot});
  final String text;
  final Color fg, bg, border;
  final IconData? icon;
  final Color? iconColor;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption(fg).copyWith(fontSize: 10, height: 1.2, fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: iconColor), const SizedBox(width: 2)],
        if (dot != null) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 3)],
        Text(text, style: style),
      ]),
    );
  }
}
