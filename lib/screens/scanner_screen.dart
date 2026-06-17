import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/export_service.dart';
import '../services/image_processor.dart';
import '../widgets/page_thumbnail.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _controller;
  final List<_ScanPage> _pages = [];
  bool _cameraReady = false;
  bool _showCamera = false;
  int? _recaptureIndex;
  bool _isProcessing = false;

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
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rawPath = '${dir.path}/raw_$timestamp.jpg';
    final file = await _controller!.takePicture();
    await File(file.path).copy(rawPath);

    // Process the image (auto-crop + enhance)
    setState(() => _isProcessing = true);
    try {
      final processed = await ImageProcessor.autoEnhance(rawPath);
      final page = _ScanPage(
        path: processed.outputPath,
        rawPath: rawPath,
        filter: FilterPreset.enhanced,
      );

      setState(() {
        if (_recaptureIndex != null) {
          // Delete old files
          final old = _pages[_recaptureIndex!];
          File(old.path).deleteSync(recursive: true);
          if (old.rawPath != old.path) File(old.rawPath).deleteSync(recursive: true);
          _pages[_recaptureIndex!] = page;
          _recaptureIndex = null;
        } else {
          _pages.add(page);
        }
        _showCamera = false;
        _isProcessing = false;
      });
    } catch (e) {
      // Fall back to unprocessed image
      final page = _ScanPage(path: rawPath, rawPath: rawPath, filter: FilterPreset.original);
      setState(() {
        if (_recaptureIndex != null) {
          final old = _pages[_recaptureIndex!];
          File(old.path).deleteSync(recursive: true);
          _pages[_recaptureIndex!] = page;
          _recaptureIndex = null;
        } else {
          _pages.add(page);
        }
        _showCamera = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    setState(() => _isProcessing = true);
    final dir = await getApplicationDocumentsDirectory();

    for (final picked in pickedFiles) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawPath = '${dir.path}/gallery_$timestamp.jpg';
      await File(picked.path).copy(rawPath);

      try {
        final processed = await ImageProcessor.autoEnhance(rawPath);
        _pages.add(_ScanPage(
          path: processed.outputPath,
          rawPath: rawPath,
          filter: FilterPreset.enhanced,
        ));
      } catch (e) {
        _pages.add(_ScanPage(path: rawPath, rawPath: rawPath, filter: FilterPreset.original));
      }
    }

    setState(() => _isProcessing = false);
  }

  void _deletePage(int index) {
    final page = _pages[index];
    File(page.path).deleteSync(recursive: true);
    if (page.rawPath != page.path) File(page.rawPath).deleteSync(recursive: true);
    setState(() => _pages.removeAt(index));
  }

  Future<void> _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
    });
    return Future.value();
  }

  void _showFilterDialog(int index) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: FilterPreset.values.map((filter) {
            final name = filter.name;
            final displayName = name[0].toUpperCase() + name.substring(1);
            final isCurrent = _pages[index].filter == filter;
            return ListTile(
              leading: Icon(
                isCurrent ? Icons.check_circle : Icons.circle_outlined,
                color: isCurrent ? Colors.green : null,
              ),
              title: Text(displayName),
              trailing: _filterPreviewIcon(filter),
              onTap: () async {
                Navigator.pop(ctx);
                final page = _pages[index];
                setState(() => _isProcessing = true);
                try {
                  final processed = await ImageProcessor.applyFilter(page.path, filter);
                  // Keep the raw path, update the display path and filter
                  final oldPath = page.path;
                  _pages[index] = _ScanPage(
                    path: processed.outputPath,
                    rawPath: page.rawPath,
                    filter: filter,
                  );
                  if (oldPath != page.rawPath) {
                    File(oldPath).deleteSync(recursive: true);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Filter failed: $e')),
                    );
                  }
                }
                setState(() => _isProcessing = false);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _filterPreviewIcon(FilterPreset filter) {
    IconData icon;
    switch (filter) {
      case FilterPreset.original:
        icon = Icons.image;
      case FilterPreset.grayscale:
        icon = Icons.blur_on;
      case FilterPreset.blackAndWhite:
        icon = Icons.brightness_2;
      case FilterPreset.highContrast:
        icon = Icons.contrast;
      case FilterPreset.enhanced:
        icon = Icons.auto_fix_high;
    }
    return Icon(icon, size: 20, color: Colors.grey);
  }

  void _clearAll() {
    for (var p in _pages) {
      File(p.path).deleteSync(recursive: true);
      if (p.rawPath != p.path) File(p.rawPath).deleteSync(recursive: true);
    }
    setState(() => _pages.clear());
  }

  Future<void> _showExportDialog() async {
    if (_pages.isEmpty) return;
    final nameController = TextEditingController(
      text: 'Document_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
    );
    bool exportPdf = true;
    bool exportDocx = false;
    bool autoEnhance = true;

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
              const SizedBox(height: 8),
              Text(
                '${_pages.length} page(s)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
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
              CheckboxListTile(
                title: const Text('Auto-enhance images'),
                subtitle: const Text('Crop, straighten, enhance contrast'),
                value: autoEnhance,
                onChanged: (v) => setS(() => autoEnhance = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _export(nameController.text.trim(), exportPdf, exportDocx, autoEnhance);
              },
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(String name, bool pdf, bool docx, bool enhance) async {
    final svc = ExportService();
    final appState = context.read<AppState>();
    final exported = <String>[];

    // Show progress
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting...'), duration: Duration(seconds: 30)),
      );
    }

    try {
      final paths = _pages.map((p) => p.path).toList();

      if (pdf) {
        final path = await svc.exportPdf(paths, name);
        exported.add('PDF: $path');
        final file = File(path);
        await appState.addExportRecord({
          'file_name': '$name.pdf',
          'file_path': path,
          'file_type': 'PDF',
          'page_count': _pages.length,
          'file_size': file.lengthSync(),
        });
      }
      if (docx) {
        final path = await svc.exportDocx(paths, name);
        exported.add('Word: $path');
        final file = File(path);
        await appState.addExportRecord({
          'file_name': '$name.docx',
          'file_path': path,
          'file_type': 'DOCX',
          'page_count': _pages.length,
          'file_size': file.lengthSync(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved: ${exported.join(', ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Processing image...', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                  onPressed: () => setState(() {
                    _showCamera = false;
                    _recaptureIndex = null;
                  }),
                ),
                GestureDetector(
                  onTap: _isProcessing ? null : _capture,
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
          if (_pages.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: 'Import from gallery',
              onPressed: _pickFromGallery,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              onPressed: _showExportDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () {
                _clearAll();
              },
            ),
          ],
        ],
      ),
      body: _pages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.document_scanner_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No pages yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Tap + to capture or import from gallery',
                      style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            )
          : _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : ReorderableGridView(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  onReorder: _reorderPages,
                  children: List.generate(_pages.length, (i) {
                    final page = _pages[i];
                    return PageThumbnail(
                      key: ValueKey(page.path),
                      imagePath: page.path,
                      pageNumber: i + 1,
                      filterLabel: page.filter != FilterPreset.enhanced
                          ? page.filter.name
                          : null,
                      onRecapture: () => _openCamera(recaptureIndex: i),
                      onDelete: () => _deletePage(i),
                      onFilter: () => _showFilterDialog(i),
                    );
                  }),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCamera(),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Page'),
      ),
    );
  }
}

/// Internal model for a scanned page with its filter state.
class _ScanPage {
  final String path;
  final String rawPath;
  final FilterPreset filter;

  _ScanPage({
    required this.path,
    required this.rawPath,
    required this.filter,
  });
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

/// Wrapper widget that delegates to ReorderableGridView's builder.
class ReorderableGridView extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final SliverGridDelegate gridDelegate;
  final ReorderCallback onReorder;
  final List<Widget> children;

  const ReorderableGridView({
    super.key,
    required this.gridDelegate,
    required this.onReorder,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final listChildren = children;
    return ReorderableBuilder(
      onReorder: onReorder,
      children: listChildren,
      builder: (items, handleBuilder) {
        return GridView.builder(
          padding: padding,
          gridDelegate: gridDelegate,
          itemCount: items.length,
          itemBuilder: (_, i) => handleBuilder(items[i], i),
        );
      },
    );
  }
}

/// A simple reorderable builder that wraps children for drag-to-reorder.
class ReorderableBuilder extends StatefulWidget {
  final List<Widget> children;
  final ReorderCallback onReorder;
  final Widget Function(List<Widget> children, Widget Function(Widget child, int index) handleBuilder) builder;

  const ReorderableBuilder({
    super.key,
    required this.children,
    required this.onReorder,
    required this.builder,
  });

  @override
  State<ReorderableBuilder> createState() => _ReorderableBuilderState();
}

class _ReorderableBuilderState extends State<ReorderableBuilder> {
  List<Widget> _children = [];

  @override
  void initState() {
    super.initState();
    _children = List.from(widget.children);
  }

  @override
  void didUpdateWidget(ReorderableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children != widget.children) {
      _children = List.from(widget.children);
    }
  }

  Widget _buildHandle(Widget child, int index) {
    return LongPressDraggable(
      key: child.key,
      data: index,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 120,
          height: 160,
          child: Opacity(opacity: 0.8, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      onDragEnd: (details) {
        // Handle drop position via drag target
      },
      child: DragTarget<int>(
        onAcceptWithDetails: (details) {
          final draggedIndex = details.data;
          final targetIndex = index;
          if (draggedIndex != targetIndex) {
            setState(() {
              final moved = _children.removeAt(draggedIndex);
              _children.insert(targetIndex, moved);
            });
            widget.onReorder(draggedIndex, targetIndex);
          }
        },
        builder: (context, candidateData, rejectedData) => child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_children, _buildHandle);
  }
}
