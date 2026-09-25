import 'package:flutter/material.dart';
import '../config/api_config.dart';

/// Searches for the Vakil server (USB, then Wi-Fi/hotspot) and says whether
/// it was found. No address is typed.
Future<void> showFindServerDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        SizedBox(width: 16),
        Expanded(child: Text('Looking for the Vakil server…')),
      ]),
    ),
  );
  final found = await ApiConfig.findServer(force: true);
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  messenger.showSnackBar(SnackBar(content: Text(found ? 'Connected to the Vakil server' : ApiConfig.unreachableMessage)));
}
