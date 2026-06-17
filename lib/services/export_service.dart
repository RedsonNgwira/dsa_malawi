import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Exports scanned pages as PDF or DOCX with proper A4 formatting.
class ExportService {
  /// Export pages as PDF with images scaled to fill A4 properly.
  Future<String> exportPdf(List<String> imagePaths, String name) async {
    final doc = pw.Document();

    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);

      // Decode image dimensions to compute proper scaling
      final decoded = await _decodeImageDimensions(bytes);
      final imgW = decoded.width;
      final imgH = decoded.height;

      // A4 dimensions in points (72 DPI): 595.28 x 841.89
      final a4 = PdfPageFormat.a4;
      final a4W = a4.width;
      final a4H = a4.height;
      final imgRatio = imgW / imgH;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (ctx) {
            // If image is landscape (wider than tall), rotate page to landscape
            if (imgRatio > 1.15) {
              // Rotate image 90 degrees for landscape images
              return pw.Transform.rotate(
                angle: 90 * math.pi / 180,
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.cover, width: a4H, height: a4W),
                ),
              );
            }
            return pw.Image(
              image,
              fit: pw.BoxFit.cover,
              width: a4W,
              height: a4H,
            );
          },
        ),
      );
    }

    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  /// Decode image dimensions without loading full image.
  Future<_ImgDims> _decodeImageDimensions(Uint8List bytes) async {
    // Parse JPEG/PNG headers for width/height
    // Simple approach: assume JPEG and extract from headers
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      // JPEG — scan for SOF marker
      int offset = 2;
      while (offset < bytes.length - 1) {
        if (bytes[offset] == 0xFF && bytes[offset + 1] == 0xC0) {
          // SOF0 marker found
          final h = (bytes[offset + 5] << 8) | bytes[offset + 6];
          final w = (bytes[offset + 7] << 8) | bytes[offset + 8];
          if (w > 0 && h > 0) return _ImgDims(w, h);
        }
        offset++;
      }
    }
    // Fallback: use image package
    // Since we can't import it here without conflicts, return A4-like dimensions
    return _ImgDims(2480, 3508); // Approx A4 at 300 DPI
  }

  Future<String> exportDocx(List<String> imagePaths, String name) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/$name.docx';
    final docx = await _buildDocx(imagePaths);
    final file = File(outPath);
    await file.writeAsBytes(docx);
    return file.path;
  }

  Future<Uint8List> _buildDocx(List<String> imagePaths) async {
    final archive = <String, Uint8List>{};

    // [Content_Types].xml
    archive['[Content_Types].xml'] = _utf8('''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''');

    // _rels/.rels
    archive['_rels/.rels'] = _utf8('''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''');

    // Embed images and build relationships + body
    final imgRels = <String>[];
    final bodyParts = <String>[];
    for (int i = 0; i < imagePaths.length; i++) {
      final imgId = 'img${i + 1}';
      final imgName = '$imgId.jpeg';
      archive['word/media/$imgName'] = await File(imagePaths[i]).readAsBytes();
      imgRels.add('<Relationship Id="$imgId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$imgName"/>');
      bodyParts.add('''<w:p>
  <w:r><w:drawing><wp:inline><wp:extent cx="12192000" cy="17272000"/>
  <wp:docPr id="${i + 1}" name="Image${i + 1}"/>
  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr><pic:cNvPr id="${i + 1}" name="$imgName"/><pic:cNvPicPr/></pic:nvPicPr>
        <pic:blipFill><a:blip r:embed="$imgId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="17272000"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
      </pic:pic>
    </a:graphicData>
  </a:graphic>
  </wp:inline></w:drawing></w:r></w:p>''');
      if (i < imagePaths.length - 1) {
        bodyParts.add('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
      }
    }

    archive['word/_rels/document.xml.rels'] = _utf8('''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  ${imgRels.join('\n  ')}
</Relationships>''');

    archive['word/document.xml'] = _utf8('''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
<w:body>
${bodyParts.join('\n')}
</w:body></w:document>''');

    return _zipArchive(archive);
  }

  Uint8List _utf8(String s) => Uint8List.fromList(s.codeUnits);

  Uint8List _zipArchive(Map<String, Uint8List> files) {
    final output = <int>[];
    final centralDir = <int>[];
    int offset = 0;

    for (final entry in files.entries) {
      final nameBytes = entry.key.codeUnits;
      final data = entry.value;
      final compressed = data;

      final localHeader = [
        0x50, 0x4B, 0x03, 0x04,
        0x14, 0x00,
        0x00, 0x00,
        0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        ..._uint32le(_crc32(data)),
        ..._uint32le(compressed.length),
        ..._uint32le(data.length),
        ..._uint16le(nameBytes.length),
        0x00, 0x00,
        ...nameBytes,
      ];

      final centralEntry = [
        0x50, 0x4B, 0x01, 0x02,
        0x14, 0x00,
        0x14, 0x00,
        0x00, 0x00,
        0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        ..._uint32le(_crc32(data)),
        ..._uint32le(compressed.length),
        ..._uint32le(data.length),
        ..._uint16le(nameBytes.length),
        0x00, 0x00,
        0x00, 0x00,
        0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        ..._uint32le(offset),
        ...nameBytes,
      ];

      output.addAll(localHeader);
      output.addAll(compressed);
      centralDir.addAll(centralEntry);
      offset += localHeader.length + compressed.length;
    }

    final cdSize = centralDir.length;
    final cdOffset = offset;
    final eocd = [
      0x50, 0x4B, 0x05, 0x06,
      0x00, 0x00, 0x00, 0x00,
      ..._uint16le(files.length),
      ..._uint16le(files.length),
      ..._uint32le(cdSize),
      ..._uint32le(cdOffset),
      0x00, 0x00,
    ];

    return Uint8List.fromList([...output, ...centralDir, ...eocd]);
  }

  List<int> _uint32le(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  List<int> _uint16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  int _crc32(Uint8List data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }
}

class _ImgDims {
  final int width, height;
  _ImgDims(this.width, this.height);
}
