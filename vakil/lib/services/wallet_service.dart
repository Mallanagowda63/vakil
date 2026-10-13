import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import '../state/wallet_state.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'realtime_service.dart';

class WalletTransaction {
  const WalletTransaction({required this.id, required this.type, required this.amount, required this.balanceAfter, required this.reason, this.note = '', this.createdAt});
  final String id;
  /// credit, debit or refund.
  final String type;
  final double amount;
  final double balanceAfter;
  /// recharge, chat, call or refund.
  final String reason;
  final String note;
  final DateTime? createdAt;
  bool get isDebit => type == 'debit';

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        id: j['id'].toString(), type: j['type']?.toString() ?? 'credit', amount: (j['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (j['balanceAfter'] as num?)?.toDouble() ?? 0, reason: j['reason']?.toString() ?? '', note: j['note']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
      );
}

/// The user's wallet. The server is the source of truth: the balance comes
/// from GET /api/wallet and live `wallet_updated` events, and money is added
/// only after the server verifies the payment. [WalletState] holds the number
/// every screen shows.
class WalletService extends ChangeNotifier {
  WalletService._();
  static final instance = WalletService._();

  final _api = ApiClient();
  List<WalletTransaction> transactions = const [];
  List<int> rechargeOptions = const [100, 200, 500, 1000];
  double minRecharge = 1;
  double maxRecharge = 50000;
  /// cashfree, test (stand-in recharge on a development server) or unavailable.
  String paymentMode = 'cashfree';
  bool loaded = false;
  StreamSubscription<SocketEvent>? _events;

  double get balance => WalletState.balance;

  void init() {
    _events ??= RealtimeService.instance.events.stream.listen((event) {
      if (event.name == 'wallet_updated') {
        final balance = (event.data['balance'] as num?)?.toDouble();
        if (balance != null) WalletState.balance = balance;
        final t = event.data['transaction'];
        if (t is Map) {
          final entry = WalletTransaction.fromJson(Map<String, dynamic>.from(t));
          if (!transactions.any((x) => x.id == entry.id)) transactions = [entry, ...transactions];
        }
        notifyListeners();
      } else if (event.name == 'connect') {
        refresh();
      }
    });
  }

  Future<void> refresh() async {
    final token = AuthService.instance.token;
    if (token == null) return;
    try {
      final data = await _api.get('/api/wallet', token: token);
      WalletState.balance = (data['balance'] as num?)?.toDouble() ?? 0;
      transactions = (data['transactions'] as List? ?? const []).map((t) => WalletTransaction.fromJson(Map<String, dynamic>.from(t as Map))).toList();
      rechargeOptions = (data['rechargeOptions'] as List? ?? rechargeOptions).map((e) => (e as num).toInt()).toList();
      minRecharge = (data['minRecharge'] as num?)?.toDouble() ?? minRecharge;
      maxRecharge = (data['maxRecharge'] as num?)?.toDouble() ?? maxRecharge;
      paymentMode = data['paymentMode']?.toString() ?? paymentMode;
      loaded = true;
      notifyListeners();
    } catch (error) {
      debugPrint('Wallet refresh failed: $error');
    }
  }

  /// Adds [amount] rupees. Returns the amount added; throws [ApiException]
  /// with a message to show when the payment fails or is cancelled.
  Future<double> recharge(double amount) async {
    final token = AuthService.instance.token;
    if (token == null) throw const ApiException('Please sign in again');
    final order = await _api.post('/api/wallet/order', {'amount': amount}, token: token);
    final orderId = order['orderId'].toString();
    if (order['mode'] == 'cashfree') await _checkout(order);
    // The server checks the order with Cashfree before adding any money.
    final result = await _api.post('/api/wallet/verify', {'orderId': orderId}, token: token);
    WalletState.balance = (result['balance'] as num?)?.toDouble() ?? WalletState.balance;
    await refresh();
    return (result['amount'] as num?)?.toDouble() ?? amount;
  }

  /// Opens Cashfree Checkout for a server-created order and waits until the
  /// user finishes it. A failed or cancelled payment is reported to the server,
  /// which still checks with Cashfree in case the money was taken.
  Future<void> _checkout(Map<String, dynamic> order) async {
    final completer = Completer<void>();
    final orderId = order['orderId'].toString();
    final gateway = CFPaymentGatewayService();
    gateway.setCallback((_) {
      if (!completer.isCompleted) completer.complete();
    }, (CFErrorResponse error, _) async {
      final res = await _api
          .post('/api/wallet/cancel', {'orderId': orderId, 'reason': error.getMessage() ?? 'Payment failed'}, token: AuthService.instance.token)
          .catchError((_) => <String, dynamic>{});
      if (completer.isCompleted) return;
      if (res['credited'] == true) return completer.complete();
      final cancelled = (error.getCode() ?? '').toLowerCase().contains('cancel') || (error.getMessage() ?? '').toLowerCase().contains('cancel');
      completer.completeError(ApiException(cancelled ? 'Payment cancelled' : 'Payment failed. No money was added.'));
    });
    final session = CFSessionBuilder()
        .setEnvironment(order['cashfreeEnvironment'] == 'PRODUCTION' ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX)
        .setOrderId(orderId)
        .setPaymentSessionId(order['paymentSessionId'].toString())
        .build();
    gateway.doPayment(CFWebCheckoutPaymentBuilder().setSession(session).build());
    return completer.future;
  }

  void clear() {
    WalletState.balance = 0;
    transactions = const [];
    loaded = false;
    notifyListeners();
  }
}
