import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One appointment the lawyer noted in the Session book.
class BookedSession {
  BookedSession({required this.id, required this.client, required this.category, required this.mode, required this.at, this.minutes = 30, this.confirmed = true});
  final String id;
  final String client, category, mode;
  final DateTime at;
  final int minutes;
  bool confirmed;

  Map<String, dynamic> toJson() => {'id': id, 'client': client, 'category': category, 'mode': mode, 'at': at.toIso8601String(), 'minutes': minutes, 'confirmed': confirmed};
  factory BookedSession.fromJson(Map<String, dynamic> j) => BookedSession(
        id: j['id'].toString(), client: j['client'].toString(), category: j['category'].toString(), mode: j['mode'].toString(),
        at: DateTime.tryParse(j['at'].toString()) ?? DateTime.now(), minutes: (j['minutes'] as num?)?.toInt() ?? 30, confirmed: j['confirmed'] != false);
}

/// The lawyer's own diary of sessions, kept on this phone (Consults → Session Book).
class SessionBook extends ChangeNotifier {
  SessionBook._() { _load(); }
  static final instance = SessionBook._();
  static const _key = 'partner_session_book';

  final List<BookedSession> sessions = [];

  /// Upcoming first, then by time; past sessions older than a day drop off the list.
  List<BookedSession> get upcoming {
    final from = DateTime.now().subtract(const Duration(days: 1));
    return sessions.where((s) => s.at.isAfter(from)).toList()..sort((a, b) => a.at.compareTo(b.at));
  }

  int get thisWeek {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    return sessions.where((s) => s.at.isAfter(now.subtract(const Duration(hours: 1))) && s.at.isBefore(end)).length;
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      sessions..clear()..addAll((jsonDecode(raw) as List).map((e) => BookedSession.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try { await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(sessions.map((s) => s.toJson()).toList())); } catch (_) {}
  }

  Future<void> add(BookedSession s) { sessions.add(s); return _save(); }
  Future<void> confirm(String id) { sessions.where((s) => s.id == id).forEach((s) => s.confirmed = true); return _save(); }
  Future<void> remove(String id) { sessions.removeWhere((s) => s.id == id); return _save(); }
}
