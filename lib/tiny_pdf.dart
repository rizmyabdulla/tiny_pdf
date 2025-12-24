/// tinypdf — Minimal PDF creation library
/// <400 LOC, zero dependencies, makes real PDFs

import 'dart:typed_data';
import 'dart:convert';

// Helvetica widths, ASCII 32-126, units per 1000
const List<int> _widths = [
  278,
  278,
  355,
  556,
  556,
  889,
  667,
  191,
  333,
  333,
  389,
  584,
  278,
  333,
  278,
  278,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  556,
  278,
  278,
  584,
  584,
  584,
  556,
  1015,
  667,
  667,
  722,
  722,
  667,
  611,
  778,
  722,
  278,
  500,
  667,
  556,
  833,
  722,
  778,
  667,
  778,
  722,
  667,
  611,
  722,
  667,
  944,
  667,
  667,
  611,
  278,
  278,
  278,
  469,
  556,
  333,
  556,
  556,
  500,
  556,
  556,
  278,
  556,
  556,
  222,
  222,
  500,
  222,
  833,
  556,
  556,
  556,
  556,
  333,
  500,
  278,
  556,
  500,
  722,
  500,
  500,
  500,
  334,
  260,
  334,
  584,
];

/// Text alignment options
enum TextAlign { left, center, right }

/// Options for rendering text
/// Options for rendering text in [PageContext.text].
class TextOptions {
  final TextAlign align;
  final double? width;
  final String? color;

  /// Create text options.
  const TextOptions({this.align = TextAlign.left, this.width, this.color});
}

/// Context for drawing on a PDF page.
abstract class PageContext {
  /// Draw text at (x, y) with given font size and options.
  void text(String str, double x, double y, double size, [TextOptions? opts]);

  /// Draw a filled rectangle at (x, y) with width w and height h.
  void rect(double x, double y, double w, double h, String fill);

  /// Draw a line from (x1, y1) to (x2, y2) with color and optional width.
  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    String stroke, [
    double lineWidth = 1,
  ]);

  /// Draw a JPEG image at (x, y) with width w and height h.
  void image(Uint8List jpegBytes, double x, double y, double w, double h);
}

/// PDF object reference
class _Ref {
  final int id;
  _Ref(this.id);
}

/// Internal PDF object
class _PDFObject {
  final int id;
  final Map<String, dynamic> dict;
  final Uint8List? stream;

  _PDFObject(this.id, this.dict, this.stream);
}

/// Measure text width in points
/// [str] - Text to measure
/// [size] - Font size in points
/// Returns width in points
double measureText(String str, double size) {
  int width = 0;
  for (int i = 0; i < str.length; i++) {
    final code = str.codeUnitAt(i);
    final w = (code >= 32 && code <= 126) ? _widths[code - 32] : 556;
    width += w;
  }
  return (width * size) / 1000;
}

/// Parse hex color to RGB floats
/// [hex] - Hex color string (#rgb or #rrggbb)
/// Returns RGB values 0-1 or null
List<double>? _parseColor(String? hex) {
  if (hex == null || hex == 'none') return null;
  hex = hex.replaceFirst('#', '');
  if (hex.length == 3) {
    hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
  }
  final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
  final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
  final b = int.parse(hex.substring(4, 6), radix: 16) / 255;
  return [r, g, b];
}

/// Escape string for PDF
String _pdfString(String str) {
  return '(${str.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)').replaceAll('\r', '\\r').replaceAll('\n', '\\n')})';
}

/// Serialize value to PDF format
String _serialize(dynamic val) {
  if (val == null) return 'null';
  if (val is bool) return val ? 'true' : 'false';
  if (val is int) return val.toString();
  if (val is double) {
    if (val == val.truncateToDouble()) {
      return val.truncate().toString();
    }
    String s = val.toStringAsFixed(4);
    // Remove trailing zeros
    while (s.endsWith('0') && s.contains('.')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
  if (val is String) {
    if (val.startsWith('/')) return val; // name
    if (val.startsWith('(')) return val; // already escaped string
    return _pdfString(val);
  }
  if (val is List) {
    return '[${val.map(_serialize).join(' ')}]';
  }
  if (val is _Ref) {
    return '${val.id} 0 R';
  }
  if (val is Map) {
    final pairs = val.entries
        .where((e) => e.value != null)
        .map((e) => '/${e.key} ${_serialize(e.value)}');
    return '<<\n${pairs.join('\n')}\n>>';
  }
  return val.toString();
}

/// PDF Builder interface
/// PDF document builder. Use [pdf] to create an instance.
class PDFBuilder {
  final List<_PDFObject> _objects = [];
  final List<_Ref> _pages = [];
  int _nextId = 1;

  _Ref _addObject(Map<String, dynamic> dict, [Uint8List? streamBytes]) {
    final id = _nextId++;
    _objects.add(_PDFObject(id, dict, streamBytes));
    return _Ref(id);
  }

  /// Add a page with custom dimensions
  void page(double width, double height, void Function(PageContext ctx) fn) {
    final ops = <String>[];
    final images = <({String name, _Ref ref})>[];
    int imageCount = 0;

    final ctx = _PageContextImpl(
      ops: ops,
      images: images,
      imageCount: () => imageCount,
      incrementImageCount: () => imageCount++,
      addObject: _addObject,
    );

    fn(ctx);

    final content = ops.join('\n');
    final contentBytes = Uint8List.fromList(utf8.encode(content));
    final contentRef = _addObject({
      'Length': contentBytes.length,
    }, contentBytes);

    final xobjects = <String, _Ref>{};
    for (final img in images) {
      xobjects[img.name.substring(1)] = img.ref;
    }

    final pageRef = _addObject({
      'Type': '/Page',
      'Parent': null,
      'MediaBox': [0, 0, width, height],
      'Contents': contentRef,
      'Resources': <String, dynamic>{
        'Font': <String, dynamic>{'F1': null},
        'XObject': xobjects.isNotEmpty ? xobjects : null,
      },
    });

    _pages.add(pageRef);
  }

  /// Add a page with default US Letter dimensions (612x792)
  void pageDefault(void Function(PageContext ctx) fn) {
    page(612, 792, fn);
  }

  /// Build the PDF and return as bytes
  Uint8List build() {
    final fontRef = _addObject({
      'Type': '/Font',
      'Subtype': '/Type1',
      'BaseFont': '/Helvetica',
    });

    final pagesRef = _addObject({
      'Type': '/Pages',
      'Kids': _pages,
      'Count': _pages.length,
    });

    for (final obj in _objects) {
      if (obj.dict['Type'] == '/Page') {
        obj.dict['Parent'] = pagesRef;
        final resources = obj.dict['Resources'] as Map<String, dynamic>?;
        if (resources != null && resources['Font'] != null) {
          (resources['Font'] as Map<String, dynamic>)['F1'] = fontRef;
        }
      }
    }

    final catalogRef = _addObject({'Type': '/Catalog', 'Pages': pagesRef});

    final parts = <dynamic>[];
    final offsets = <int, int>{};

    parts.add('%PDF-1.4\n%\xFF\xFF\xFF\xFF\n');

    for (final obj in _objects) {
      offsets[obj.id] = _calculateLength(parts);

      String content = '${obj.id} 0 obj\n${_serialize(obj.dict)}\n';
      if (obj.stream != null) {
        content += 'stream\n';
        parts.add(content);
        parts.add(obj.stream!);
        parts.add('\nendstream\nendobj\n');
      } else {
        content += 'endobj\n';
        parts.add(content);
      }
    }

    final xrefOffset = _calculateLength(parts);

    String xref = 'xref\n0 ${_objects.length + 1}\n';
    xref += '0000000000 65535 f \n';
    for (int i = 1; i <= _objects.length; i++) {
      xref += '${offsets[i].toString().padLeft(10, '0')} 00000 n \n';
    }
    parts.add(xref);

    parts.add(
      'trailer\n${_serialize({
            'Size': _objects.length + 1,
            'Root': catalogRef
          })}\n',
    );
    parts.add('startxref\n$xrefOffset\n%%EOF\n');

    final totalLength = _calculateLength(parts);
    final result = Uint8List(totalLength);
    int offset = 0;
    for (final part in parts) {
      final bytes = part is String
          ? Uint8List.fromList(utf8.encode(part))
          : part as Uint8List;
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }

    return result;
  }

  int _calculateLength(List<dynamic> parts) {
    int sum = 0;
    for (final p in parts) {
      if (p is String) {
        sum += utf8.encode(p).length;
      } else if (p is Uint8List) {
        sum += p.length;
      }
    }
    return sum;
  }
}

class _PageContextImpl implements PageContext {
  final List<String> ops;
  final List<({String name, _Ref ref})> images;
  final int Function() imageCount;
  final void Function() incrementImageCount;
  final _Ref Function(Map<String, dynamic>, [Uint8List?]) addObject;

  _PageContextImpl({
    required this.ops,
    required this.images,
    required this.imageCount,
    required this.incrementImageCount,
    required this.addObject,
  });

  @override
  void text(String str, double x, double y, double size, [TextOptions? opts]) {
    opts ??= const TextOptions();
    final align = opts.align;
    final boxWidth = opts.width;
    final color = opts.color ?? '#000000';

    double tx = x;
    if (align != TextAlign.left && boxWidth != null) {
      final textWidth = measureText(str, size);
      if (align == TextAlign.center) tx = x + (boxWidth - textWidth) / 2;
      if (align == TextAlign.right) tx = x + boxWidth - textWidth;
    }

    final rgb = _parseColor(color);
    if (rgb != null) {
      ops.add(
        '${rgb[0].toStringAsFixed(3)} ${rgb[1].toStringAsFixed(3)} ${rgb[2].toStringAsFixed(3)} rg',
      );
    }
    ops.add('BT');
    ops.add('/F1 $size Tf');
    ops.add('${tx.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td');
    ops.add('${_pdfString(str)} Tj');
    ops.add('ET');
  }

  @override
  void rect(double x, double y, double w, double h, String fill) {
    final rgb = _parseColor(fill);
    if (rgb != null) {
      ops.add(
        '${rgb[0].toStringAsFixed(3)} ${rgb[1].toStringAsFixed(3)} ${rgb[2].toStringAsFixed(3)} rg',
      );
      ops.add(
        '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re',
      );
      ops.add('f');
    }
  }

  @override
  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    String stroke, [
    double lineWidth = 1,
  ]) {
    final rgb = _parseColor(stroke);
    if (rgb != null) {
      ops.add('${lineWidth.toStringAsFixed(2)} w');
      ops.add(
        '${rgb[0].toStringAsFixed(3)} ${rgb[1].toStringAsFixed(3)} ${rgb[2].toStringAsFixed(3)} RG',
      );
      ops.add('${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} m');
      ops.add('${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)} l');
      ops.add('S');
    }
  }

  @override
  void image(Uint8List jpegBytes, double x, double y, double w, double h) {
    int imgWidth = 0, imgHeight = 0;
    for (int i = 0; i < jpegBytes.length - 1; i++) {
      if (jpegBytes[i] == 0xFF &&
          (jpegBytes[i + 1] == 0xC0 || jpegBytes[i + 1] == 0xC2)) {
        imgHeight = (jpegBytes[i + 5] << 8) | jpegBytes[i + 6];
        imgWidth = (jpegBytes[i + 7] << 8) | jpegBytes[i + 8];
        break;
      }
    }

    final imgName = '/Im${imageCount()}';
    incrementImageCount();

    final imgRef = addObject({
      'Type': '/XObject',
      'Subtype': '/Image',
      'Width': imgWidth,
      'Height': imgHeight,
      'ColorSpace': '/DeviceRGB',
      'BitsPerComponent': 8,
      'Filter': '/DCTDecode',
      'Length': jpegBytes.length,
    }, jpegBytes);

    images.add((name: imgName, ref: imgRef));

    ops.add('q');
    ops.add(
      '${w.toStringAsFixed(2)} 0 0 ${h.toStringAsFixed(2)} ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} cm',
    );
    ops.add('$imgName Do');
    ops.add('Q');
  }
}

/// Create a new PDF document
/// Create a new PDF document builder.
PDFBuilder pdf() {
  return PDFBuilder();
}

/// Convert markdown to PDF
/// Supports: # headers, - lists, 1. numbered lists, --- rules, paragraphs with word wrap
Uint8List markdown(String md, {double? width, double? height, double? margin}) {
  final W = width ?? 612;
  final H = height ?? 792;
  final M = margin ?? 72;
  final doc = pdf();
  final textW = W - M * 2;
  const bodySize = 11.0;

  final items = <_Item>[];

  List<String> wrap(String text, double size, double maxW) {
    final words = text.split(' ');
    final lines = <String>[];
    String line = '';
    for (final word in words) {
      final test = line.isNotEmpty ? '$line $word' : word;
      if (measureText(test, size) <= maxW) {
        line = test;
      } else {
        if (line.isNotEmpty) lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines.isNotEmpty ? lines : [''];
  }

  String prevType = 'start';
  for (final raw in md.split('\n')) {
    final line = raw.trimRight();
    if (RegExp(r'^#{1,3}\s').hasMatch(line)) {
      final lvl = RegExp(r'^#+').firstMatch(line)![0]!.length;
      final size = [22.0, 16.0, 13.0][lvl - 1];
      final before = prevType == 'start' ? 0.0 : [14.0, 12.0, 10.0][lvl - 1];
      final wrapped = wrap(line.substring(lvl + 1), size, textW);
      for (int i = 0; i < wrapped.length; i++) {
        items.add(
          _Item(
            text: wrapped[i],
            size: size,
            indent: 0,
            spaceBefore: i == 0 ? before : 0,
            spaceAfter: 4,
            color: '#111111',
          ),
        );
      }
      prevType = 'header';
    } else if (RegExp(r'^[-*]\s').hasMatch(line)) {
      final wrapped = wrap(line.substring(2), bodySize, textW - 18);
      for (int i = 0; i < wrapped.length; i++) {
        items.add(
          _Item(
            text: (i == 0 ? '- ' : '  ') + wrapped[i],
            size: bodySize,
            indent: 12,
            spaceBefore: 0,
            spaceAfter: 2,
          ),
        );
      }
      prevType = 'list';
    } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
      final num = RegExp(r'^\d+').firstMatch(line)![0]!;
      final text = line.substring(num.length + 2);
      final wrapped = wrap(text, bodySize, textW - 18);
      for (int i = 0; i < wrapped.length; i++) {
        items.add(
          _Item(
            text: (i == 0 ? '$num. ' : '   ') + wrapped[i],
            size: bodySize,
            indent: 12,
            spaceBefore: 0,
            spaceAfter: 2,
          ),
        );
      }
      prevType = 'list';
    } else if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line)) {
      items.add(
        _Item(
          text: '',
          size: bodySize,
          indent: 0,
          spaceBefore: 8,
          spaceAfter: 8,
          rule: true,
        ),
      );
      prevType = 'rule';
    } else if (line.trim().isEmpty) {
      if (prevType != 'start' && prevType != 'blank') {
        items.add(
          _Item(
            text: '',
            size: bodySize,
            indent: 0,
            spaceBefore: 0,
            spaceAfter: 4,
          ),
        );
      }
      prevType = 'blank';
    } else {
      final wrapped = wrap(line, bodySize, textW);
      for (int i = 0; i < wrapped.length; i++) {
        items.add(
          _Item(
            text: wrapped[i],
            size: bodySize,
            indent: 0,
            spaceBefore: 0,
            spaceAfter: 4,
            color: '#111111',
          ),
        );
      }
      prevType = 'para';
    }
  }

  final pages = <({List<_Item> items, List<double> ys})>[];
  double y = H - M;
  var pg = <_Item>[];
  var ys = <double>[];

  for (final item in items) {
    final needed = item.spaceBefore + item.size + item.spaceAfter;
    if (y - needed < M) {
      pages.add((items: pg, ys: ys));
      pg = [];
      ys = [];
      y = H - M;
    }
    y -= item.spaceBefore;
    ys.add(y);
    pg.add(item);
    y -= item.size + item.spaceAfter;
  }
  if (pg.isNotEmpty) pages.add((items: pg, ys: ys));

  for (final pageData in pages) {
    doc.page(W, H, (ctx) {
      for (int i = 0; i < pageData.items.length; i++) {
        final it = pageData.items[i];
        final py = pageData.ys[i];
        if (it.rule) {
          ctx.line(M, py, W - M, py, '#e0e0e0', 0.5);
        } else if (it.text.isNotEmpty) {
          ctx.text(
            it.text,
            M + it.indent,
            py,
            it.size,
            TextOptions(color: it.color),
          );
        }
      }
    });
  }

  return doc.build();
}

class _Item {
  final String text;
  final double size;
  final double indent;
  final double spaceBefore;
  final double spaceAfter;
  final bool rule;
  final String? color;

  _Item({
    required this.text,
    required this.size,
    required this.indent,
    required this.spaceBefore,
    required this.spaceAfter,
    this.rule = false,
    this.color,
  });
}
