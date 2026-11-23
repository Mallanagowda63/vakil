import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'lt_ui.dart';

/// Law categories used for filters, practice areas and Law points.
class LawCategory {
  const LawCategory(this.id, this.label, this.acts);
  final String id, label, acts;
}

const lawCategories = [
  LawCategory('Criminal', 'Criminal', 'IPC / BNS'),
  LawCategory('Civil', 'Civil', 'CPC'),
  LawCategory('Consumer', 'Consumer', 'CPA 2019'),
  LawCategory('Family', 'Family', 'HMA / BNSS 144'),
  LawCategory('Property', 'Property', 'TPA / Partition'),
  LawCategory('Cheque', 'Cheque bounce', 'NI Act §138'),
  LawCategory('Labour', 'Labour', 'Wages / PF'),
];

String lawLabel(String id) => lawCategories.where((c) => c.id == id).firstOrNull?.label ?? id;

/// Which category a free-text practice area or request category belongs to.
String categoryOf(String text) {
  final t = text.toLowerCase();
  if (t.contains('criminal') || t.contains('bail')) return 'Criminal';
  if (t.contains('cheque') || t.contains('138') || t.contains('negotiable')) return 'Cheque';
  if (t.contains('consumer') || t.contains('refund') || t.contains('insurance')) return 'Consumer';
  if (t.contains('family') || t.contains('divorce') || t.contains('maintenance') || t.contains('matrimon')) return 'Family';
  if (t.contains('property') || t.contains('real estate') || t.contains('tenan') || t.contains('partition') || t.contains('land')) return 'Property';
  if (t.contains('labour') || t.contains('employ') || t.contains('salary') || t.contains('service')) return 'Labour';
  return 'Civil';
}

class _Law {
  const _Law(this.acts, this.points, this.say, this.docs);
  final String acts;
  final List<(String, String)> points;
  final String say;
  final List<String> docs;
}

// Quick reference only; the sheet says to check the current text before advising.
const _law = <String, _Law>{
  'Criminal': _Law('BNS 2023 (replaced IPC) · BNSS 2023 (replaced CrPC) · BSA 2023', [
    ('BNSS §173', 'FIR must be registered for cognizable offences; Zero FIR and e-FIR allowed at any police station.'),
    ('BNSS §175(3)', 'If police refuse, apply to the Magistrate to direct investigation (old CrPC §156(3)).'),
    ('BNSS §480 / §482', 'Regular bail (old CrPC §437/439) and anticipatory bail (old §438).'),
    ('BNS §318', 'Cheating (old IPC §420). BNS §316 criminal breach of trust (old IPC §406).'),
    ('BNS §85–86', 'Cruelty by husband or relatives (old IPC §498A).'),
  ], 'Tell the client which section applies, whether it is bailable, and that offences on or after 1 July 2024 are under BNS; older ones stay under IPC.',
      ['FIR copy / complaint', 'Notice or summons received', 'ID proof', 'Any CCTV, messages, call records']),
  'Civil': _Law('Code of Civil Procedure 1908 · Limitation Act 1963 · Specific Relief Act 1963', [
    ('CPC Order 39 R.1–2', 'Temporary injunction to stop the other side till the suit is decided.'),
    ('CPC §80', "Two months' notice before suing the Government."),
    ('Limitation Act', '3 years for most money / contract claims; 12 years to recover possession of immovable property (Art. 65).'),
    ('Specific Relief Act §10', 'Specific performance of a contract, e.g. sale agreement.'),
    ('CPC Order 37', 'Summary suit for recovery on written contracts and promissory notes.'),
  ], 'Explain the limitation deadline first, then the relief (injunction, recovery, declaration) and the court where the suit will be filed.',
      ['Agreement / contract', 'Payment proofs', 'Legal notice sent or received', 'Property documents if any']),
  'Consumer': _Law('Consumer Protection Act 2019 · E-commerce Rules 2020', [
    ('CPA §2(7), §2(11)', "A buyer for personal use is a consumer; 'deficiency' covers poor service."),
    ('CPA §34, §47, §58', 'District Commission up to ₹50 lakh; State ₹50 lakh–₹2 crore; National above ₹2 crore (2021 limits).'),
    ('CPA §35', 'Complaint can be filed where the consumer lives or works; e-filing on e-Daakhil.'),
    ('CPA §69', 'File within 2 years of the cause of action.'),
    ('CPA §38', 'Mediation option before or during the case.'),
  ], 'Tell the client to send a written complaint to the seller first, keep the invoice, and that no lawyer is mandatory but filing fee depends on the claim value.',
      ['Invoice / bill', 'Warranty card', 'Emails or chats with seller', 'Photos of the defect']),
  'Family': _Law('Hindu Marriage Act 1955 · BNSS §144 · Protection of Women from DV Act 2005', [
    ('HMA §13', 'Grounds for contested divorce: cruelty, desertion (2 yrs), adultery, conversion, mental disorder.'),
    ('HMA §13B', 'Mutual consent divorce; 6-month cooling period can be waived by the court.'),
    ('BNSS §144', 'Maintenance for wife, children and parents (old CrPC §125).'),
    ('HMA §24', 'Interim maintenance and litigation costs while the case is pending.'),
    ('DV Act §12, §18–20', 'Protection, residence and monetary relief orders.'),
  ], 'Clarify whether the client wants divorce, maintenance or protection first; explain mediation and that the Family Court where the wife lives can be approached.',
      ['Marriage certificate / photos', 'Income proofs of both sides', "Children's details", 'Any complaints already filed']),
  'Property': _Law('Hindu Succession Act 1956 · Transfer of Property Act 1882 · Registration Act 1908', [
    ('HSA §6', 'Daughters are coparceners by birth with equal rights in ancestral property.'),
    ('HSA §8', 'Self-acquired property of a Hindu male dying without a will goes to Class I heirs equally.'),
    ('Registration Act §17', 'Sale, gift and leases over 1 year must be registered.'),
    ('TPA §54', 'Sale of immovable property only by registered deed; agreement to sell gives no title.'),
    ('Partition suit', 'Filed in civil court for division by metes and bounds; get RTC / khata first.'),
  ], "Ask whether the land is ancestral or self-acquired and whether there is a will; explain each heir's share and partition by agreement before going to court.",
      ['RTC / Pahani, khata extract', 'Sale or gift deeds', 'Death certificate, family tree', 'Encumbrance certificate']),
  'Cheque': _Law('Negotiable Instruments Act 1881 §138–148', [
    ('Validity', 'Present the cheque within 3 months of its date.'),
    ('§138(b)', "Send a demand notice within 30 days of the bank's return memo."),
    ('§138(c)', 'The drawer gets 15 days after receiving the notice to pay.'),
    ('§142', 'File the complaint within 1 month after the 15 days end (delay can be condoned).'),
    ('§143A / §148', 'Interim compensation up to 20% at trial; 20% deposit on appeal. Punishment up to 2 years or twice the amount.'),
  ], 'Check the dates first. For the drawer, advise paying within 15 days of the notice to avoid prosecution; for the payee, keep the return memo and notice proof.',
      ['Original cheque', 'Bank return memo', 'Copy of legal notice + postal proof', 'Loan / transaction proof']),
  'Labour': _Law('Code on Wages 2019 · Payment of Gratuity Act 1972 · Industrial Disputes Act 1947', [
    ('Wages', 'Salary must be paid by the due date; unpaid wages can be claimed before the Labour authority.'),
    ('Gratuity', "Payable after 5 years of continuous service: 15 days' wages per year of service."),
    ('ID Act §2A, §25F', 'Individual dispute over dismissal; retrenchment needs notice and compensation.'),
    ('EPF', 'Employer must deposit PF; check on the EPFO portal with UAN.'),
    ('Labour Commissioner', 'Conciliation first; then Labour Court.'),
  ], 'Tell the client to send a written demand to HR, collect salary slips and the appointment letter, and that the Labour office route is usually cheaper than a civil suit.',
      ['Appointment letter', 'Salary slips / bank statements', 'Termination or resignation letter', 'UAN / PF details']),
};

/// "§ Law points" button for a request or session.
class LawPointsButton extends StatelessWidget {
  const LawPointsButton(this.category, {super.key});
  final String category;
  @override
  Widget build(BuildContext context) {
    final c = LT.of(context);
    return GestureDetector(
      onTap: () => showLawPoints(context, category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: c.goldSoft, borderRadius: BorderRadius.circular(8)),
        child: Text('§ Law points', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.gold)),
      ),
    );
  }
}

Future<void> showLawPoints(BuildContext context, String category) {
  var selected = _law.containsKey(category) ? category : 'Criminal';
  return showLtSheet(context, title: 'Law points', builder: (sheetContext) => StatefulBuilder(builder: (context, setState) {
    final c = LT.of(context);
    final law = _law[selected]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: lawCategories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final cat = lawCategories[i];
            final on = cat.id == selected;
            return GestureDetector(
              onTap: () => setState(() => selected = cat.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? c.brandSoft : c.surface, borderRadius: BorderRadius.circular(13), border: Border.all(color: on ? c.brand : c.line)),
                child: Text(cat.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? c.brand : c.ink)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Text(law.acts, style: TextStyle(fontSize: 12, color: c.muted, height: 1.5)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
        child: Column(children: [
          for (var i = 0; i < law.points.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 100, child: Text(law.points[i].$1, style: mono(11.5, color: c.brand))),
                const SizedBox(width: 8),
                Expanded(child: Text(law.points[i].$2, style: TextStyle(fontSize: 13, height: 1.45, color: c.ink))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow('Tell the client', color: c.brand),
          const SizedBox(height: 6),
          Text(law.say, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.ink)),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: LtButton('Copy for the chat', icon: Icons.copy_rounded, onTap: () async {
            await Clipboard.setData(ClipboardData(text: law.say));
            if (context.mounted) toast(context, 'Copied. Paste it in the client chat');
          })),
        ]),
      ),
      const SizedBox(height: 16),
      const Eyebrow('Ask the client for'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in law.docs)
          Container(
            width: (MediaQuery.sizeOf(context).width - 44) / 2,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check, size: 14, color: c.good),
              const SizedBox(width: 6),
              Expanded(child: Text(d, style: TextStyle(fontSize: 12.5, height: 1.35, color: c.ink))),
            ]),
          ),
      ]),
      const SizedBox(height: 14),
      Center(child: Text('Quick reference only. Check the current text and latest judgments before advising.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.muted))),
    ]);
  }));
}
