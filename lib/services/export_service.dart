import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;


class ExportService {
  Future<String> exportPdf(List<String> imagePaths, String name) async {
    final doc = pw.Document();

    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(image, fit: pw.BoxFit.contain),
        ),
      );
    }

    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  Future<String> exportDocx(List<String> imagePaths, String name) async {
    // Build a simple docx with each image on its own paragraph
    // docx_template uses a template approach; we build from scratch via raw XML
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/$name.docx';

    // Use pdf-generated file as base, then create docx with image references
    // Simplest approach: generate a docx XML manually
    final docx = await _buildDocx(imagePaths);
    final file = File(outPath);
    await file.writeAsBytes(docx);
    return file.path;
  }

  Future<Uint8List> _buildDocx(List<String> imagePaths) async {
    // We'll use docx_template with a minimal inline template
    // For each image, embed as base64 in the word document
    // Since docx_template needs a template file, we use the pdf package
    // to render images and save as DOCX-compatible format.
    // Practical approach: save images into a zip-based .docx structure.
    
    // Build minimal Office Open XML .docx in memory
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
      // 6096000 EMUs = ~16.9cm (A4 width minus margins)
      bodyParts.add('''<w:p>
  <w:r><w:drawing><wp:inline><wp:extent cx="6096000" cy="8636000"/>
  <wp:docPr id="${i + 1}" name="Image${i + 1}"/>
  <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
      <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr><pic:cNvPr id="${i + 1}" name="$imgName"/><pic:cNvPicPr/></pic:nvPicPr>
        <pic:blipFill><a:blip r:embed="$imgId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
        <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="6096000" cy="8636000"/></a:xfrm>
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
    // Simple zip builder (stored, no compression for images)
    final output = <int>[];
    final centralDir = <int>[];
    int offset = 0;

    for (final entry in files.entries) {
      final nameBytes = entry.key.codeUnits;
      final data = entry.value;
      final isText = !entry.key.contains('media/');
      final compressed = isText ? _deflateStored(data) : data;

      final localHeader = [
        0x50, 0x4B, 0x03, 0x04, // signature
        0x14, 0x00, // version 2.0
        0x00, 0x00, // flags
        0x00, 0x00, // compression: stored
        0x00, 0x00, 0x00, 0x00, // mod time/date
        ..._uint32le(_crc32(data)),
        ..._uint32le(compressed.length),
        ..._uint32le(data.length),
        ..._uint16le(nameBytes.length),
        0x00, 0x00, // extra length
        ...nameBytes,
      ];

      final centralEntry = [
        0x50, 0x4B, 0x01, 0x02, // signature
        0x14, 0x00, // version made
        0x14, 0x00, // version needed
        0x00, 0x00, // flags
        0x00, 0x00, // compression
        0x00, 0x00, 0x00, 0x00, // mod time/date
        ..._uint32le(_crc32(data)),
        ..._uint32le(compressed.length),
        ..._uint32le(data.length),
        ..._uint16le(nameBytes.length),
        0x00, 0x00, // extra
        0x00, 0x00, // comment
        0x00, 0x00, // disk start
        0x00, 0x00, // internal attr
        0x00, 0x00, 0x00, 0x00, // external attr
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

  Uint8List _deflateStored(Uint8List data) => data;

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
