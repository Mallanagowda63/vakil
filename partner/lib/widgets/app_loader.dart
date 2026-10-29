import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// Loading indicators shared by the User App and the Partner App (keep both
// copies of this file identical): a swinging scale of justice with a quote
// for whole screens, and three bouncing dots for small spaces and buttons.

/// Short legal quotes and facts shown while a screen loads.
const loadingQuotes = [
  ('Injustice anywhere is a threat to justice everywhere.', 'Martin Luther King Jr.'),
  ('Satyameva Jayate: truth alone triumphs.', 'Mundaka Upanishad'),
  ('Be you never so high, the law is above you.', 'Thomas Fuller'),
  ('Wherever law ends, tyranny begins.', 'John Locke'),
  ('The Constitution is not a mere lawyers\' document; it is a vehicle of life.', 'Dr. B. R. Ambedkar'),
  ('It is better that ten guilty persons escape than that one innocent suffer.', 'William Blackstone'),
  ('Equal justice and free legal aid are part of the Constitution of India.', 'Article 39A'),
  ('Justice delayed is justice denied.', 'Legal maxim'),
  ('Knowing your rights is the first step to protecting them.', 'Legally Talk'),
];

/// Fills the space it is given: the swinging scale, dots and a quote that
/// changes every few seconds. [compact] leaves out the quote (short spaces).
class PageLoader extends StatefulWidget {
  const PageLoader({super.key, this.compact = false, this.color, this.message});
  final bool compact;
  final Color? color;
  /// Shown above the quote, e.g. "Connecting to the server".
  final String? message;

  @override
  State<PageLoader> createState() => _PageLoaderState();
}

class _PageLoaderState extends State<PageLoader> with SingleTickerProviderStateMixin {
  late final _swing = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  Timer? _next;
  late int _quote = math.Random().nextInt(loadingQuotes.length);

  @override
  void initState() {
    super.initState();
    if (!widget.compact) _next = Timer.periodic(const Duration(milliseconds: 3800), (_) => setState(() => _quote = (_quote + 1) % loadingQuotes.length));
  }

  @override
  void dispose() {
    _next?.cancel();
    _swing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final (text, author) = loadingQuotes[_quote];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _swing,
            builder: (_, child) => Transform.rotate(angle: (Curves.easeInOut.transform(_swing.value) - 0.5) * 0.35, child: child),
            child: Container(
              width: widget.compact ? 44 : 60,
              height: widget.compact ? 44 : 60,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.balance_rounded, color: color, size: widget.compact ? 24 : 32),
            ),
          ),
          const SizedBox(height: 12),
          DotsLoader(color: color),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            Text(widget.message!, textAlign: TextAlign.center, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
          if (!widget.compact) ...[
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Column(key: ValueKey(_quote), mainAxisSize: MainAxisSize.min, children: [
                Text('"$text"', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF4B5563), height: 1.4)),
                const SizedBox(height: 6),
                Text('- $author', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Three dots bouncing in turn; fits inside buttons and small boxes.
class DotsLoader extends StatefulWidget {
  const DotsLoader({super.key, this.color, this.size = 8});
  final Color? color;
  final double size;

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Builder(builder: (_) {
              final t = (_controller.value - i * 0.18) % 1;
              final lift = t < 0.5 ? math.sin(t * 2 * math.pi) : 0.0;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
                child: Transform.translate(
                  offset: Offset(0, -lift.abs() * widget.size * 0.9),
                  child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: color.withValues(alpha: 0.45 + 0.55 * lift.abs()), shape: BoxShape.circle)),
                ),
              );
            }),
        ]),
      ),
    );
  }
}
