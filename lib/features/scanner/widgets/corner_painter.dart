import 'package:flutter/material.dart';

/// Paints corner brackets on the camera preview to guide document framing.
class CornerPainter extends CustomPainter {
  final Color color;
  const CornerPainter({this.color = Colors.white38});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
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

/// Paints the live document border detected by edge detection.
class DocumentBorderPainter extends CustomPainter {
  final List<Offset> corners;
  final Color color;
  const DocumentBorderPainter({required this.corners, this.color = Colors.amberAccent});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DocumentBorderPainter old) => old.corners != corners;
}
