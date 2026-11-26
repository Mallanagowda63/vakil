import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/law_points.dart';
import '../widgets/lt_ui.dart';

/// One row of the Law Book: an old section and where it is in the 2023 codes.
class LawBookRow {
  LawBookRow(Map<String, dynamic> j)
      : code = j['c'] as String,
        oldSection = j['o'] as String,
        oldTitle = j['ot'] as String,
        newSection = j['n'] as String,
        newText = j['nt'] as String,
        status = j['s'] as String,
        chapter = j['ch'] as String,
        important = j['i'] == 1,
        _search = '${j['o']} ${j['ot']} ${j['n']} ${j['nt']} ${j['ch']}'.toLowerCase();
  final String code, oldSection, oldTitle, newSection, newText, status, chapter;
  final bool important;
  final String _search;

  String get oldAct => switch (code) { 'IPC' => 'IPC', 'CrPC' => 'CrPC', _ => 'Evidence Act' };
  String get newAct => switch (code) { 'IPC' => 'BNS', 'CrPC' => 'BNSS', _ => 'BSA' };
  /// The new text when it says more than the section numbers.
  String get newWording => RegExp(r'[A-Za-z]{3}').hasMatch(newText) ? newText : '';
  String get shareText => oldSection.isEmpty
      ? '$newAct $newSection (new provision)'
      : newSection.isEmpty ? '$oldAct $oldSection — removed in the 2023 code' : '$oldAct $oldSection → $newAct $newSection';
}

/// The Law Book from Legally-Talk-Law-Book.xlsx (tool/law_book_to_json.py),
/// bundled in the app so it works offline.
class LawBook {
  LawBook._();
  static List<LawBookRow>? _rows;
  static String note = '', source = '';

  static Future<List<LawBookRow>> load() async {
    if (_rows != null) return _rows!;
    final data = jsonDecode(await rootBundle.loadString('assets/data/law_book.json')) as Map<String, dynamic>;
    note = data['note']?.toString() ?? '';
    source = data['source']?.toString() ?? '';
    return _rows = (data['rows'] as List).map((e) => LawBookRow(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Section numbers match first ("420" → IPC 420 before rows that only mention 420 in the text).
  static List<LawBookRow> search(List<LawBookRow> rows, String query, {String code = 'all', String filter = 'important'}) {
    var q = query.trim().toLowerCase().replaceAll(RegExp(r'^(section|sec\.?|s\.)\s*'), '');
    // An act name in front picks the code: "crpc 438", "ipc 420", "bns 318" (new section), "bsa 63".
    var byNew = false;
    final act = RegExp(r'^(ipc|crpc|cr\.p\.c\.?|evidence( act)?|iea|bnss|bns|bsa)\s*(section|sec\.?|s\.)?\s*').firstMatch(q);
    if (act != null) {
      final name = act.group(1)!;
      code = name.startsWith('ipc') || name == 'bns' ? 'IPC' : name.startsWith('cr') || name == 'bnss' ? 'CrPC' : 'IEA';
      byNew = name.startsWith('b');
      q = q.substring(act.end).trim();
    }
    Iterable<LawBookRow> list = rows.where((r) => code == 'all' || r.code == code);
    if (q.isEmpty) {
      list = switch (filter) {
        'important' => list.where((r) => r.important),
        'changed' => list.where((r) => r.status == 'Changed'),
        'new' => list.where((r) => r.status == 'New'),
        'removed' => list.where((r) => r.status == 'Deleted'),
        _ => list,
      };
      return list.toList();
    }
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    bool newMatch(String neu) => neu.split(RegExp(r',\s*')).any((n) => n == q || n.startsWith('$q('));
    int rank(LawBookRow r) {
      final old = r.oldSection.toLowerCase(), neu = r.newSection.toLowerCase();
      if (byNew ? newMatch(neu) : old == q) return 0;
      if (byNew ? old == q : newMatch(neu)) return 1;
      if (old.startsWith(q)) return 2;
      if (r.oldTitle.toLowerCase().contains(q)) return 3;
      return 4;
    }
    if (act != null && q.isEmpty) return list.where((r) => r.important).toList();
    final hits = list.where((r) => words.every(r._search.contains)).toList();
    hits.sort((a, b) => rank(a).compareTo(rank(b)));
    return hits;
  }
}

/// Law points: the Law Book (old → new sections, with search) and the quick guide by category.
class LawBookScreen extends StatefulWidget {
  const LawBookScreen({super.key, this.initialQuery = '', this.category = 'Criminal'});
  final String initialQuery;
  final String category;
  @override
  State<LawBookScreen> createState() => _LawBookScreenState();
}

class _LawBookScreenState extends State<LawBookScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  List<LawBookRow>? _rows;
  String _code = 'all', _filter = 'important';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    LawBook.load().then((rows) { if (mounted) setState(() => _rows = rows); });
  }

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        title: Text('Law points', style: sora(19, color: c.ink)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Segmented<int>(items: const [(0, 'Old → New sections'), (1, 'Quick guide')], selected: _tab, onSelected: (v) => setState(() => _tab = v)),
        ),
        Expanded(child: _tab == 0 ? _lawBook(c) : SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), child: LawPointsGuide(category: widget.category))),
      ]),
    );
  }

  Widget _lawBook(LT c) {
    final rows = _rows;
    if (rows == null) return const Center(child: Text('Loading…'));
    final results = LawBook.search(rows, _query.text, code: _code, filter: _filter);
    final searching = _query.text.trim().isNotEmpty;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search: 420, crpc 438, bns 318, cheating…',
            prefixIcon: Icon(Icons.search, color: c.muted),
            suffixIcon: searching ? IconButton(icon: Icon(Icons.close, color: c.muted), onPressed: () => setState(_query.clear)) : null,
            filled: true, fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.brand)),
          ),
        ),
      ),
      PillBar<String>(
        dark: false,
        items: const [
          (value: 'all', label: 'All codes', sub: null, count: null),
          (value: 'IPC', label: 'IPC → BNS', sub: null, count: null),
          (value: 'CrPC', label: 'CrPC → BNSS', sub: null, count: null),
          (value: 'IEA', label: 'Evidence → BSA', sub: null, count: null),
        ],
        selected: _code,
        onSelected: (v) => setState(() => _code = v),
      ),
      if (!searching) ...[
        const SizedBox(height: 8),
        PillBar<String>(
          items: const [
            (value: 'important', label: '★ Important', sub: null, count: null),
            (value: 'all', label: 'All sections', sub: null, count: null),
            (value: 'changed', label: 'Changed', sub: null, count: null),
            (value: 'new', label: 'New', sub: null, count: null),
            (value: 'removed', label: 'Removed', sub: null, count: null),
          ],
          selected: _filter,
          onSelected: (v) => setState(() => _filter = v),
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Row(children: [
          Expanded(child: Eyebrow(searching ? '${results.length} ${results.length == 1 ? 'match' : 'matches'}' : '${results.length} sections')),
          Text('Long-press to copy', style: TextStyle(fontSize: 11, color: c.muted)),
        ]),
      ),
      Expanded(
        child: results.isEmpty
            ? const Padding(padding: EdgeInsets.all(18), child: EmptyCard(icon: Icons.menu_book_outlined, title: 'No section found', text: 'Try the old section number (e.g. 420, 156(3), 65B) or a word from its title.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                itemCount: results.length + 1,
                itemBuilder: (context, i) => i == results.length ? _footer(c) : Padding(padding: const EdgeInsets.only(bottom: 10), child: _RowCard(row: results[i])),
              ),
      ),
    ]);
  }

  Widget _footer(LT c) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('${LawBook.note}\nSource: ${LawBook.source}.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.muted, height: 1.5)),
      );
}

class _RowCard extends StatefulWidget {
  const _RowCard({required this.row});
  final LawBookRow row;
  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    final r = widget.row;
    final (label, tone) = switch (r.status) {
      'Changed' => ('Changed', ChipTone.wait),
      'New' => ('New', ChipTone.good),
      'Deleted' => ('Removed', ChipTone.bad),
      _ => ('Same', ChipTone.muted),
    };
    Widget code(String act, String section, {bool strong = false}) => Text.rich(TextSpan(children: [
          TextSpan(text: '$act ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
          TextSpan(text: section.isEmpty ? '—' : section, style: mono(15, color: strong ? c.brand : c.ink).copyWith(fontWeight: FontWeight.w700)),
        ]));
    final details = r.newWording.isNotEmpty && r.newWording.toLowerCase() != r.oldTitle.toLowerCase();
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: '${r.shareText}${r.oldTitle.isNotEmpty ? ' (${r.oldTitle})' : ''}'));
        if (context.mounted) toast(context, 'Copied: ${r.shareText}');
      },
      child: LtCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: code(r.oldAct, r.oldSection)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 16, color: c.muted)),
            Flexible(child: code(r.newAct, r.newSection, strong: true)),
            const Spacer(),
            if (r.important) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.star_rounded, size: 17, color: c.gold)),
            StateChip(label, tone: tone),
          ]),
          if (r.oldTitle.isNotEmpty || r.newWording.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.oldTitle.isNotEmpty ? r.oldTitle : r.newWording, maxLines: _open ? null : 2, overflow: _open ? null : TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.ink)),
          ],
          if (_open) ...[
            if (details && r.oldTitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(10)),
                child: Text('${r.newAct}: ${r.newWording}', style: TextStyle(fontSize: 12.5, height: 1.45, color: c.ink)),
              ),
            ],
            if (r.status == 'Deleted') Padding(padding: const EdgeInsets.only(top: 8), child: Text('No equivalent in ${r.newAct}. Offences before 1 July 2024 still go under ${r.oldAct}.', style: TextStyle(fontSize: 12, color: c.bad))),
            if (r.status == 'New') Padding(padding: const EdgeInsets.only(top: 8), child: Text('New in ${r.newAct}; there was no matching ${r.oldAct} section.', style: TextStyle(fontSize: 12, color: c.good))),
          ],
          if (r.chapter.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.chapter, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted)),
          ],
        ]),
      ),
    );
  }
}
