import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/image_processor.dart';
import '../../../services/gps_service.dart';
import '../../../providers/app_state.dart';
import '../../../services/export_service.dart';
import '../providers/smart_scanner_service.dart';
import '../screens/scan_page_model.dart';

/// Holds all scanner logic: camera, document detection, capture, export.
class ScannerController extends ChangeNotifier {
  CameraController? _camera;
  bool _cameraReady = false;
  bool _showCamera = false;
  int? _recaptureIndex;
  bool _isProcessing = false;
  final List<ScanPageDto> _pages = [];
  List<Offset>? _detectedCorners;
  int _frameCount = 0;
  bool _isDetecting = false;
  int _stableFrames = 0;
  bool _autoCaptureTriggered = false;
  static const int _autoCaptureThreshold = 8;

  // Getters
  CameraController? get camera => _camera;
  bool get cameraReady => _cameraReady;
  bool get showCamera => _showCamera;
  bool get isProcessing => _isProcessing;
  List<ScanPageDto> get pages => List.unmodifiable(_pages);
  List<Offset>? get detectedCorners => _detectedCorners;
  int get stableFrames => _stableFrames;
  int get autoCaptureThreshold => _autoCaptureThreshold;
  bool get autoCaptureReady => _stableFrames >= _autoCaptureThreshold;
  bool get isEmpty => _pages.isEmpty;

  /// Initialize camera
  Future<bool> initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return false;
    final cameras = await availableCameras();
    if (cameras.isEmpty) return false;
    _camera = CameraController(cameras.first, ResolutionPreset.high);
    await _camera!.initialize();
    _cameraReady = true;
    _camera!.startImageStream(_onImageStream);
    notifyListeners();
    return true;
  }

  void disposeCamera() {
    _camera?.stopImageStream();
    _camera?.dispose();
    _camera = null;
    _cameraReady = false;
  }

  void openCamera({int? recaptureIndex}) {
    _recaptureIndex = recaptureIndex;
    _showCamera = true;
    notifyListeners();
  }

  void closeCamera() {
    _showCamera = false;
    _recaptureIndex = null;
    _detectedCorners = null;
    _stableFrames = 0;
    _autoCaptureTriggered = false;
    notifyListeners();
  }

  /// Image stream callback for live edge detection
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
        _detectedCorners = [
          Offset(minX * scaleX, minY * scaleX),
          Offset(maxX * scaleX, minY * scaleY),
          Offset(maxX * scaleX, maxY * scaleY),
          Offset(minX * scaleX, maxY * scaleY),
        ];

        if (!_autoCaptureTriggered && !_isProcessing) {
          _stableFrames++;
          if (_stableFrames >= _autoCaptureThreshold) {
            _autoCaptureTriggered = true;
            capture();
          }
        }
      } else {
        _detectedCorners = null;
        _stableFrames = 0;
        _autoCaptureTriggered = false;
      }
    } catch (_) {}
    _isDetecting = false;
    notifyListeners();
  }

  Future<void> capture() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rawPath = '${dir.path}/raw_$timestamp.jpg';
    final file = await _camera!.takePicture();
    await File(file.path).copy(rawPath);

    _isProcessing = true;
    notifyListeners();

    final gpsFuture = GpsService.captureLocation();
    try {
      final processed = await ImageProcessor.autoEnhance(rawPath);
      final gpsLoc = await gpsFuture;
      _addPage(processed.outputPath, rawPath, FilterPreset.enhanced, gps: gpsLoc);
    } catch (_) {
      _addPage(rawPath, rawPath, FilterPreset.original, gps: await gpsFuture);
    }
  }

  Future<void> smartScan() async {
    _isProcessing = true;
    notifyListeners();
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
    } catch (_) {}
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    _isProcessing = true;
    notifyListeners();
    final dir = await getApplicationDocumentsDirectory();
    final gpsLoc = await GpsService.captureLocation();

    for (final picked in pickedFiles) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final rawPath = '${dir.path}/gallery_$timestamp.jpg';
      await File(picked.path).copy(rawPath);
      try {
        final processed = await ImageProcessor.autoEnhance(rawPath);
        _pages.add(ScanPageDto(path: processed.outputPath, rawPath: rawPath, filter: FilterPreset.enhanced, gps: gpsLoc));
      } catch (_) {
        _pages.add(ScanPageDto(path: rawPath, rawPath: rawPath, filter: FilterPreset.original, gps: gpsLoc));
      }
    }
    _isProcessing = false;
    notifyListeners();
  }

  void _addPage(String path, String rawPath, FilterPreset filter, {gps}) {
    final page = ScanPageDto(path: path, rawPath: rawPath, filter: filter, gps: gps);
    if (_recaptureIndex != null) {
      final old = _pages[_recaptureIndex!];
      old.deleteFiles();
      _pages[_recaptureIndex!] = page;
      _recaptureIndex = null;
    } else {
      _pages.add(page);
    }
    closeCamera();
    _isProcessing = false;
    notifyListeners();
  }

  void deletePage(int index) {
    _pages[index].deleteFiles();
    _pages.removeAt(index);
    notifyListeners();
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
    notifyListeners();
  }

  void clearAll() {
    for (final p in _pages) { p.deleteFiles(); }
    _pages.clear();
    notifyListeners();
  }

  /// Apply a filter to a page and replace its processed image.
  Future<void> applyFilter(int index, FilterPreset filter) async {
    final page = _pages[index];
    _isProcessing = true;
    notifyListeners();
    try {
      final processed = await ImageProcessor.applyFilter(page.path, filter);
      final oldPath = page.path;
      _pages[index] = page.copyWith(path: processed.outputPath, filter: filter);
      if (oldPath != page.rawPath) File(oldPath).deleteSync(recursive: true);
    } catch (_) {}
    _isProcessing = false;
    notifyListeners();
  }

  /// Export pages to PDF and/or DOCX.
  Future<void> export(BuildContext context, String name, bool pdf, bool docx) async {
    final svc = ExportService();
    final appState = Provider.of<AppState>(context, listen: false);
    final paths = _pages.map((p) => p.path).toList();
    try {
      if (pdf) {
        final path = await svc.exportPdf(paths, name);
        final file = File(path);
        await appState.addExportRecord({
          'file_name': '$name.pdf', 'file_path': path, 'file_type': 'PDF',
          'page_count': _pages.length, 'file_size': file.lengthSync(),
        });
      }
      if (docx) {
        final path = await svc.exportDocx(paths, name);
        final file = File(path);
        await appState.addExportRecord({
          'file_name': '$name.docx', 'file_path': path, 'file_type': 'DOCX',
          'page_count': _pages.length, 'file_size': file.lengthSync(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    disposeCamera();
    super.dispose();
  }
}
