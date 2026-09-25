import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/consultation_service.dart';
import '../services/partner_auth_service.dart';
import '../services/realtime_service.dart';

enum TxnCategory { feesEarned, payout, pending }

enum PayoutMethodType { upi, bank }

class WalletTransaction {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final TxnCategory category;

  const WalletTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.category,
  });

  WalletTransaction copyWith({TxnCategory? category}) => WalletTransaction(
        id: id,
        title: title,
        subtitle: subtitle,
        amount: amount,
        date: date,
        category: category ?? this.category,
      );

  bool get isCredit => amount >= 0;

  /// A ledger row from the server: an earning (with what the client paid and
  /// the commission) or a payout.
  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    final earning = json['type'] == 'earning';
    final client = json['clientName']?.toString() ?? 'Client';
    String money(Object? v) => (v as num?) == null ? '' : '₹${(v as num) == v.roundToDouble() ? v.toInt() : v.toStringAsFixed(2)}';
    return WalletTransaction(
      id: json['id'].toString(),
      title: earning ? '${json['reason'] == 'call' ? 'Call' : 'Chat'} · $client' : json['type'] == 'payout' ? 'Payout' : 'Adjustment',
      subtitle: earning ? 'Client paid ${money(json['gross'])} · commission ${money(json['commission'])}${json['note'] == null || json['note'] == '' ? '' : ' · ${json['note']}'}' : (json['note']?.toString() ?? ''),
      amount: amount,
      date: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      category: earning ? TxnCategory.feesEarned : TxnCategory.payout,
    );
  }
}

/// The lawyer's money, from GET /api/lawyers/me/earnings: every client payment
/// minus the platform commission is an earning; payouts are taken out.
class WalletController extends ChangeNotifier {
  WalletController() {
    _events = RealtimeService.instance.events.stream.listen((event) {
      if (event.name == 'connect' || event.name == 'earnings_updated') load();
    });
    load();
  }

  final _service = PartnerConsultationService();
  StreamSubscription<SocketEvent>? _events;
  double availableBalance = 0;
  double totalEarnings = 0;
  double pendingPayouts = 0;
  double commissionPercent = 0;
  double minimumWithdrawal = 0;
  bool autoSettlementEnabled = false;

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) return;
    try {
      _apply(await _service.earnings(token));
    } catch (error) {
      debugPrint('Could not load wallet: $error');
    }
  }

  void _apply(Map<String, dynamic> data) {
    double money(String key) => (data[key] as num?)?.toDouble() ?? 0;
    availableBalance = money('available');
    totalEarnings = money('totalEarnings');
    pendingPayouts = money('pendingPayouts');
    commissionPercent = money('commissionPercent');
    minimumWithdrawal = money('minimumWithdrawal');
    transactions
      ..clear()
      ..addAll((data['transactions'] as List? ?? const []).map((raw) => WalletTransaction.fromJson(Map<String, dynamic>.from(raw as Map))));
    notifyListeners();
  }

  String? upiId = 'adv.rajesh@okaxis';
  String? upiHolderName = 'RAJESH KUMAR SHARMA';

  String? bankHolderName = 'Adv. Rajesh Kumar Sharma';
  String? bankIfsc = 'HDFC0000124';
  String? bankBranch = 'HDFC BANK, KASTURBA GANDHI MARG, NEW DELHI';
  String? bankAccountLast4 = '9820';

  PayoutMethodType defaultMethod = PayoutMethodType.upi;

  bool get hasUpi => upiId != null;
  bool get hasBank => bankIfsc != null;

  String get defaultMethodSummary =>
      defaultMethod == PayoutMethodType.upi ? 'UPI · $upiId' : 'Bank Account · HDFC ****$bankAccountLast4';

  /// Newest first: earnings (client payment minus commission) and payouts.
  final List<WalletTransaction> transactions = [];

  void linkUpi(String vpa, String holderName) {
    upiId = vpa;
    upiHolderName = holderName;
    notifyListeners();
  }

  void linkBankAccount({
    required String holderName,
    required String ifsc,
    required String branch,
    required String accountNumber,
  }) {
    bankHolderName = holderName;
    bankIfsc = ifsc;
    bankBranch = branch;
    bankAccountLast4 = accountNumber.length >= 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber;
    notifyListeners();
  }

  void setDefaultMethod(PayoutMethodType type) {
    defaultMethod = type;
    notifyListeners();
  }

  void enableAutoSettlement() {
    autoSettlementEnabled = true;
    notifyListeners();
  }

  /// Asks Vakil to pay out the available balance (the admin sends it).
  /// Throws [PartnerNetworkException] with the reason, e.g. below the minimum.
  Future<WalletTransaction> requestWithdrawal() async {
    final token = PartnerAuthService.instance.token;
    if (token == null) throw const PartnerNetworkException('Please sign in again');
    final data = await _service.requestPayout(token);
    _apply(data);
    final payout = Map<String, dynamic>.from(data['payout'] as Map);
    return WalletTransaction(
      id: payout['id'].toString(),
      title: 'Payout requested',
      subtitle: defaultMethod == PayoutMethodType.upi ? 'To UPI ($upiId)' : 'To your bank account',
      amount: -((payout['amount'] as num?)?.toDouble() ?? 0),
      date: DateTime.tryParse(payout['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      category: TxnCategory.pending,
    );
  }
}
