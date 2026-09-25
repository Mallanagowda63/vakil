import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/consultation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'lawyers_screen.dart';

/// Shown after a chat ends. Pops with the rating on success, or null on skip.
class RateLawyerScreen extends StatefulWidget {
  const RateLawyerScreen({super.key, required this.requestId, required this.lawyerName, this.photoUrl});
  final String requestId;
  final String lawyerName;
  final String? photoUrl;
  @override
  State<RateLawyerScreen> createState() => _RateLawyerScreenState();
}

class _RateLawyerScreenState extends State<RateLawyerScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ConsultationService().review(widget.requestId, _rating, _comment.text.trim());
      if (mounted) Navigator.of(context).pop(_rating);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white, actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip'))]),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Center(child: LawyerAvatar(name: widget.lawyerName, photoUrl: widget.photoUrl, radius: 40)),
          const SizedBox(height: 16),
          Text('Consultation ended', textAlign: TextAlign.center, style: AppText.h2(AppColors.textDark)),
          const SizedBox(height: 6),
          Text('How was your chat or call with ${widget.lawyerName}? Your rating helps other clients and is shared with the lawyer.', textAlign: TextAlign.center, style: AppText.body(AppColors.textGray)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var star = 1; star <= 5; star++)
              IconButton(iconSize: 40, onPressed: () => setState(() => _rating = star), icon: Icon(star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.starGold)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _comment, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(hintText: 'Add a comment (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          FilledButton(onPressed: _rating == 0 || _saving ? null : _submit, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(_saving ? 'Submitting…' : 'Submit rating')),
        ]),
      ),
    );
  }
}
