import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'file_viewer_screen.dart';
import 'email_composer_screen.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<File> _files = [];
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    if (!mounted) return;
    setState(() => _files = found);

    // Update provider
    final appState = context.read<AppState>();
    appState.updateDocuments(found.map((f) => {
      'name': f.uri.pathSegments.last,
      'path': f.path,
      'size': f.lengthSync(),
      'modified': f.statSync().modified.toIso8601String(),
      'type': f.path.endsWith('.pdf') ? 'PDF' : 'DOCX',
    }).toList());
  }

  List<File> _filteredFiles() {
    final appState = context.read<AppState>();
    final query = appState.searchQuery.toLowerCase();
    final sortBy = appState.sortBy;

    var result = List<File>.from(_files);

    // Search filter
    if (query.isNotEmpty) {
      result = result.where((f) =>
        f.uri.pathSegments.last.toLowerCase().contains(query),
      ).toList();
    }

    // Sort
    switch (sortBy) {
      case 'name':
        result.sort((a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last));
        break;
      case 'size':
        result.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
        break;
      case 'date':
      default:
        result.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        break;
    }

    return result;
  }

  Future<void> _share(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _shareViaWhatsApp(File file) async {
    final name = file.uri.pathSegments.last;
    // Try WhatsApp deep link first — sends text + file info
    final phone = ''; // Optional: add default bank office WhatsApp number
    final text = Uri.encodeComponent('Document from DSA Malawi: $name');
    final waUrl = 'https://api.whatsapp.com/send?${phone.isNotEmpty ? "phone=$phone&" : ""}text=$text';

    try {
      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to share sheet
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: name,
        );
      }
    } catch (_) {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: name,
      );
    }
  }

  Future<void> _shareViaEmail(File file) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmailComposerScreen(file: file)),
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
    final appState = context.watch<AppState>();
    final filtered = _filteredFiles();

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search documents...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => appState.setSearchQuery(v),
              )
            : const Text('Documents'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  appState.setSearchQuery('');
                }
              });
            },
          ),
          // Sort button
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (v) => appState.setSortBy(v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    if (appState.sortBy == 'date') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('Date modified'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    if (appState.sortBy == 'name') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('Name'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'size',
                child: Row(
                  children: [
                    if (appState.sortBy == 'size') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('File size'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: _files.isEmpty
          ? _buildEmptyState()
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('No matches found', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFiles,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _FileCard(
                      file: filtered[i],
                      size: _size(filtered[i]),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => FileViewerScreen(file: filtered[i]),
                      )),
                      onShare: () => _share(filtered[i]),
                      onWhatsApp: () => _shareViaWhatsApp(filtered[i]),
                      onEmail: () => _shareViaEmail(filtered[i]),
                      onDelete: () => _delete(filtered[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }
}

class _FileCard extends StatelessWidget {
  final File file;
  final String size;
  final VoidCallback onTap, onShare, onWhatsApp, onEmail, onDelete;

  const _FileCard({
    required this.file,
    required this.size,
    required this.onTap,
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                    icon: Icons.whatshot,
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
