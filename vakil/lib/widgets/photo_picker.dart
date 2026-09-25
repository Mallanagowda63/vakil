import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Asks camera or gallery and returns the chosen photo, resized for upload
/// (null if cancelled). [onRemove] adds a "Remove photo" choice.
Future<XFile?> pickProfilePhoto(BuildContext context, {VoidCallback? onRemove}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheetContext) => SafeArea(
      child: Wrap(children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(sheetContext, 'camera')),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(sheetContext, 'gallery')),
        if (onRemove != null) ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Remove photo', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(sheetContext, 'remove')),
      ]),
    ),
  );
  if (choice == null) return null;
  if (choice == 'remove') { onRemove?.call(); return null; }
  try {
    return await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the camera or gallery. Check the app permissions.')));
    return null;
  }
}
