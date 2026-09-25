import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/wallet_data.dart';
import '../theme/app_theme.dart';

enum _Filter { all, fees, payouts, pending }

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  _Filter _filter = _Filter.all;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilter(WalletTransaction t) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.fees:
        return t.category == TxnCategory.feesEarned;
      case _Filter.payouts:
        return t.category == TxnCategory.payout;
      case _Filter.pending:
        return t.category == TxnCategory.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<WalletController>().transactions;
    final filtered = all.where(_matchesFilter).where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.title.toLowerCase().contains(q) || t.subtitle.toLowerCase().contains(q) || t.id.toLowerCase().contains(q);
    }).toList();

    final groups = <String, List<WalletTransaction>>{};
    for (final t in filtered) {
      final key = DateFormat('MMMM yyyy').format(t.date).toUpperCase();
      groups.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statement & History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.help_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  _filterChip('All', _Filter.all),
                  const SizedBox(width: 8),
                  _filterChip('Fees Earned', _Filter.fees),
                  const SizedBox(width: 8),
                  _filterChip('Payouts', _Filter.payouts),
                  const SizedBox(width: 8),
                  _filterChip('Pending', _Filter.pending),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No transactions found', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: groups.entries.expand((entry) sync* {
                        yield Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4),
                          ),
                        );
                        for (final t in entry.value) {
                          yield _HistoryTile(txn: t);
                        }
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _Filter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.card,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final WalletTransaction txn;
  const _HistoryTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final credit = txn.isCredit;
    final pending = txn.category == TxnCategory.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(txn.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                    if (pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(10)),
                        child: const Text('PENDING', style: TextStyle(fontSize: 9, color: Color(0xFFB5751B), fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('TXN #${txn.id}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${credit ? '+' : '-'}₹${NumberFormat('#,##,##0.00', 'en_IN').format(txn.amount.abs())}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: credit ? AppColors.success : AppColors.textPrimary),
              ),
              Text(DateFormat('d MMM').format(txn.date), style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
