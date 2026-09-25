import 'package:flutter/foundation.dart';

/// Single source of truth for the user's wallet balance, shared by the
/// wallet top-up flow and the per-minute call billing flow so the number
/// shown never disagrees between screens. Backed by a [ValueNotifier] so
/// any screen still alive underneath in the nav stack (e.g. the wallet
/// screen you top up from, revealed again after paying) picks up the new
/// balance instead of showing what was on screen when it was first built.
class WalletState {
  WalletState._();

  // Set from the server (sign-in, GET /api/wallet, wallet_updated); starts at 0.
  static final ValueNotifier<double> _balance = ValueNotifier(0);

  static ValueListenable<double> get balanceListenable => _balance;

  static double get balance => _balance.value;
  static set balance(double value) => _balance.value = value;
}
