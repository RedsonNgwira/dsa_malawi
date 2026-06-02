import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class FileViewerScreen extends StatefulWidget {
  final File file;
  const FileViewerScreen({super.key, required this.file});

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  // ignore: unused_field
  PDFViewController? _controller;

  bool get _isPdf => widget.file.path.endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final name = widget.file.uri.pathSegments.last;
    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          if (_isPdf && _totalPages > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text('$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: _isPdf ? _buildPdfView() : _buildDocxFallback(),
    );
  }

  Widget _buildPdfView() {
    return PDFView(
      filePath: widget.file.path,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) => setState(() => _totalPages = pages ?? 0),
      onPageChanged: (page, _) => setState(() => _currentPage = (page ?? 0) + 1),
      onViewCreated: (ctrl) { _controller = ctrl; },
      onError: (e) => _showError('$e'),
      onPageError: (page, e) => _showError('Page $page: $e'),
    );
  }

  Widget _buildDocxFallback() {
    // .docx files can't be rendered natively — show an info card with open-in option
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, size: 80, color: Color(0xFF2B579A)),
            const SizedBox(height: 16),
            Text(widget.file.uri.pathSegments.last,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            const Text(
              'Word documents can be shared and opened\nin Microsoft Word or Google Docs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
