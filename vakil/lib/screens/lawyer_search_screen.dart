import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/api_client.dart';
import '../services/consultation_service.dart';
import '../services/realtime_service.dart';
import '../state/home_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'lawyers_screen.dart';

/// Search lawyers by name, practice area, city or language. Results update as
/// the user types; online lawyers stay on top.
class LawyerSearchScreen extends StatefulWidget {
  const LawyerSearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  State<LawyerSearchScreen> createState() => _LawyerSearchScreenState();
}

class _LawyerSearchScreenState extends State<LawyerSearchScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  final _service = ConsultationService();
  StreamSubscription<SocketEvent>? _events;
  List<LawyerSummary>? _lawyers;
  String? _error;

  static const _suggestions = ['Criminal', 'Family', 'Property', 'Corporate', 'Divorce', 'Tax', 'Consumer', 'Employment'];

  @override
  void initState() {
    super.initState();
    _events = RealtimeService.instance.events.stream.where((e) => e.name == 'lawyer_status_changed').listen((event) {
      final lawyers = _lawyers;
      if (lawyers != null && mounted) setState(() => _lawyers = applyLawyerStatus(lawyers, event.data));
    });
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final lawyers = sortLawyers(await _service.lawyers());
      if (mounted) setState(() { _lawyers = lawyers; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _setQuery(String value) {
    _query.text = value;
    _query.selection = TextSelection.collapsed(offset: value.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final lawyers = _lawyers;
    final results = lawyers == null ? null : query.isEmpty ? lawyers : lawyers.where((l) => l.matchesSearch(query)).toList();
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: widget.initialQuery.isEmpty,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          style: AppText.input(AppColors.textDark),
          decoration: InputDecoration(
            hintText: 'Search name, practice area, city, language',
            hintStyle: AppText.body(AppColors.textGray),
            border: InputBorder.none,
            suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close), onPressed: () => _setQuery('')),
          ),
        ),
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: AppText.body(AppColors.textGray)), TextButton(onPressed: _load, child: const Text('Try again'))]))
          : results == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (query.isEmpty) ...[
                    Text('Popular searches', style: AppText.bodyMedium(AppColors.textDark)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _setQuery(s))]),
                    const SizedBox(height: 18),
                    Text('All lawyers', style: AppText.bodyMedium(AppColors.textDark)),
                  ] else
                    Text('${results.length} ${results.length == 1 ? 'lawyer' : 'lawyers'} for "$query"', style: AppText.bodyMedium(AppColors.textDark)),
                  const SizedBox(height: 10),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(children: [
                        const Icon(Icons.search_off, size: 40, color: AppColors.textGraySoft),
                        const SizedBox(height: 8),
                        Text('No lawyers match "$query".', style: AppText.body(AppColors.textGray)),
                        TextButton(onPressed: () { Navigator.pop(context); HomeNav.openLawyers(); }, child: const Text('Browse all lawyers')),
                      ]),
                    )
                  else
                    for (final lawyer in results) Padding(padding: const EdgeInsets.only(bottom: 10), child: LawyerRow(lawyer: lawyer)),
                ]),
    );
  }
}
