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

class ScannerController extends ChangeNotifier {
  CameraController? _camera;
  bool _cameraReady = false, _showCamera = false, _isProcessing = false;
  int? _recaptureIndex;
  final List<ScanPageDto> _pages = [];
  List<Offset>? _detectedCorners;
  int _frameCount = 0, _stableFrames = 0;
  bool _isDetecting = false, _autoCaptureTriggered = false;
  static const int _autoCaptureThreshold = 8;

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

  Future<bool> initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return false;
    final cameras = await availableCameras();
    if (cameras.isEmpty) return false;
    _camera = CameraController(cameras.first, ResolutionPreset.high);
    await _camera!.initialize();
    _cameraReady = true;
    _camera!.startImageStream(_onImageStream); notifyListeners();
    return true;
  }

  void disposeCamera() { _camera?.stopImageStream(); _camera?.dispose(); _camera = null; _cameraReady = false; }

  void openCamera({int? recaptureIndex}) { _recaptureIndex = recaptureIndex; _showCamera = true; notifyListeners(); }

  void closeCamera() { _showCamera = false; _recaptureIndex = null; _detectedCorners = null; _stableFrames = 0; _autoCaptureTriggered = false; notifyListeners(); }

  void _onImageStream(CameraImage image) {
    _frameCount++;
    if (_frameCount % 10 != 0 || _isDetecting) return;
    _isDetecting = true; _detectEdges(image);
  }

  void _detectEdges(CameraImage image) {
    try {
      final yPlane = image.planes[0].bytes;
      final srcW = image.width, srcH = image.height;
      const tw = 40, th = 56;
      final xStep = srcW ~/ tw, yStep = srcH ~/ th;
      var edgeCount = 0;
      int minX = tw, minY = th, maxX = 0, maxY = 0;
      for (int y = 2; y < th - 2; y++) for (int x = 2; x < tw - 2; x++) {
        final sx = (x * xStep + xStep ~/ 2).clamp(xStep, srcW - xStep - 1);
        final sy = (y * yStep + yStep ~/ 2).clamp(yStep, srcH - yStep - 1);
        if ((yPlane[sy * srcW + (sx + xStep)] - yPlane[sy * srcW + (sx - xStep)]).abs() + (yPlane[(sy + yStep) * srcW + sx] - yPlane[(sy - yStep) * srcW + sx]).abs() > 30) {
          edgeCount++;
          if (x < minX) minX = x; if (y < minY) minY = y; if (x > maxX) maxX = x; if (y > maxY) maxY = y;
        }
      }
      final ratio = edgeCount / (tw * th);
      if (ratio > 0.01 && ratio < 0.5 && maxX > minX && maxY > minY) {
        _detectedCorners = [Offset(minX * srcW / tw, minY * srcH / th), Offset(maxX * srcW / tw, minY * srcH / th), Offset(maxX * srcW / tw, maxY * srcH / th), Offset(minX * srcW / tw, maxY * srcH / th)];
        if (!_autoCaptureTriggered && !_isProcessing) {
          _stableFrames++;
          if (_stableFrames >= _autoCaptureThreshold) { _autoCaptureTriggered = true; capture(); }
        }
      } else { _detectedCorners = null; _stableFrames = 0; _autoCaptureTriggered = false; }
    } catch (_) {} _isDetecting = false; notifyListeners();
  }

  Future<void> capture() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final rawPath = '${dir.path}/raw_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File((await _camera!.takePicture()).path).copy(rawPath);
    _isProcessing = true; notifyListeners();
    final gpsFuture = GpsService.captureLocation();
    try {
      final processed = await ImageProcessor.autoEnhance(rawPath);
      _addPage(processed.outputPath, rawPath, FilterPreset.enhanced, gps: await gpsFuture);
    } catch (_) { _addPage(rawPath, rawPath, FilterPreset.original, gps: await gpsFuture); }
  }

  Future<void> smartScan() async {
    _isProcessing = true; notifyListeners();
    try {
      final result = await SmartScannerService.scanDocument();
      if (result.success && result.imagePath != null) {
        final dir = await getApplicationDocumentsDirectory();
        final rawPath = '${dir.path}/smart_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(result.imagePath!).copy(rawPath);
        try {
          final processed = await ImageProcessor.autoEnhance(rawPath);
          _addPage(processed.outputPath, rawPath, FilterPreset.enhanced, gps: await GpsService.captureLocation());
        } catch (_) { _addPage(rawPath, rawPath, FilterPreset.original); }
      }
    } catch (_) {} _isProcessing = false; notifyListeners();
  }

  Future<void> pickFromGallery() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    _isProcessing = true; notifyListeners();
    final dir = await getApplicationDocumentsDirectory();
    final gpsLoc = await GpsService.captureLocation();
    for (final f in picked) {
      final rawPath = '${dir.path}/gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(f.path).copy(rawPath);
      try { final p = await ImageProcessor.autoEnhance(rawPath); _pages.add(ScanPageDto(path: p.outputPath, rawPath: rawPath, filter: FilterPreset.enhanced, gps: gpsLoc)); }
      catch (_) { _pages.add(ScanPageDto(path: rawPath, rawPath: rawPath, filter: FilterPreset.original, gps: gpsLoc)); }
    }
    _isProcessing = false; notifyListeners();
  }

  void _addPage(String path, String rawPath, FilterPreset filter, {gps}) {
    final page = ScanPageDto(path: path, rawPath: rawPath, filter: filter, gps: gps);
    if (_recaptureIndex != null) { _pages[_recaptureIndex!].deleteFiles(); _pages[_recaptureIndex!] = page; _recaptureIndex = null; }
    else { _pages.add(page); }
    closeCamera(); _isProcessing = false; notifyListeners();
  }

  void deletePage(int index) { _pages[index].deleteFiles(); _pages.removeAt(index); notifyListeners(); }

  void reorderPages(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final page = _pages.removeAt(oldIndex); _pages.insert(newIndex, page); notifyListeners();
  }

  void clearAll() { for (final p in _pages) p.deleteFiles(); _pages.clear(); notifyListeners(); }

  Future<void> applyFilter(int index, FilterPreset filter) async {
    final page = _pages[index]; _isProcessing = true; notifyListeners();
    try {
      final processed = await ImageProcessor.applyFilter(page.path, filter);
      final oldPath = page.path;
      _pages[index] = page.copyWith(path: processed.outputPath, filter: filter);
      if (oldPath != page.rawPath) File(oldPath).deleteSync(recursive: true);
    } catch (_) {} _isProcessing = false; notifyListeners();
  }

  Future<void> export(BuildContext ctx, String name, bool pdf, bool docx) async {
    final svc = ExportService(); final appState = Provider.of<AppState>(ctx, listen: false);
    final paths = _pages.map((p) => p.path).toList();
    try {
      if (pdf) { final p = await svc.exportPdf(paths, name); await appState.addExportRecord({'file_name': '$name.pdf', 'file_path': p, 'file_type': 'PDF', 'page_count': _pages.length, 'file_size': File(p).lengthSync()}); }
      if (docx) { final p = await svc.exportDocx(paths, name); await appState.addExportRecord({'file_name': '$name.docx', 'file_path': p, 'file_type': 'DOCX', 'page_count': _pages.length, 'file_size': File(p).lengthSync()}); }
    } catch (e) { rethrow; }
  }

  @override void dispose() { disposeCamera(); super.dispose(); }
}
