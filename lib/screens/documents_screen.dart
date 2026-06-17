import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'file_viewer_screen.dart';
import 'email_composer_screen.dart';
import '../features/documents/widgets/document_card.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<File> _files = [];
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() { super.initState(); _loadFiles(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadFiles() async {
    final dirs = <Directory>[];
    final ext = await getExternalStorageDirectory();
    final app = await getApplicationDocumentsDirectory();
    if (ext != null) dirs.add(ext);
    dirs.add(app);
    final found = <File>[];
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      found.addAll(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.pdf') || f.path.endsWith('.docx')));
    }
    found.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    if (!mounted) return;
    setState(() => _files = found);
    context.read<AppState>().updateDocuments(found.map((f) => {'name': f.uri.pathSegments.last, 'path': f.path, 'size': f.lengthSync(), 'modified': f.statSync().modified.toIso8601String(), 'type': f.path.endsWith('.pdf') ? 'PDF' : 'DOCX'}).toList());
  }

  List<File> _filtered() {
    final appState = context.read<AppState>();
    final q = appState.searchQuery.toLowerCase();
    final s = appState.sortBy;
    var r = List<File>.from(_files);
    if (q.isNotEmpty) r = r.where((f) => f.uri.pathSegments.last.toLowerCase().contains(q)).toList();
    switch (s) {
      case 'name': r.sort((a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last)); break;
      case 'size': r.sort((a, b) => b.lengthSync().compareTo(a.lengthSync())); break;
      default: r.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    }
    return r;
  }

  Future<void> _share(File f) async => Share.shareXFiles([XFile(f.path)]);
  Future<void> _whatsApp(File f) async {
    final uri = Uri.parse('https://api.whatsapp.com/send?text=Document from DSA Malawi: ${Uri.encodeComponent(f.uri.pathSegments.last)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  void _email(File f) => Navigator.push(context, MaterialPageRoute(builder: (_) => EmailComposerScreen(file: f)));
  void _view(File f) => Navigator.push(context, MaterialPageRoute(builder: (_) => FileViewerScreen(file: f)));
  void _delete(File f) async {
    await f.delete();
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final files = _filtered();
    return Scaffold(
      appBar: AppBar(title: Text(_showSearch ? '' : 'Documents', style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: Icon(_showSearch ? Icons.close : Icons.search), onPressed: () => setState(() { _showSearch = !_showSearch; if (!_showSearch) appState.setSearchQuery(''); })),
          if (!_showSearch) ...[
            PopupMenuButton<String>(icon: const Icon(Icons.sort), onSelected: (v) => appState.setSortBy(v), itemBuilder: (_) => [const PopupMenuItem(value: 'date', child: Text('Sort by Date')), const PopupMenuItem(value: 'name', child: Text('Sort by Name')), const PopupMenuItem(value: 'size', child: Text('Sort by Size'))]),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
          ],
        ],
      ),
      body: Column(children: [
        if (_showSearch)
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: TextField(
            controller: _searchCtrl, autofocus: true, decoration: InputDecoration(hintText: 'Search documents...', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            onChanged: (v) => appState.setSearchQuery(v),
          )),
        Expanded(
          child: files.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300), const SizedBox(height: 12), Text('No documents yet', style: TextStyle(color: Colors.grey.shade500))]))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: files.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DocumentCard(
                      file: files[i],
                      onTap: () => _view(files[i]),
                      onWhatsApp: () => _whatsApp(files[i]),
                      onEmail: () => _email(files[i]),
                      onShare: () => _share(files[i]),
                      onDelete: () => _delete(files[i]),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}
