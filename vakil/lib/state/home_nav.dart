import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

/// A speciality on the home screen and how it matches lawyers' practice areas
/// (from the Partner App, e.g. "Criminal Law", "Civil & Family Law").
class Speciality {
  const Speciality(this.name, this.keywords, {this.exclude = const []});
  final String name;
  /// Lower-case words searched in the practice areas; empty = every lawyer.
  final List<String> keywords;
  /// Practice areas containing these words never match (e.g. "Intellectual Property" is not real estate).
  final List<String> exclude;

  bool matches(LawyerSummary lawyer) =>
      keywords.isEmpty || lawyer.categories.any((area) { final a = area.toLowerCase(); return keywords.any(a.contains) && !exclude.any(a.contains); });

  static const all = Speciality('Legal Specialist', []);
  static const criminal = Speciality('Criminal Law', ['criminal']);
  static const family = Speciality('Family Law', ['family', 'matrimon', 'divorce']);
  static const business = Speciality('Business Law', ['corporate', 'business', 'company', 'commercial', 'tax', 'labour', 'employment']);
  static const realEstate = Speciality('Real Estate', ['real estate', 'property'], exclude: ['intellectual']);
  static const medical = Speciality('Medical Malpractice', ['medical', 'malpractice', 'consumer']);
}

/// The home shell's selected tab and the speciality filter of the Lawyers tab,
/// so the home screen can open the Lawyers tab already filtered.
class HomeNav {
  HomeNav._();
  static const home = 0, chats = 1, lawyers = 2, profile = 3;

  static final tab = ValueNotifier<int>(home);
  static final speciality = ValueNotifier<Speciality?>(null);

  /// Switches to the Lawyers tab showing [filter] (null or "Legal Specialist" = all lawyers).
  static void openLawyers([Speciality? filter]) {
    speciality.value = filter == null || filter.keywords.isEmpty ? null : filter;
    tab.value = lawyers;
  }
}
