import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

class PracticeAreasScreen extends StatefulWidget {
  final List<String> initiallySelected;
  const PracticeAreasScreen({super.key, required this.initiallySelected});

  @override
  State<PracticeAreasScreen> createState() => _PracticeAreasScreenState();
}

class _PracticeAreasScreenState extends State<PracticeAreasScreen> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initiallySelected.toSet();
  }

  void _toggle(String title) {
    setState(() {
      if (_selected.contains(title)) {
        _selected.remove(title);
      } else {
        _selected.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose practice areas')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the areas you want to highlight for clients.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                ),
                SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Practice areas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Spacer(),
                    Text(
                      'Tap each option to add it to your profile',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: kPracticeAreaOptions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final option = kPracticeAreaOptions[i];
                final selected = _selected.contains(option.title);
                return InkWell(
                  onTap: () => _toggle(option.title),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              const SizedBox(height: 3),
                              Text(
                                option.description,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Checkbox(
                          value: selected,
                          onChanged: (_) => _toggle(option.title),
                          shape: const CircleBorder(),
                          activeColor: AppColors.primaryDark,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: PrimaryButton(
                label: 'Save',
                onPressed: () => Navigator.of(context).pop(_selected.toList()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
