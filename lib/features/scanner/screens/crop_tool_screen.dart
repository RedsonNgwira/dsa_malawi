import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Manual crop tool for scanned pages.
/// User drags corners to select crop region, then confirms.
class CropToolScreen extends StatefulWidget {
  final String imagePath;

  const CropToolScreen({super.key, required this.imagePath});

  @override
  State<CropToolScreen> createState() => _CropToolScreenState();
}

class _CropToolScreenState extends State<CropToolScreen> {
  late Size _imageSize;
  Rect _cropRect = Rect.zero;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      setState(() {
        _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
        _cropRect = Rect.fromLTWH(0, 0, decoded.width.toDouble(), decoded.height.toDouble());
        _loaded = true;
      });
    }
  }

  Future<void> _applyCrop() async {
    if (_cropRect.width < 10 || _cropRect.height < 10) return;

    final bytes = await File(widget.imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;

    final x = _cropRect.left.round().clamp(0, decoded.width - 1);
    final y = _cropRect.top.round().clamp(0, decoded.height - 1);
    final w = _cropRect.width.round().clamp(1, decoded.width - x);
    final h = _cropRect.height.round().clamp(1, decoded.height - y);

    final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
    final jpeg = img.encodeJpg(cropped, quality: 92);

    final dir = Directory(widget.imagePath).parent;
    final name = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    await File(outPath).writeAsBytes(jpeg);

    if (mounted) Navigator.pop(context, outPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _loaded ? _applyCrop : null,
            icon: const Icon(Icons.check),
            label: const Text('Apply'),
          ),
        ],
      ),
      body: _loaded ? _buildCropper() : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildCropper() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;
        final imgRatio = _imageSize.width / _imageSize.height;
        final screenRatio = screenW / screenH;

        double displayW, displayH;
        if (imgRatio > screenRatio) {
          displayW = screenW;
          displayH = screenW / imgRatio;
        } else {
          displayH = screenH;
          displayW = screenH * imgRatio;
        }

        final offsetX = (screenW - displayW) / 2;
        final offsetY = (screenH - displayH) / 2;

        return Stack(
          children: [
            // Image
            Positioned(
              left: offsetX, top: offsetY,
              width: displayW, height: displayH,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
              ),
            ),
            // Dark overlay outside crop area
            Positioned.fill(
              child: CustomPaint(
                painter: _CropOverlayPainter(
                  cropRect: Rect.fromLTWH(
                    offsetX + _cropRect.left / _imageSize.width * displayW,
                    offsetY + _cropRect.top / _imageSize.height * displayH,
                    _cropRect.width / _imageSize.width * displayW,
                    _cropRect.height / _imageSize.height * displayH,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay outside crop
    final overlay = Paint()..color = Colors.black54;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(2))),
      ),
      overlay,
    );

    // Crop border
    final border = Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, border);

    // Corner handles
    final handle = Paint()..color = Colors.amberAccent..style = PaintingStyle.fill;
    const r = 8.0;
    canvas.drawCircle(Offset(cropRect.left, cropRect.top), r, handle);
    canvas.drawCircle(Offset(cropRect.right, cropRect.top), r, handle);
    canvas.drawCircle(Offset(cropRect.left, cropRect.bottom), r, handle);
    canvas.drawCircle(Offset(cropRect.right, cropRect.bottom), r, handle);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) => old.cropRect != cropRect;
}
