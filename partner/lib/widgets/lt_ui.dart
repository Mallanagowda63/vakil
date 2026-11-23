import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'app_loader.dart';

// Building blocks of the Legally Talk Partner design: cards, section heads,
// pills, chips and the bottom sheet. Colours come from LT (light / dark).

TextStyle sora(double size, {FontWeight weight = FontWeight.w600, Color? color, double? letterSpacing}) =>
    GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

TextStyle mono(double size, {Color? color}) => GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: FontWeight.w500, color: color, letterSpacing: 0.3);

String inr(num v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toInt().toString() : v.toStringAsFixed(2);
  // Indian grouping: 12,34,567
  final parts = s.split('.');
  var n = parts[0];
  final neg = n.startsWith('-');
  if (neg) n = n.substring(1);
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final groups = <String>[];
    while (rest.length > 2) { groups.insert(0, rest.substring(rest.length - 2)); rest = rest.substring(0, rest.length - 2); }
    if (rest.isNotEmpty) groups.insert(0, rest);
    n = '${groups.join(',')},$last3';
  }
  return '${neg ? '−' : ''}₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

class LtCard extends StatelessWidget {
  const LtCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: const Color(0xFF0E2C28).withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600, color: color ?? LT.of(context).muted));
}

/// "EARNINGS ……… View ledger →"
class SecHead extends StatelessWidget {
  const SecHead(this.title, {super.key, this.action, this.onAction, this.trailing});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Row(children: [
          Expanded(child: Eyebrow(title)),
          if (trailing != null) trailing!,
          if (action != null) LinkButton(action!, onTap: onAction),
        ]),
      );
}

class LinkButton extends StatelessWidget {
  const LinkButton(this.label, {super.key, this.onTap, this.arrow = true});
  final String label;
  final VoidCallback? onTap;
  final bool arrow;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(color: c.brand, fontWeight: FontWeight.w600, fontSize: 13)),
        if (arrow) ...[const SizedBox(width: 4), Icon(Icons.arrow_forward, size: 15, color: c.brand)],
      ]),
    );
  }
}

/// Rounded square with a client's initials (or photo).
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 42, this.highlight = false, this.icon, this.iconColor, this.iconBg});
  final String name;
  final double size;
  final bool highlight;
  final IconData? icon;
  final Color? iconColor, iconBg;

  static String of(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: iconBg ?? (highlight ? c.brand : c.surface2), borderRadius: BorderRadius.circular(size * 0.31)),
      child: icon != null
          ? Icon(icon, size: size * 0.45, color: iconColor ?? c.brand)
          : Text(of(name), style: sora(size * 0.33, weight: FontWeight.w700, color: highlight ? c.brandInk : c.ink)),
    );
  }
}

enum ChipTone { good, bad, wait, brand, muted }

class StateChip extends StatelessWidget {
  const StateChip(this.text, {super.key, this.tone = ChipTone.good, this.icon, this.onTap});
  final String text;
  final ChipTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final (bg, fg) = switch (tone) {
      ChipTone.good => (c.goodSoft, c.good),
      ChipTone.bad => (c.badSoft, c.bad),
      ChipTone.wait => (c.goldSoft, c.gold),
      ChipTone.brand => (c.brandSoft, c.brand),
      ChipTone.muted => (c.surface2, c.muted),
    };
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
    return onTap == null ? chip : GestureDetector(onTap: onTap, child: chip);
  }
}

enum BtnKind { primary, ghost, gold }

class LtButton extends StatelessWidget {
  const LtButton(this.label, {super.key, required this.onTap, this.kind = BtnKind.primary, this.icon, this.loading = false, this.height = 46});
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final IconData? icon;
  final bool loading;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final (bg, fg) = switch (kind) {
      BtnKind.primary => (c.brand, c.brandInk),
      BtnKind.ghost => (c.surface2, c.ink),
      BtnKind.gold => (c.gold, const Color(0xFF1D1404)),
    };
    return SizedBox(
      height: height,
      child: Material(
        color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: loading ? null : onTap,
          child: Center(
            child: loading
                ? DotsLoader(size: 6, color: fg)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 7)],
                    Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14))),
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Horizontal pills (Incoming 3 · Active 1 …) or law-category chips.
class PillBar<T> extends StatelessWidget {
  const PillBar({super.key, required this.items, required this.selected, required this.onSelected, this.dark = true});
  final List<({T value, String label, String? sub, int? count})> items;
  final T selected;
  final ValueChanged<T> onSelected;
  /// true: selected pill is dark (filters); false: brand-tinted (categories).
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return SizedBox(
      height: items.any((i) => i.sub != null) ? 50 : 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          final on = it.value == selected;
          final bg = on ? (dark ? c.nav : c.brandSoft) : c.surface;
          final fg = on ? (dark ? c.navOn : c.brand) : c.ink;
          return GestureDetector(
            onTap: () => onSelected(it.value),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 13, vertical: it.sub != null ? 7 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(it.sub != null ? 13 : 99), border: Border.all(color: on ? (dark ? c.nav : c.brand) : c.line)),
              child: it.sub != null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(it.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                      Text(it.sub!, style: TextStyle(fontSize: 10.5, color: on ? fg : c.muted)),
                    ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(it.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
                      if (it.count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.16) : c.surface2, borderRadius: BorderRadius.circular(99)),
                          child: Text('${it.count}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
                        ),
                      ],
                    ]),
            ),
          );
        },
      ),
    );
  }
}

/// The three-way segmented control (Consults · Chats · Session Book).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.items, required this.selected, required this.onSelected});
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final (value, label) in items)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: value == selected ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: value == selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                alignment: Alignment.center,
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: value == selected ? c.ink : c.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A list row: leading, title, subtitle, trailing.
class LtRow extends StatelessWidget {
  const LtRow({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.titleColor, this.first = false});
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: c.line))),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: titleColor ?? c.ink)),
            if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
          ])),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

/// Empty state inside a card.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, this.text = ''});
  final IconData icon;
  final String title, text;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return LtCard(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(children: [
        Icon(icon, size: 34, color: c.muted),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: sora(15, color: c.ink)),
        if (text.isNotEmpty) ...[const SizedBox(height: 4), Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted))],
      ]),
    );
  }
}

/// The design's bottom sheet: grab handle, title, close button, scrolling body.
Future<T?> showLtSheet<T>(BuildContext context, {required String title, String? eyebrow, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = LT.of(sheetContext);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88),
          decoration: BoxDecoration(color: c.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(9))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (eyebrow != null) Eyebrow(eyebrow),
                  Text(title, style: sora(19, color: c.ink)),
                ])),
                IconButton(onPressed: () => Navigator.pop(sheetContext), icon: Icon(Icons.close, color: c.ink)),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 24), child: builder(sheetContext))),
          ]),
        ),
      );
    },
  );
}

void toast(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 96)));
