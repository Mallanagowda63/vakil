import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakil_partner/screens/law_book_screen.dart';

void main() {
  final data = jsonDecode(File('assets/data/law_book.json').readAsStringSync()) as Map<String, dynamic>;
  final rows = (data['rows'] as List).map((e) => LawBookRow(Map<String, dynamic>.from(e as Map))).toList();
  String first(String q, {String code = 'all'}) => LawBook.search(rows, q, code: code).first.shareText;

  test('the whole Excel law book is bundled', () {
    expect(rows.length, greaterThan(1300));
    expect(rows.where((r) => r.important).length, greaterThanOrEqualTo(68));
  });
  test('old section numbers find the new sections first', () {
    expect(first('420'), 'IPC 420 → BNS 318(4)');
    expect(first('crpc 438'), 'CrPC 438 → BNSS 482');
    expect(LawBook.search(rows, '438').take(2).map((r) => r.shareText), containsAll(['CrPC 438 → BNSS 482', 'IPC 438 → BNS 327(2)']));
    expect(first('bns 318(4)'), 'IPC 420 → BNS 318(4)');
    expect(first('Section 420'), 'IPC 420 → BNS 318(4)');
    expect(first('65B'), 'Evidence Act 65B → BSA 63');
    expect(first('506'), 'IPC 506 → BNS 351(2), 351(3)');
    expect(first('156(3)', code: 'CrPC'), startsWith('CrPC 156(3) → BNSS 175(3)'));
  });
  test('removed sections say so', () {
    expect(first('124A'), 'IPC 124A — removed in the 2023 code');
  });
  test('words search titles', () {
    expect(LawBook.search(rows, 'anticipatory bail').isNotEmpty || LawBook.search(rows, 'apprehending arrest').isNotEmpty, isTrue);
    expect(LawBook.search(rows, 'cheating').any((r) => r.oldSection == '420'), isTrue);
  });
  test('no search shows the important list', () {
    final list = LawBook.search(rows, '');
    expect(list.every((r) => r.important), isTrue);
    expect(list.any((r) => r.oldSection == '498A'), isTrue);
  });
}
