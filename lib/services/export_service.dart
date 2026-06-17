import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  Future<String> exportPdf(List<String> imagePaths, String name) async {
    final doc = pw.Document();
    for (final path in imagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      final d = _dims(bytes);
      final a4 = PdfPageFormat.a4;
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(0), build: (_) {
        if (d.width / d.height > 1.15) {
          return pw.Transform.rotate(angle: 90 * math.pi / 180,
            child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.cover, width: a4.height, height: a4.width)));
        }
        return pw.Image(image, fit: pw.BoxFit.cover, width: a4.width, height: a4.height);
      }));
    }
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.pdf');
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  _ImgDims _dims(Uint8List bytes) {
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      for (int i = 2; i < bytes.length - 1; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xC0 && i + 8 < bytes.length) {
          return _ImgDims((bytes[i + 7] << 8) | bytes[i + 8], (bytes[i + 5] << 8) | bytes[i + 6]);
        }
      }
    }
    return _ImgDims(2480, 3508);
  }

  Future<String> exportDocx(List<String> imagePaths, String name) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/$name.docx';
    final archive = <String, Uint8List>{};
    archive['[Content_Types].xml'] = _u('<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="jpeg" ContentType="image/jpeg"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
    archive['_rels/.rels'] = _u('<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');

    final imgRels = <String>[]; final bodyParts = <String>[];
    for (int i = 0; i < imagePaths.length; i++) {
      final id = 'img${i+1}';
      archive['word/media/$id.jpeg'] = await File(imagePaths[i]).readAsBytes();
      imgRels.add('<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$id.jpeg"/>');
      bodyParts.add('<w:p><w:r><w:drawing><wp:inline><wp:extent cx="12192000" cy="17272000"/><wp:docPr id="${i+1}" name="Image${i+1}"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="${i+1}" name="$id.jpeg"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="$id"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="12192000" cy="17272000"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>');
      if (i < imagePaths.length - 1) bodyParts.add('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    }
    archive['word/_rels/document.xml.rels'] = _u('<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${imgRels.join('')}</Relationships>');
    archive['word/document.xml'] = _u('<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"><w:body>${bodyParts.join('')}</w:body></w:document>');
    final file = File(outPath); await file.writeAsBytes(_zip(archive)); return file.path;
  }

  Uint8List _u(String s) => Uint8List.fromList(s.codeUnits);

  Uint8List _zip(Map<String, Uint8List> files) {
    final out = <int>[], dir = <int>[]; int offset = 0;
    for (final e in files.entries) {
      final nb = e.key.codeUnits, d = e.value;
      final h = [0x50, 0x4B, 0x03, 0x04, 0x14, 0, 0, 0, 0, 0, ..._crc32le(d), ..._i32le(d.length), ..._i32le(d.length), ..._i16le(nb.length), 0, 0, ...nb];
      dir.addAll([0x50, 0x4B, 0x01, 0x02, 0x14, 0, 0x14, 0, 0, 0, 0, 0, 0, 0, ..._crc32le(d), ..._i32le(d.length), ..._i32le(d.length), ..._i16le(nb.length), 0, 0, 0, 0, 0, 0, ..._i32le(offset), ...nb]);
      out.addAll(h); out.addAll(d); offset += h.length + d.length;
    }
    return Uint8List.fromList([...out, ...dir, 0x50, 0x4B, 0x05, 0x06, 0, 0, 0, 0, ..._i16le(files.length), ..._i16le(files.length), ..._i32le(dir.length), ..._i32le(offset), 0, 0]);
  }

  List<int> _i32le(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  List<int> _i16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  List<int> _crc32le(Uint8List data) {
    var c = 0xFFFFFFFF;
    for (final b in data) { c ^= b; for (var i = 0; i < 8; i++) c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1; }
    return _i32le((~c) & 0xFFFFFFFF);
  }
}

class _ImgDims {
  final int width, height;
  _ImgDims(this.width, this.height);
}
