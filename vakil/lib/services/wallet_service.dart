import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
  /// razorpay, test (stand-in recharge on a development server) or unavailable.
  String paymentMode = 'razorpay';
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
    Map<String, dynamic> proof = {'orderId': orderId};
    if (order['mode'] == 'razorpay') {
      proof = await _checkout(order);
    }
    final result = await _api.post('/api/wallet/verify', proof, token: token);
    WalletState.balance = (result['balance'] as num?)?.toDouble() ?? WalletState.balance;
    await refresh();
    return (result['amount'] as num?)?.toDouble() ?? amount;
  }

  /// Opens Razorpay Checkout for a server-created order and waits for the result.
  Future<Map<String, dynamic>> _checkout(Map<String, dynamic> order) {
    final completer = Completer<Map<String, dynamic>>();
    final razorpay = Razorpay();
    final orderId = order['orderId'].toString();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!completer.isCompleted) completer.complete({'orderId': r.orderId ?? orderId, 'razorpayPaymentId': r.paymentId, 'signature': r.signature});
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      final cancelled = r.code == Razorpay.PAYMENT_CANCELLED;
      _api.post('/api/wallet/cancel', {'orderId': orderId, 'reason': r.message ?? 'Payment failed'}, token: AuthService.instance.token).catchError((_) => <String, dynamic>{});
      if (!completer.isCompleted) completer.completeError(ApiException(cancelled ? 'Payment cancelled' : 'Payment failed. No money was added.'));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
    final prefill = Map<String, dynamic>.from(order['prefill'] as Map? ?? const {});
    razorpay.open({
      'key': order['razorpayKeyId'],
      'order_id': orderId,
      'amount': order['amountPaise'],
      'currency': 'INR',
      'name': 'Vakil',
      'description': 'Wallet recharge',
      'prefill': {'contact': prefill['contact'] ?? '', 'email': prefill['email'] ?? ''},
      'theme': {'color': '#2463EB'},
    });
    return completer.future.whenComplete(razorpay.clear);
  }

  void clear() {
    WalletState.balance = 0;
    transactions = const [];
    loaded = false;
    notifyListeners();
  }
}
