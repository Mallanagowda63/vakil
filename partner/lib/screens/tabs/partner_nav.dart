import 'package:flutter/foundation.dart';

/// Which tab of the partner app is showing, and where Consults should open,
/// so a card on Home can jump to "Consults → Incoming" or "Session Book".
class PartnerNav {
  PartnerNav._();
  static const home = 0, consults = 1, earnings = 2, profile = 3;

  static final tab = ValueNotifier<int>(home);
  /// 'consults' | 'chats' | 'sessions'
  static final consultsSegment = ValueNotifier<String>('consults');
  /// 'incoming' | 'active' | 'completed' | 'declined'
  static final consultsFilter = ValueNotifier<String>('incoming');

  static void openConsults({String seg = 'consults', String? filter}) {
    consultsSegment.value = seg;
    if (filter != null) consultsFilter.value = filter;
    tab.value = consults;
  }
}
