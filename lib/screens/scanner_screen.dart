import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/export_service.dart';
import '../widgets/page_thumbnail.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  final List<String> _pages = []; // file paths
  bool _cameraReady = false;
  bool _showCamera = false;
  int? _recaptureIndex; // null = new page, int = replacing this index

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission required')),
        );
      }
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras.first, ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  Future<void> _openCamera({int? recaptureIndex}) async {
    _recaptureIndex = recaptureIndex;
    if (!_cameraReady) await _initCamera();
    if (mounted) setState(() => _showCamera = true);
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/page_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = await _controller!.takePicture();
    await File(file.path).copy(path);

    setState(() {
      if (_recaptureIndex != null) {
        // Delete old file and replace
        File(_pages[_recaptureIndex!]).deleteSync(recursive: true);
        _pages[_recaptureIndex!] = path;
        _recaptureIndex = null;
      } else {
        _pages.add(path);
      }
      _showCamera = false;
    });
  }

  void _deletePage(int index) {
    File(_pages[index]).deleteSync(recursive: true);
    setState(() => _pages.removeAt(index));
  }

  Future<void> _showExportDialog() async {
    if (_pages.isEmpty) return;
    final nameController = TextEditingController(
      text: 'Document_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
    );
    bool exportPdf = true;
    bool exportDocx = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Export Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'File name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('PDF'),
                value: exportPdf,
                onChanged: (v) => setS(() => exportPdf = v!),
              ),
              CheckboxListTile(
                title: const Text('Word (.docx)'),
                value: exportDocx,
                onChanged: (v) => setS(() => exportDocx = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _export(nameController.text.trim(), exportPdf, exportDocx);
              },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(String name, bool pdf, bool docx) async {
    final svc = ExportService();
    final exported = <String>[];
    try {
      if (pdf) {
        final path = await svc.exportPdf(_pages, name);
        exported.add('PDF: $path');
      }
      if (docx) {
        final path = await svc.exportDocx(_pages, name);
        exported.add('Word: $path');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: ${exported.join(', ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCamera) return _buildCameraView();
    return _buildScannerView();
  }

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // Corner guides
          Positioned.fill(
            child: CustomPaint(painter: _CornerPainter()),
          ),
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => setState(() { _showCamera = false; _recaptureIndex = null; }),
                ),
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.white24,
                    ),
                  ),
                ),
                const SizedBox(width: 50),
              ],
            ),
          ),
          Positioned(
            top: 50, left: 16,
            child: Text(
              _recaptureIndex != null
                  ? 'Recapture page ${_recaptureIndex! + 1}'
                  : 'Page ${_pages.length + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              onPressed: _showExportDialog,
            ),
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () {
    for (var p in _pages) { File(p).deleteSync(recursive: true); }
                setState(() => _pages.clear());
              },
            ),
        ],
      ),
      body: _pages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.document_scanner_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No pages yet',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + to capture a page',
                      style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: _pages.length,
              itemBuilder: (_, i) => PageThumbnail(
                imagePath: _pages[i],
                pageNumber: i + 1,
                onRecapture: () => _openCamera(recaptureIndex: i),
                onDelete: () => _deletePage(i),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCamera(),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Page'),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const len = 30.0;
    const margin = 40.0;
    final corners = [
      [Offset(margin, margin), Offset(margin + len, margin), Offset(margin, margin + len)],
      [Offset(size.width - margin, margin), Offset(size.width - margin - len, margin), Offset(size.width - margin, margin + len)],
      [Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), Offset(margin, size.height - margin - len)],
      [Offset(size.width - margin, size.height - margin), Offset(size.width - margin - len, size.height - margin), Offset(size.width - margin, size.height - margin - len)],
    ];
    for (final c in corners) {
      canvas.drawLine(c[0], c[1], paint);
      canvas.drawLine(c[0], c[2], paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
