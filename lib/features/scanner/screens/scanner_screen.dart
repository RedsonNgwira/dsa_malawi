import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_state.dart';
import '../../../services/export_service.dart';
import '../../../services/gps_service.dart';
import '../../../services/image_processor.dart';
import '../../../widgets/page_thumbnail.dart';
import '../providers/smart_scanner_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  final List<_ScanPage> _pages = [];
  bool _cameraReady = false;
  bool _showCamera = false;
  int? _recaptureIndex;
  bool _isProcessing = false;
  List<Offset>? _detectedCorners;
  int _frameCount = 0;
  bool _isDetecting = false;
  int _stableFrames = 0;
  bool _autoCaptureTriggered = false;
  static const int _autoCaptureThreshold = 8; // ~400ms stable (8 frames × 10th frame sampling)

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) _snack('Camera permission required');
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _controller = CameraController(cameras.first, ResolutionPreset.high);
    await _controller!.initialize();
    if (mounted) {
      setState(() => _cameraReady = true);
      _controller!.startImageStream(_onImageStream);
    }
  }

  void _onImageStream(CameraImage image) {
    _frameCount++;
    if (_frameCount % 10 != 0 || _isDetecting) return;
    _isDetecting = true;
    _detectEdges(image);
  }

  void _detectEdges(CameraImage image) {
    try {
      final yPlane = image.planes[0].bytes;
      final srcW = image.width;
      final srcH = image.height;
      const tw = 40, th = 56;
      final xStep = srcW ~/ tw;
      final yStep = srcH ~/ th;

      // Simple edge detection on downsampled Y plane
      var edgeCount = 0;
      int minX = tw, minY = th, maxX = 0, maxY = 0;

      for (int y = 2; y < th - 2; y++) {
        for (int x = 2; x < tw - 2; x++) {
          final sx = (x * xStep + xStep ~/ 2).clamp(xStep, srcW - xStep - 1);
          final sy = (y * yStep + yStep ~/ 2).clamp(yStep, srcH - yStep - 1);
          final gx = (yPlane[sy * srcW + (sx + xStep)] - yPlane[sy * srcW + (sx - xStep)]).abs();
          final gy = (yPlane[(sy + yStep) * srcW + sx] - yPlane[(sy - yStep) * srcW + sx]).abs();
          if (gx + gy > 30) {
            edgeCount++;
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
      }

      final ratio = edgeCount / (tw * th);
      if (ratio > 0.01 && ratio < 0.5 && maxX > minX && maxY > minY) {
        final scaleX = srcW / tw;
        final scaleY = srcH / th;
        final newCorners = [
          Offset(minX * scaleX, minY * scaleY),
          Offset(maxX * scaleX, minY * scaleY),
          Offset(maxX * scaleX, maxY * scaleY),
          Offset(minX * scaleX, maxY * scaleY),
        ];
        if (mounted) setState(() => _detectedCorners = newCorners);

        // Auto-capture: increment stable counter
        if (!_autoCaptureTriggered && !_isProcessing) {
          _stableFrames++;
          if (_stableFrames >= _autoCaptureThreshold) {
            _autoCaptureTriggered = true;
            _capture();
          }
        }
      } else if (mounted) {
        setState(() {
          _detectedCorners = null;
          _stableFrames = 0;
          _autoCaptureTriggered = false;
        });
      }
    } catch (_) {}
    _isDetecting = false;
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

    setState(() => _isProcessing = true);
    final gpsFuture = GpsService.captureLocation();

    try {
      final processed = await ImageProcessor.autoEnhance(rawPath);
      final gpsLoc = await gpsFuture;
      _addPage(processed.outputPath, rawPath, FilterPreset.enhanced, gps: gpsLoc);
    } catch (_) {
      _addPage(rawPath, rawPath, FilterPreset.original, gps: await gpsFuture);
    }
  }

  void _addPage(String path, String rawPath, FilterPreset filter, {gps}) {
    setState(() {
      if (_recaptureIndex != null) {
        final old = _pages[_recaptureIndex!];
        File(old.path).deleteSync(recursive: true);
        if (old.rawPath != old.path) File(old.rawPath).deleteSync(recursive: true);
        _pages[_recaptureIndex!] = _ScanPage(path: path, rawPath: rawPath, filter: filter, gps: gps);
        _recaptureIndex = null;
      } else {
        _pages.add(_ScanPage(path: path, rawPath: rawPath, filter: filter, gps: gps));
      }
      _showCamera = false;
      _isProcessing = false;
    });
  }

  Future<void> _smartScan() async {
    setState(() => _isProcessing = true);
    try {
      final result = await SmartScannerService.scanDocument();
      if (result.success && result.imagePath != null) {
        final dir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final rawPath = '${dir.path}/smart_$timestamp.jpg';
        await File(result.imagePath!).copy(rawPath);
        try {
          final processed = await ImageProcessor.autoEnhance(rawPath);
          final gpsLoc = await GpsService.captureLocation();
          _addPage(processed.outputPath, rawPath, FilterPreset.enhanced, gps: gpsLoc);
        } catch (_) {
          _addPage(rawPath, rawPath, FilterPreset.original);
        }
      }
    } catch (e) {
      if (mounted) _snack('Smart scan failed');
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    setState(() => _isProcessing = true);
    final dir = await getApplicationDocumentsDirectory();
    final gpsLoc = await GpsService.captureLocation();

    for (final picked in pickedFiles) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawPath = '${dir.path}/gallery_$timestamp.jpg';
      await File(picked.path).copy(rawPath);
      try {
        final processed = await ImageProcessor.autoEnhance(rawPath);
        _pages.add(_ScanPage(path: processed.outputPath, rawPath: rawPath, filter: FilterPreset.enhanced, gps: gpsLoc));
      } catch (_) {
        _pages.add(_ScanPage(path: rawPath, rawPath: rawPath, filter: FilterPreset.original, gps: gpsLoc));
      }
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  void _deletePage(int index) {
    final page = _pages[index];
    File(page.path).deleteSync(recursive: true);
    if (page.rawPath != page.path) File(page.rawPath).deleteSync(recursive: true);
    setState(() => _pages.removeAt(index));
  }

  void _clearAll() {
    for (var p in _pages) {
      File(p.path).deleteSync(recursive: true);
      if (p.rawPath != p.path) File(p.rawPath).deleteSync(recursive: true);
    }
    setState(() => _pages.clear());
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_showCamera) return _buildCamera();
    if (_isProcessing) return _buildProcessing();

    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        actions: [
          if (_pages.isNotEmpty) ...[
            IconButton(icon: const Icon(Icons.photo_library_outlined), tooltip: 'Import', onPressed: _pickFromGallery),
            IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Export', onPressed: _pages.isEmpty ? null : () => _showExportDialog(context)),
            IconButton(icon: const Icon(Icons.delete_sweep_outlined), tooltip: 'Clear all', onPressed: _clearAll),
          ],
        ],
      ),
      body: _pages.isEmpty ? _buildEmpty(colorScheme) : _buildGrid(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Smart Scan — the hero feature
          ScaleTransition(
            scale: _pulseAnim,
            child: FloatingActionButton(
              heroTag: 'smart_scan',
              onPressed: _smartScan,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.auto_fix_high, size: 28),
            ),
          ),
          const SizedBox(height: AppTheme.sm),
          FloatingActionButton.small(
            heroTag: 'add_page',
            onPressed: () => _openCamera(),
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurface,
            child: const Icon(Icons.camera_alt_outlined, size: 20),
          ),
          const SizedBox(height: AppTheme.sm),
          FloatingActionButton.small(
            heroTag: 'gallery',
            onPressed: _pickFromGallery,
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurface,
            child: const Icon(Icons.photo_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: Icon(Icons.document_scanner_outlined, size: 48, color: scheme.primary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: AppTheme.lg),
          Text('No pages yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          const SizedBox(height: AppTheme.sm),
          Text(
            'Tap the scan button to capture\na document',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.5), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.sm,
        mainAxisSpacing: AppTheme.sm,
        childAspectRatio: 0.72,
      ),
      itemCount: _pages.length,
      itemBuilder: (_, i) {
        final page = _pages[i];
        return PageThumbnail(
          imagePath: page.path,
          pageNumber: i + 1,
          filterLabel: page.filter != FilterPreset.enhanced ? page.filter.name : null,
          onRecapture: () => _openCamera(recaptureIndex: i),
          onDelete: () => _deletePage(i),
          onFilter: () => _showFilterDialog(i),
          gpsLabel: page.hasGps ? '📍' : null,
        );
      },
    );
  }

  Widget _buildProcessing() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.lg),
            Text('Processing...', style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          _recaptureIndex != null ? 'Recapture page ${_recaptureIndex! + 1}' : 'Page ${_pages.length + 1}',
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() { _showCamera = false; _recaptureIndex = null; }),
        ),
        actions: [],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraReady && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Live document edge detection overlay
          if (_detectedCorners != null)
            CustomPaint(
              painter: _LiveDocumentBorder(corners: _detectedCorners!),
              size: Size.infinite,
            ),

          // Corner guides
          Positioned.fill(
            child: CustomPaint(painter: _CornerPainter(color: Colors.white24)),
          ),

          // Detection indicator
          if (_detectedCorners != null)
            Positioned(
              top: 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('📄 Document detected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + AppTheme.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Auto-capture countdown ring
            SizedBox(
              width: 72, height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_stableFrames > 0 && _stableFrames < _autoCaptureThreshold)
                    CircularProgressIndicator(
                      value: _stableFrames / _autoCaptureThreshold,
                      strokeWidth: 3,
                      color: Colors.amberAccent,
                      backgroundColor: Colors.white24,
                    ),
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      width: 62, height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _detectedCorners != null ? Colors.amberAccent : Colors.white,
                          width: _detectedCorners != null ? 5 : 4,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _detectedCorners != null
                              ? Colors.amberAccent.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.95),
                        ),
                        child: _detectedCorners != null
                            ? const Icon(Icons.auto_awesome, color: Colors.black87, size: 22)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(int index) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.xs, bottom: AppTheme.sm),
                child: Text('Filter', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const Divider(),
              ...FilterPreset.values.map((filter) {
                final isCurrent = _pages[index].filter == filter;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isCurrent ? Icons.check_circle : Icons.circle_outlined,
                    color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                    size: 20,
                  ),
                  title: Text(_filterName(filter), style: TextStyle(fontSize: 14, fontWeight: isCurrent ? FontWeight.w600 : null)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final page = _pages[index];
                    setState(() => _isProcessing = true);
                    try {
                      final processed = await ImageProcessor.applyFilter(page.path, filter);
                      final oldPath = page.path;
                      _pages[index] = _ScanPage(path: processed.outputPath, rawPath: page.rawPath, filter: filter, gps: page.gps);
                      if (oldPath != page.rawPath) File(oldPath).deleteSync(recursive: true);
                    } catch (_) {}
                    if (mounted) setState(() => _isProcessing = false);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _filterName(FilterPreset f) => f.name[0].toUpperCase() + f.name.substring(1);

  void _showExportDialog(BuildContext context) {
    final nameCtrl = TextEditingController(
      text: 'Document_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
    );
    bool pdf = true, docx = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: const Text('Export'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'File name')),
            const SizedBox(height: AppTheme.sm),
            Text('${_pages.length} page(s)', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: AppTheme.sm),
            CheckboxListTile(title: const Text('PDF'), value: pdf, onChanged: (v) => pdf = v!, contentPadding: EdgeInsets.zero),
            CheckboxListTile(title: const Text('Word (.docx)'), value: docx, onChanged: (v) => docx = v!, contentPadding: EdgeInsets.zero),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () { Navigator.pop(ctx); _export(nameCtrl.text.trim(), pdf, docx); }, child: const Text('Export')),
        ],
      ),
    );
  }

  Future<void> _export(String name, bool pdf, bool docx) async {
    final svc = ExportService();
    final appState = context.read<AppState>();
    final paths = _pages.map((p) => p.path).toList();
    try {
      if (pdf) {
        final path = await svc.exportPdf(paths, name);
        final file = File(path);
        await appState.addExportRecord({'file_name': '$name.pdf', 'file_path': path, 'file_type': 'PDF', 'page_count': _pages.length, 'file_size': file.lengthSync()});
      }
      if (docx) {
        final path = await svc.exportDocx(paths, name);
        final file = File(path);
        await appState.addExportRecord({'file_name': '$name.docx', 'file_path': path, 'file_type': 'DOCX', 'page_count': _pages.length, 'file_size': file.lengthSync()});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    }
  }
}

class _ScanPage {
  final String path, rawPath;
  final FilterPreset filter;
  final GpsLocation? gps;
  _ScanPage({required this.path, required this.rawPath, required this.filter, this.gps});
  bool get hasGps => gps != null;
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({this.color = Colors.white});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke;
    const len = 28.0, margin = 36.0;
    for (final c in [
      [Offset(margin, margin), Offset(margin + len, margin), Offset(margin, margin + len)],
      [Offset(size.width - margin, margin), Offset(size.width - margin - len, margin), Offset(size.width - margin, margin + len)],
      [Offset(margin, size.height - margin), Offset(margin + len, size.height - margin), Offset(margin, size.height - margin - len)],
      [Offset(size.width - margin, size.height - margin), Offset(size.width - margin - len, size.height - margin), Offset(size.width - margin, size.height - margin - len)],
    ]) {
      canvas.drawLine(c[0], c[1], paint);
      canvas.drawLine(c[0], c[2], paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

/// Painter for live document edge detection border
class _LiveDocumentBorder extends CustomPainter {
  final List<Offset> corners;
  _LiveDocumentBorder({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;
    final paint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();
    canvas.drawPath(path, paint);
    // Corner dots
    final dot = Paint()..color = Colors.amberAccent..style = PaintingStyle.fill;
    for (final c in corners) { canvas.drawCircle(c, 5, dot); }
  }

  @override
  bool shouldRepaint(covariant _LiveDocumentBorder old) {
    if (old.corners.length != corners.length) return true;
    for (int i = 0; i < corners.length; i++) {
      if (old.corners[i] != corners[i]) return true;
    }
    return false;
  }
}
