import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';

// Photos and files in a chat, shared by the User App and the Partner App
// (keep both copies of this file identical). The server keeps the bytes; only
// the two people in the chat can download them, with their sign-in token.

const _maxBytes = 10 * 1024 * 1024;
const _documentTypes = {'pdf': 'application/pdf', 'doc': 'application/msword', 'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'txt': 'text/plain'};
const _imageTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};

String _attachmentUrl(String requestId, String attachmentId) => '${ApiConfig.baseUrl}/api/consultations/$requestId/attachments/$attachmentId';

/// Asks camera / gallery / document, then uploads the choice into the chat.
/// Returns the sent message, or null when cancelled or failed (a snackbar says why).
Future<ChatMessage?> pickAndSendAttachment(BuildContext context, {required String requestId, required String token}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: _PickOption(icon: Icons.photo_camera_outlined, label: 'Camera', color: const Color(0xFFE11D48), onTap: () => Navigator.pop(context, 'camera'))),
            Expanded(child: _PickOption(icon: Icons.photo_library_outlined, label: 'Gallery', color: const Color(0xFF7C3AED), onTap: () => Navigator.pop(context, 'gallery'))),
            Expanded(child: _PickOption(icon: Icons.description_outlined, label: 'Document', color: const Color(0xFF2563EB), onTap: () => Navigator.pop(context, 'document'))),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.timer_outlined, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(child: Text('Files are temporary. They are deleted 5 minutes after the chat ends. Photos, PDF, Word or text, up to 10 MB.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.35))),
            ]),
          ),
        ]),
      ),
    ),
  );
  if (choice == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));

  String? name; List<int>? bytes;
  try {
    if (choice == 'document') {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: [..._documentTypes.keys, ..._imageTypes.keys]);
      if (file != null && (await file.length() ?? 0) > _maxBytes) { say('That file is too big. The limit is 10 MB.'); return null; }
      name = file?.name; bytes = await file?.readAsBytes();
    } else {
      final image = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      name = image?.name; bytes = await image?.readAsBytes();
    }
  } catch (_) {
    say('Could not open ${choice == 'document' ? 'your files' : 'the $choice'}. Check the app\'s permissions.');
    return null;
  }
  if (bytes == null || name == null) return null;

  final extension = name.split('.').last.toLowerCase();
  final contentType = _imageTypes[extension] ?? _documentTypes[extension];
  if (contentType == null) { say('You can send photos, PDF, Word or text files.'); return null; }
  if (bytes.length > _maxBytes) { say('That file is too big. The limit is 10 MB.'); return null; }

  final sending = messenger.showSnackBar(SnackBar(duration: const Duration(minutes: 2), content: Row(children: [
    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
    const SizedBox(width: 12),
    Expanded(child: Text(contentType.startsWith('image/') ? 'Sending photo…' : 'Sending $name…', overflow: TextOverflow.ellipsis)),
  ])));
  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/consultations/$requestId/attachments'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'file': base64Encode(bytes), 'contentType': contentType, 'fileName': name, 'clientId': 'f${DateTime.now().microsecondsSinceEpoch}'}),
    ).timeout(const Duration(seconds: 90));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    sending.close();
    if (response.statusCode >= 400) { say(data['error']?.toString() ?? 'Could not send the file.'); return null; }
    return ChatMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  } catch (_) {
    sending.close();
    say('Could not send the file. Check your internet and try again.');
    return null;
  }
}

class _PickOption extends StatelessWidget {
  const _PickOption({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 26)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// The photo or file inside a chat bubble. Tap a photo to see it full screen,
/// a file to download and open it.
class AttachmentView extends StatelessWidget {
  const AttachmentView({super.key, required this.message, required this.token, required this.mine});
  final ChatMessage message;
  final String? token;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment!;
    if (attachment.deleted) return _DeletedFile(attachment: attachment, mine: mine);
    final url = _attachmentUrl(message.requestId, attachment.id);
    final headers = {if (token != null) 'Authorization': 'Bearer $token'};
    if (message.isImage) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PhotoViewer(url: url, headers: headers, title: attachment.fileName))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Hero(
            tag: url,
            child: Image.network(
              url,
              headers: headers,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null ? child : Container(width: 220, height: 220, color: Colors.black12, alignment: Alignment.center, child: const CircularProgressIndicator(strokeWidth: 2)),
              errorBuilder: (context, error, stack) => Container(width: 220, height: 120, color: Colors.black12, alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined, color: Colors.black38)),
            ),
          ),
        ),
      );
    }
    final fg = mine ? Colors.white : const Color(0xFF14141F);
    final extension = attachment.fileName.contains('.') ? attachment.fileName.split('.').last.toUpperCase() : 'FILE';
    return InkWell(
      onTap: () => _openFile(context, url, headers, attachment),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Container(
            width: 38,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: extension == 'PDF' ? const Color(0xFFDC2626) : const Color(0xFF2563EB), borderRadius: BorderRadius.circular(6)),
            child: Text(extension.length > 4 ? extension.substring(0, 4) : extension, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(attachment.fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(attachment.sizeLabel, style: TextStyle(color: fg.withValues(alpha: 0.6), fontSize: 11.5)),
          ])),
          Icon(Icons.download_rounded, color: fg.withValues(alpha: 0.7), size: 20),
        ]),
      ),
    );
  }

  static Future<void> _openFile(BuildContext context, String url, Map<String, String> headers, ChatAttachment attachment) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chat_${attachment.id}_${attachment.fileName.replaceAll(RegExp(r'[^\w.\- ]'), '_')}');
      if (!await file.exists()) {
        messenger.showSnackBar(const SnackBar(content: Text('Downloading…'), duration: Duration(seconds: 2)));
        final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 90));
        if (response.statusCode == 404) { messenger.showSnackBar(const SnackBar(content: Text('This file was deleted after the chat ended.'))); return; }
        if (response.statusCode != 200) throw const HttpException('download failed');
        await file.writeAsBytes(response.bodyBytes);
      }
      final result = await OpenFilex.open(file.path, type: attachment.contentType);
      if (result.type == ResultType.noAppToOpen) messenger.showSnackBar(const SnackBar(content: Text('No app on this phone can open this file.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not download the file. Try again.')));
    }
  }
}

/// Shown in place of a photo or file the server has deleted.
class _DeletedFile extends StatelessWidget {
  const _DeletedFile({required this.attachment, required this.mine});
  final ChatAttachment attachment;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final fg = (mine ? Colors.white : const Color(0xFF14141F)).withValues(alpha: 0.6);
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: mine ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.auto_delete_outlined, color: fg, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(attachment.contentType.startsWith('image/') ? 'Photo deleted' : 'File deleted', style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
          Text('Removed 5 min after the chat ended', style: TextStyle(color: fg, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url, required this.headers, required this.title});
  final String url;
  final Map<String, String> headers;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(title, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis)),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Hero(tag: url, child: Image.network(url, headers: headers, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
