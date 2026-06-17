import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/scanner_controller.dart';
import 'corner_painter.dart';

/// Full-screen camera view with corner guides, live border overlay,
/// and capture button.
class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ScannerController>();
    final caption = ctrl.pages.isEmpty ? 'Page 1' : 'Page ${ctrl.pages.length + 1}';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(caption, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => ctrl.closeCamera(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () {
              // CameraController may not have switchCamera in all versions
              // User can manually change camera in system settings
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ctrl.cameraReady && ctrl.camera != null)
            CameraPreview(ctrl.camera!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // Corner guides
          Positioned.fill(child: CustomPaint(painter: const CornerPainter())),
          // Live document border
          if (ctrl.detectedCorners != null)
            Positioned.fill(
              child: CustomPaint(painter: DocumentBorderPainter(corners: ctrl.detectedCorners!)),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Auto-capture progress indicator
            if (ctrl.stableFrames > 0 && !ctrl.autoCaptureReady)
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: SizedBox(
                  width: 48, height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: ctrl.stableFrames / ctrl.autoCaptureThreshold,
                        strokeWidth: 3,
                        color: Colors.amberAccent,
                        backgroundColor: Colors.white24,
                      ),
                      Text(
                        '${ctrl.stableFrames}',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            // Capture button
            GestureDetector(
              onTap: () => ctrl.capture(),
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ctrl.autoCaptureReady ? Colors.amberAccent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
