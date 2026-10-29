import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../theme/app_theme.dart';
import 'consultation_summary_screen.dart';
import 'dashboard_screen.dart';

/// The first thing a lawyer sees when a chat ends: a thank-you with what this
/// chat earned and how today is going, so finishing a consultation feels good.
/// The full breakdown (charges, feedback, report) is one tap away.
class SessionThanksScreen extends StatefulWidget {
  const SessionThanksScreen({super.key, required this.requestId, required this.clientName});
  final String requestId;
  final String clientName;

  @override
  State<SessionThanksScreen> createState() => _SessionThanksScreenState();
}

class _SessionThanksScreenState extends State<SessionThanksScreen> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  final _service = PartnerConsultationService();

  double? _earned;
  bool _trial = false;
  int? _minutes;
  Map<String, dynamic>? _today;
  String _name = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _intro.dispose();
    _confetti.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      final results = await Future.wait([_service.getRequest(widget.requestId, token), _service.earnings(token), _service.profile(token)]);
      if (!mounted) return;
      final request = Map<String, dynamic>.from(results[0]['request'] as Map? ?? const {});
      final earning = results[0]['earning'] == null ? null : Map<String, dynamic>.from(results[0]['earning'] as Map);
      setState(() {
        _trial = request['isTrial'] == true;
        _earned = (earning?['amount'] as num?)?.toDouble() ?? 0;
        _minutes = (((request['durationSeconds'] as num?) ?? 0) / 60).ceil();
        _name = results[2]['fullName']?.toString() ?? '';
        _today = results[1]['today'] == null ? null : Map<String, dynamic>.from(results[1]['today'] as Map);
      });
    } catch (_) {
      // The thank-you still shows; only the numbers are missing.
      if (mounted) setState(() => _earned ??= 0);
    }
  }

  String get _firstName {
    final name = _name.trim();
    return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  }

  String get _todayLine {
    final count = (_today?['consultations'] as num?)?.toInt() ?? 0;
    if (count <= 1) return 'Your first consultation today. Good start.';
    if (count < 5) return "That's $count consultations today. Keep the momentum going.";
    return "$count consultations today. You're having a great day.";
  }

  void _toDashboard() => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const DashboardScreen()), (route) => false);

  void _details() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ConsultationSummaryScreen(requestId: widget.requestId, clientName: widget.clientName)));

  /// Fades and slides a block in, starting [at] (0–1) through the intro.
  Widget _reveal(double at, Widget child) {
    final curve = CurvedAnimation(parent: _intro, curve: Interval(at, math.min(1, at + 0.35), curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) => Opacity(opacity: curve.value, child: Transform.translate(offset: Offset(0, 24 * (1 - curve.value)), child: child)),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hello = _firstName.isEmpty ? 'Thank you' : 'Thank you, $_firstName';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _toDashboard(); },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E1B4D), Color(0xFF1D3FAE), Color(0xFF2454E0)]),
          ),
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _confetti, builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_confetti.value))))),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 36, 22, 24),
                child: Column(children: [
                  _Badge(intro: _intro, pulse: _pulse),
                  const SizedBox(height: 26),
                  _reveal(0.25, Text(hello, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 8),
                  _reveal(0.32, Text(
                    'You just helped ${widget.clientName} with their legal question. That matters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14.5, height: 1.4),
                  )),
                  const SizedBox(height: 28),
                  _reveal(0.45, _EarnedCard(earned: _earned, trial: _trial, minutes: _minutes, animation: _intro)),
                  const SizedBox(height: 14),
                  if (_today != null) _reveal(0.6, _TodayCard(today: _today!, line: _todayLine)),
                  const SizedBox(height: 14),
                  _reveal(0.7, Row(children: [
                    Icon(Icons.trending_up_rounded, size: 18, color: Colors.white.withValues(alpha: 0.75)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Lawyers who are online show first to clients. Stay online to get the next request.', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5, height: 1.35))),
                  ])),
                  const SizedBox(height: 28),
                  _reveal(0.8, SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _toDashboard,
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Ready for the next client', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  )),
                  const SizedBox(height: 6),
                  _reveal(0.85, TextButton(
                    onPressed: _details,
                    child: Text('See session details & feedback', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  )),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A white circle with a tick that pops in, with soft rings pulsing out.
class _Badge extends StatelessWidget {
  const _Badge({required this.intro, required this.pulse});
  final Animation<double> intro, pulse;

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(parent: intro, curve: const Interval(0, 0.45, curve: Curves.elasticOut));
    final tick = CurvedAnimation(parent: intro, curve: const Interval(0.2, 0.55, curve: Curves.easeOut));
    return SizedBox(
      width: 150,
      height: 150,
      child: AnimatedBuilder(
        animation: Listenable.merge([pop, tick, pulse]),
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          for (final offset in [0.0, 0.5])
            Builder(builder: (_) {
              final t = (pulse.value + offset) % 1;
              return Container(
                width: 96 + 54 * t,
                height: 96 + 54 * t,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35 * (1 - t)), width: 2)),
              );
            }),
          Transform.scale(
            scale: pop.value,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))]),
              child: CustomPaint(painter: _TickPainter(tick.value)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.71, size.height * 0.37);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = AppColors.success
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}

/// Paper pieces bursting up from the badge and drifting down.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  static const _colors = [Color(0xFFFFC94D), Color(0xFF4ADE80), Color(0xFFF472B6), Color(0xFF60A5FA), Colors.white];
  static final _pieces = List.generate(60, (i) {
    final r = math.Random(i * 7919);
    return (angle: -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.4, speed: 260 + r.nextDouble() * 320, spin: (r.nextDouble() - 0.5) * 14, size: 5 + r.nextDouble() * 6, color: _colors[i % _colors.length]);
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final origin = Offset(size.width / 2, 36 + 75 + MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).padding.top);
    final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    for (final p in _pieces) {
      final time = t * 2.2;
      final position = origin + Offset(math.cos(p.angle) * p.speed * time, math.sin(p.angle) * p.speed * time + 380 * time * time);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(p.spin * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), Paint()..color = p.color.withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _EarnedCard extends StatelessWidget {
  const _EarnedCard({required this.earned, required this.trial, required this.minutes, required this.animation});
  final double? earned;
  final bool trial;
  final int? minutes;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final count = CurvedAnimation(parent: animation, curve: const Interval(0.45, 1, curve: Curves.easeOutCubic));
    final freeTrial = trial && (earned ?? 0) == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
      child: Column(children: [
        Text(freeTrial ? 'FREE TRIAL CHAT' : 'YOU EARNED', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 6),
        if (earned == null)
          const SizedBox(height: 44, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
        else if (freeTrial)
          const Text('First impression made', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))
        else
          AnimatedBuilder(
            animation: count,
            builder: (_, __) => Text('₹${(earned! * count.value).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
          ),
        const SizedBox(height: 4),
        Text(
          freeTrial ? 'Clients who like their free minute come back for paid chats.' : minutes == null || minutes == 0 ? 'Added to your wallet' : 'For $minutes min · added to your wallet',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
        ),
      ]),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.line});
  final Map<String, dynamic> today;
  final String line;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          ]),
        );
    final earnings = (today['earnings'] as num?)?.toDouble() ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('TODAY', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(line, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(children: [
          stat('${(today['consultations'] as num?)?.toInt() ?? 0}', 'Consultations'),
          Container(width: 1, height: 30, color: AppColors.border),
          stat('${(today['minutes'] as num?)?.toInt() ?? 0}', 'Minutes'),
          Container(width: 1, height: 30, color: AppColors.border),
          stat('₹${earnings % 1 == 0 ? earnings.toInt() : earnings.toStringAsFixed(2)}', 'Earned'),
        ]),
      ]),
    );
  }
}
