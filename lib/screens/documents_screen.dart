import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final dirs = <Directory>[];
    final ext = await getExternalStorageDirectory();
    final app = await getApplicationDocumentsDirectory();
    if (ext != null) dirs.add(ext);
    dirs.add(app);

    final found = <File>[];
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      final entries = dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.pdf') || f.path.endsWith('.docx'),
      );
      found.addAll(entries);
    }

    found.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() => _files = found);
  }

  Future<void> _share(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _shareViaWhatsApp(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: file.uri.pathSegments.last,
    );
  }

  Future<void> _shareViaEmail(File file) async {
    final name = file.uri.pathSegments.last;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: name,
      text: 'Please find the attached document: $name',
    );
  }

  Future<void> _delete(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(file.uri.pathSegments.last),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      file.deleteSync();
      _loadFiles();
    }
  }

  String _size(File f) {
    final bytes = f.lengthSync();
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: _files.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No documents yet', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text('Exported PDFs and Word files appear here',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _files.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _FileCard(
                file: _files[i],
                size: _size(_files[i]),
                onShare: () => _share(_files[i]),
                onWhatsApp: () => _shareViaWhatsApp(_files[i]),
                onEmail: () => _shareViaEmail(_files[i]),
                onDelete: () => _delete(_files[i]),
              ),
            ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final File file;
  final String size;
  final VoidCallback onShare, onWhatsApp, onEmail, onDelete;

  const _FileCard({
    required this.file,
    required this.size,
    required this.onShare,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onDelete,
  });

  bool get _isPdf => file.path.endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final name = file.uri.pathSegments.last;
    final modified = file.statSync().modified;
    final dateStr = '${modified.day}/${modified.month}/${modified.year}  ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isPdf ? Icons.picture_as_pdf : Icons.description,
                  color: _isPdf ? Colors.red : const Color(0xFF2B579A),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      Text('$size  •  $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.whatshot, // WhatsApp green
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: onWhatsApp,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  color: Colors.orange,
                  onTap: onEmail,
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  icon: Icons.share,
                  label: 'Share',
                  color: Colors.blueGrey,
                  onTap: onShare,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 12, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 6),
        ),
      ),
    );
  }
}
