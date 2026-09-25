import 'package:flutter/foundation.dart';

/// Whether the user's one-time free 1-minute chat has been used (from the
/// server). Listenable, so price badges switch from "FREE 1 min trial" to
/// "₹X/min" the moment the trial is consumed.
class FreeTrialState {
  FreeTrialState._();

  static final ValueNotifier<bool> _used = ValueNotifier(false);
  static ValueListenable<bool> get listenable => _used;
  static bool get used => _used.value;
  static set used(bool value) => _used.value = value;
}
