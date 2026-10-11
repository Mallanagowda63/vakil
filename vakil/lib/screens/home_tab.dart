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
const _pageBg = Color(0xFFF6F7FB);
const _navy = Color(0xFF0B1130);
const _blue = Color(0xFF3B82F6);
const _blueTint = Color(0xFFEAF2FE);
const _stroke = Color(0xFFE4E7EE);

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _pageBg,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppLogo(width: 112),
                  const Spacer(),
                  _CircleButton(
                    icon: Icons.search,
                    filled: false,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LawyerSearchScreen())),
                  ),
                  const SizedBox(width: 12),
                  _CircleButton(
                    icon: Icons.credit_card,
                    filled: true,
                    onTap: () => openWallet(context),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _Specialties(),
              const SizedBox(height: 16),
              const _HeroBanner(),
              const SizedBox(height: 14),
              const _SaathiCard(),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => HomeNav.openLawyers(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _blueTint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('View all', style: AppText.caption(AppColors.textDark).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: _blue),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _FeaturedLawyers(),
              const SizedBox(height: 22),
              Text('Trust essentials', style: AppText.h3(AppColors.textDark).copyWith(fontSize: 19)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _stroke),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TrustItem(icon: Icons.shield_outlined, label: 'Private &\nConfidential', color: _blue)),
                    Expanded(child: _TrustItem(icon: Icons.balance, label: 'Verified Lawyer', color: AppColors.greenAccent)),
                    Expanded(child: _TrustItem(icon: Icons.work_outline, label: 'Secure Payment', color: AppColors.gold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.filled, required this.onTap});
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFFE6E9F0) : Colors.white,
      shape: CircleBorder(side: filled ? BorderSide.none : const BorderSide(color: _stroke)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 21, color: filled ? AppColors.textDark : AppColors.textGray)),
      ),
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
    final chips = [for (final s in _specialties) _SpecialtyChip(data: s)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Browse by specialty', style: AppText.h3(AppColors.textDark).copyWith(fontSize: 19))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(children: [
                Text(_expanded ? 'See less' : 'See all', style: AppText.bodyMedium(_blue)),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: _blue),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_expanded)
          Wrap(spacing: 8, runSpacing: 8, children: chips)
        else
          SizedBox(
            height: 38,
            child: ListView.separated(
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
  const _SpecialtyChip({required this.data});
  final _SpecialtyChipData data;

  @override
  Widget build(BuildContext context) {
    // Opens the Lawyers tab filtered to this speciality.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _stroke)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => HomeNav.openLawyers(data.speciality),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(data.icon, size: 17, color: _blue),
            const SizedBox(width: 7),
            Text(data.label, style: AppText.body(AppColors.textDark).copyWith(fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalHelpStartScreen())),
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -18,
              child: Icon(Icons.balance, size: 110, color: Colors.white.withValues(alpha: 0.07)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Your Rights, Our Priority', style: AppText.h3(Colors.white)),
                const SizedBox(height: 4),
                Text('Expert legal advice by chat, call or AI.', style: AppText.caption(Colors.white.withValues(alpha: 0.75))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Get Started', style: AppText.caption(Colors.white).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 13, color: Colors.white),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SaathiCard extends StatelessWidget {
  const _SaathiCard();

  @override
  Widget build(BuildContext context) {
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegalSaathiScreen()));
    return GestureDetector(
      onTap: open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Legal Saathi AI agent', style: AppText.h3(Colors.white).copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('Ask Vakil for quick legal guidance, summaries, and next steps.',
                      style: AppText.caption(Colors.white.withValues(alpha: 0.8)).copyWith(height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: open,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Open', style: AppText.bodySmall(AppColors.textDark).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 15, color: AppColors.textDark),
                ]),
              ),
            ),
          ],
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
  static const _cardWidth = 150.0, _gap = 12.0;
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
          height: 156,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: lawyers.length,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, i) => SizedBox(width: _cardWidth, child: _FeaturedLawyerCard(lawyer: lawyers[i])),
          ),
        ),
        if (lawyers.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(lawyers.length, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: i == active ? _blue : const Color(0xFFD5D9E2), shape: BoxShape.circle),
                )),
          ),
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
    // Chat when the lawyer takes chats, else Call; disabled while offline.
    final call = !lawyer.chatOnline && lawyer.callOnline;
    final onPressed = lawyer.online ? () => requestLawyer(context, lawyer, call: call) : null;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LawyerProfileScreen(lawyer: lawyer))),
      child: Container(
        padding: const EdgeInsets.all(10),
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
                      _Pill(text: _shortCategory(lawyer.category), fg: AppColors.textGray, bg: AppColors.lightSurface, border: _stroke),
                      const SizedBox(height: 5),
                      Text(lawyer.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: AppText.caption(AppColors.textDark).copyWith(fontWeight: FontWeight.w700, height: 1.25)),
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
              _Pill(bold: '${lawyer.consultationsDone}', text: ' Completed', fg: AppColors.textGray, bg: Colors.white, border: _stroke),
            ]),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: AppColors.lightSurface,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(call ? 'Call' : 'Chat',
                    style: AppText.bodyMedium(onPressed == null ? AppColors.textGraySoft : Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Criminal Law" → "Criminal", so the tag fits the card.
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
    final initial = Center(child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(), style: AppText.h3(AppColors.blueAccent)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 50,
        color: AppColors.blueSoft,
        child: url == null ? initial : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
      ),
    );
  }
}

/// A small rounded tag on the lawyer card (category, rating, Live, completed).
class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.fg, required this.bg, required this.border, this.icon, this.iconColor, this.dot, this.bold});
  final String text;
  final Color fg, bg, border;
  final IconData? icon;
  final Color? iconColor;
  final Color? dot;
  final String? bold;

  @override
  Widget build(BuildContext context) {
    final style = AppText.caption(fg).copyWith(fontSize: 9.5, height: 1.2, fontWeight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: iconColor), const SizedBox(width: 2)],
        if (dot != null) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 3)],
        if (bold != null) Text(bold!, style: style.copyWith(color: AppColors.textDark, fontWeight: FontWeight.w800)),
        Text(text, style: style),
      ]),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: AppText.caption(AppColors.textDark).copyWith(fontWeight: FontWeight.w600, height: 1.25)),
      ],
    );
  }
}
