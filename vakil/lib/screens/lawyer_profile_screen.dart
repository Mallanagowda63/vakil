import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import '../services/profile_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/chat_format.dart';
import '../widgets/wallet_widgets.dart';
import 'lawyers_screen.dart';

/// A lawyer from the server: name, photo, practice areas, availability and
/// price ("FREE 1 min trial" until the user's trial is used, then ₹X/min).
class LawyerProfileScreen extends StatefulWidget {
  const LawyerProfileScreen({super.key, required this.lawyer});

  final LawyerSummary lawyer;

  @override
  State<LawyerProfileScreen> createState() => _LawyerProfileScreenState();
}

class _LawyerProfileScreenState extends State<LawyerProfileScreen> {
  late LawyerSummary lawyer = widget.lawyer;
  StreamSubscription<SocketEvent>? _events;
  ({List<LawyerReview> items, double? average, int count})? _reviews;

  @override
  void initState() {
    super.initState();
    ProfileService.instance.lawyerReviews(lawyer.id).then((r) { if (mounted) setState(() => _reviews = r); }, onError: (_) { if (mounted) setState(() => _reviews = (items: const <LawyerReview>[], average: null, count: 0)); });
    // Chat / call switches change live while the profile is open.
    _events = RealtimeService.instance.events.stream.where((e) => e.name == 'lawyer_status_changed' && e.data['id']?.toString() == lawyer.id).listen((event) {
      if (mounted) setState(() => lawyer = applyLawyerStatus([lawyer], event.data).first);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    final average = reviews?.average ?? lawyer.ratingAverage;
    final count = reviews?.count ?? lawyer.ratingCount;
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Lawyer Profile', style: AppText.h3(AppColors.textDark))),
                  const WalletButton(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.navyDeep, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: lawyer.photoUrl == null ? null : () => showPhoto(context, lawyer.photoUrl!, lawyer.name),
                                child: LawyerAvatar(name: lawyer.name, photoUrl: lawyer.photoUrl, radius: 34),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Flexible(child: Text('Adv. ${lawyer.name}', style: AppText.h3(AppColors.textWhite), overflow: TextOverflow.ellipsis)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 16, color: AppColors.greenAccent),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text([lawyer.category, if (lawyer.city.isNotEmpty) lawyer.city].join(' · '), style: AppText.bodySmall(AppColors.textMuted)),
                                    if (average != null) Padding(padding: const EdgeInsets.only(top: 4), child: RatingLine(average: average, count: count, color: AppColors.textWhite)),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Container(width: 6, height: 6, decoration: BoxDecoration(color: lawyer.online ? AppColors.greenAccent : AppColors.textFaint, shape: BoxShape.circle)),
                                      const SizedBox(width: 4),
                                      Text(lawyer.online ? 'ONLINE NOW' : 'OFFLINE', style: AppText.caption(lawyer.online ? AppColors.greenAccent : AppColors.textMuted).copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chat_bubble_outline, size: 14, color: lawyer.chatOnline ? AppColors.greenAccent : AppColors.textFaint),
                                      const SizedBox(width: 6),
                                      Icon(Icons.call_outlined, size: 14, color: lawyer.callOnline ? AppColors.greenAccent : AppColors.textFaint),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Align(alignment: Alignment.centerLeft, child: PriceTag(ratePerMinute: lawyer.ratePerMinute, large: true)),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(child: _StatTile(value: formatRate(lawyer.ratePerMinute), label: 'Chat price')),
                            const SizedBox(width: 10),
                            Expanded(child: _StatTile(value: formatRate(lawyer.rateFor(call: true)), label: 'Voice call')),
                            const SizedBox(width: 10),
                            Expanded(child: _StatTile(value: lawyer.chatOnline && lawyer.callOnline ? 'Chat + Call' : lawyer.chatOnline ? 'Chat only' : lawyer.callOnline ? 'Call only' : 'Away', label: 'Available for')),
                          ]),
                        ],
                      ),
                    ),
                    if (lawyer.bio.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Text('About', style: AppText.h3(AppColors.textDark)),
                      const SizedBox(height: 6),
                      Text(lawyer.bio, style: AppText.body(AppColors.textGray)),
                    ],
                    if (lawyer.languages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(children: [const Icon(Icons.translate, size: 16, color: AppColors.textGray), const SizedBox(width: 6), Expanded(child: Text(lawyer.languages, style: AppText.bodySmall(AppColors.textGray)))]),
                    ],
                    const SizedBox(height: 22),
                    Text('Practice Areas', style: AppText.h3(AppColors.textDark)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [for (final area in lawyer.categories) _PracticeChip(label: area)]),
                    const SizedBox(height: 22),
                    Text('Consultation', style: AppText.h3(AppColors.textDark)),
                    const SizedBox(height: 6),
                    Text('Chat ${formatRate(lawyer.ratePerMinute)} · Voice call ${formatRate(lawyer.rateFor(call: true))}. Charged per minute from your wallet after your free 1-minute trial.', style: AppText.bodySmall(AppColors.textGray)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: ChatCallButton(lawyer: lawyer, expand: true)),
                      const SizedBox(width: 10),
                      Expanded(child: ChatCallButton(lawyer: lawyer, call: true, expand: true)),
                    ]),
                    if (!lawyer.online) Padding(padding: const EdgeInsets.only(top: 8), child: Text('This lawyer is offline right now.', style: AppText.caption(AppColors.textGray))),
                    const SizedBox(height: 26),
                    Text('Client Reviews${count > 0 ? ' ($count)' : ''}', style: AppText.h3(AppColors.textDark)),
                    const SizedBox(height: 10),
                    if (reviews == null)
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (reviews.items.isEmpty)
                      Text('No reviews yet.', style: AppText.bodySmall(AppColors.textGray))
                    else
                      for (final r in reviews.items) _ReviewTile(review: r),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photo full screen; tap to close.
void showPhoto(BuildContext context, String photoUrl, String name) {
  final url = ApiConfig.mediaUrl(photoUrl);
  if (url == null) return;
  showDialog(context: context, builder: (dialogContext) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: GestureDetector(onTap: () => Navigator.pop(dialogContext), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain, semanticLabel: name)))),
  ));
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final LawyerReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightStroke)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LawyerAvatar(name: review.clientName, photoUrl: review.clientPhotoUrl, radius: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(review.clientName, style: AppText.bodyMedium(AppColors.textDark))),
            if (review.createdAt != null) Text(dayLabel(review.createdAt!), style: AppText.caption(AppColors.textGray)),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            for (var i = 1; i <= 5; i++) Icon(i <= review.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: AppColors.starGold),
            const SizedBox(width: 6),
            Text(review.isCall ? 'Voice call' : 'Chat', style: AppText.caption(AppColors.textGray)),
          ]),
          if (review.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review.comment, style: AppText.bodySmall(AppColors.textDark))),
        ])),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.darkInputBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              textAlign: TextAlign.center,
              style: AppText.bodyMedium(AppColors.textWhite)),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption(AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _PracticeChip extends StatelessWidget {
  const _PracticeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.blueSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppText.bodySmall(AppColors.blueAccent)
              .copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
