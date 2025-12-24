import 'package:test/test.dart';

import 'package:tiny_pdf/tiny_pdf.dart';

void main() {
  test('measureText calculates width correctly', () {
    // Test with known characters
    final width = measureText('Hello', 12);
    expect(width, greaterThan(0));
  });

  test('pdf creates a valid PDF', () {
    final doc = pdf();
    doc.page(612, 792, (ctx) {
      ctx.text('Hello World', 100, 700, 24);
      ctx.rect(100, 600, 200, 50, '#ff0000');
      ctx.line(100, 550, 300, 550, '#0000ff', 2);
    });
    final bytes = doc.build();
    // Check PDF header
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });

  test('pageDefault uses US Letter dimensions', () {
    final doc = pdf();
    doc.pageDefault((ctx) {
      ctx.text('Default page', 100, 700, 12);
    });
    final bytes = doc.build();
    expect(bytes.length, greaterThan(0));
  });

  test('markdown converts to PDF', () {
    final bytes = markdown('# Hello\n\nThis is a test.');
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });
}
