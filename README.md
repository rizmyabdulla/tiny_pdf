# tiny_pdf

Tiny, zero-dependency PDF builder for Dart. Write PDF primitives (text, rects, lines, JPEG images) and render markdown into real PDFs.

[Click here](https://dev.to/rizmyabdulla/tinypdf-a-tiny-pdf-library-in-dart-600-loc-zero-deps-real-pdfs-1do9) to read the dev.to post.

## Install

```bash
dart pub add tiny_pdf
```

## Quick start

```dart
import 'dart:io';
import 'package:tiny_pdf/tiny_pdf.dart';

void main() {
	final doc = pdf();

	doc.page((p) {
		p.text('Hello PDF', 72, 700, 24);
		p.rect(72, 660, 200, 40, '#2563eb');
		p.line(72, 640, 272, 640, '#111111', 1);
	});

	final bytes = doc.build();
	File('hello.pdf').writeAsBytesSync(bytes);
}
```

## Markdown to PDF

```dart
import 'dart:io';
import 'package:tiny_pdf/tiny_pdf.dart';

void main() {
	final bytes = markdown('# Title\n\n- Bullet one\n- Bullet two');
	File('markdown.pdf').writeAsBytesSync(bytes);
}
```

## Invoice example

See `examples/invoice_example.dart` for a complete invoice layout; running it writes `examples/invoice.pdf`.


## API

```dart
// Create a new PDF document
PDFBuilder doc = pdf();

// Add a page (default 612x792)
doc.page((PageContext p) {
	p.text(String text, double x, double y, double size, [TextOptions? opts]);
	p.rect(double x, double y, double w, double h, String fillColor);
	p.line(double x1, double y1, double x2, double y2, String strokeColor, [double lineWidth = 1]);
	p.image(Uint8List jpegBytes, double x, double y, double w, double h);
});

// Add a page with custom size
doc.page(double width, double height, (PageContext p) { ... });

// Build the PDF and get bytes
Uint8List bytes = doc.build();

// Measure text width in points
double w = measureText('Hello', 12);

// Render markdown to PDF
Uint8List pdfBytes = markdown('# Title', width: 612, height: 792, margin: 72);

// TextOptions
TextOptions(
	align: TextAlign.left|center|right,
	width: double?,
	color: String? // hex color, e.g. '#2563eb'
);
```

## License

MIT License. See `LICENSE` file for details.
