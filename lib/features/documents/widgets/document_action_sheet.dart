import 'package:flutter/material.dart';

/// Context menu sheet for document operations (share, email, delete, info).
class DocumentActionSheet extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final VoidCallback onShare;
  final VoidCallback onEmail;
  final VoidCallback onDelete;
  final VoidCallback onInfo;

  const DocumentActionSheet({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.onShare,
    required this.onEmail,
    required this.onDelete,
    required this.onInfo,
  });

  static void show(BuildContext context, {
    required String fileName, required String fileSize,
    required VoidCallback onShare, required VoidCallback onEmail,
    required VoidCallback onDelete, required VoidCallback onInfo,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(fileSize, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Divider(),
            ListTile(leading: const Icon(Icons.share), title: const Text('Share'), onTap: () { Navigator.pop(context); onShare(); }),
            ListTile(leading: const Icon(Icons.email), title: const Text('Send via Email'), onTap: () { Navigator.pop(context); onEmail(); }),
            ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); onDelete(); }),
            ListTile(leading: const Icon(Icons.info_outline), title: const Text('File Info'), onTap: () { Navigator.pop(context); onInfo(); }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
