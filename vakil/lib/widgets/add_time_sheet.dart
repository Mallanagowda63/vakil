import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/consultation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/currency.dart';
import 'wallet_widgets.dart';

/// The minute packages a client can buy (for a new chat or to add time).
const packageMinutes = [5, 10, 15, 30];

/// Choice chips for [packageMinutes] with each package's price.
class MinutePicker extends StatelessWidget {
  const MinutePicker({super.key, required this.rate, required this.selected, required this.onSelected});
  final double rate;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final minutes in packageMinutes)
          ChoiceChip(
            selected: minutes == selected,
            onSelected: (_) => onSelected(minutes),
            label: Text('$minutes min · ${formatCurrency(minutes * rate)}'),
            labelStyle: AppText.bodyMedium(minutes == selected ? Colors.white : AppColors.textDark),
            selectedColor: AppColors.blueAccent,
            showCheckmark: false,
          ),
      ]);
}

/// Lets the client buy more minutes for an ongoing chat (and its call).
/// Returns the new seconds left, or null if nothing was bought.
Future<int?> showAddTimeSheet(BuildContext context, {required String requestId, double? rate}) async {
  var price = rate;
  if (price == null || price <= 0) {
    try { price = (await ConsultationService().chat(requestId)).ratePerMinute; } catch (_) {}
  }
  if (!context.mounted || price == null || price <= 0) return null;
  return showModalBottomSheet<int>(context: context, isScrollControlled: true, builder: (_) => _AddTimeSheet(requestId: requestId, rate: price!));
}

class _AddTimeSheet extends StatefulWidget {
  const _AddTimeSheet({required this.requestId, required this.rate});
  final String requestId;
  final double rate;
  @override
  State<_AddTimeSheet> createState() => _AddTimeSheetState();
}

class _AddTimeSheetState extends State<_AddTimeSheet> {
  int _minutes = packageMinutes.first;
  bool _busy = false;
  String? _error;

  Future<void> _buy() async {
    setState(() { _busy = true; _error = null; });
    try {
      final seconds = await ConsultationService().addTime(widget.requestId, _minutes);
      if (mounted) Navigator.of(context).pop(seconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        Navigator.of(context).pop();
        openWallet(context, message: 'Add money to buy $_minutes more minutes');
      } else {
        setState(() { _error = e.message; _busy = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add time', style: AppText.h2(AppColors.textDark)),
            const SizedBox(height: 4),
            Text('Keep chatting and calling. ${formatRate(widget.rate)}, paid from your wallet.', style: AppText.body(AppColors.textGray)),
            const SizedBox(height: 16),
            MinutePicker(rate: widget.rate, selected: _minutes, onSelected: (m) => setState(() => _minutes = m)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: AppText.body(AppColors.redAccent))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _buy,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_busy ? 'Adding…' : 'Add $_minutes min · ${formatCurrency(_minutes * widget.rate)}'),
            ),
          ]),
        ),
      );
}
