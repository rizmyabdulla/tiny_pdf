import 'dart:io';
import 'package:tiny_pdf/tiny_pdf.dart';

void main() {
  final doc = pdf();
  final margin = 40.0;
  final pw = 612.0 - margin * 2; // 532

  doc.page(612, 792, (p) {
    // Header
    p.rect(margin, 716, pw, 36, '#2563eb');
    p.text('INVOICE', margin + 15, 726, 24, TextOptions(color: '#ffffff'));
    p.text(
      '#INV-2025-001',
      margin + pw - 100,
      728,
      12,
      TextOptions(color: '#ffffff'),
    );

    // Company info
    p.text('Acme Corporation', margin, 670, 16, TextOptions(color: '#000000'));
    p.text(
      '123 Business Street',
      margin,
      652,
      11,
      TextOptions(color: '#666666'),
    );
    p.text(
      'New York, NY 10001',
      margin,
      638,
      11,
      TextOptions(color: '#666666'),
    );

    // Bill to
    p.text('Bill To:', margin + 300, 670, 12, TextOptions(color: '#666666'));
    p.text('John Smith', margin + 300, 652, 14, TextOptions(color: '#000000'));
    p.text(
      '456 Customer Ave',
      margin + 300,
      636,
      11,
      TextOptions(color: '#666666'),
    );
    p.text(
      'Los Angeles, CA 90001',
      margin + 300,
      622,
      11,
      TextOptions(color: '#666666'),
    );

    // Table header
    p.rect(margin, 560, pw, 25, '#f3f4f6');
    p.text('Description', margin + 10, 568, 11, TextOptions(color: '#000000'));
    p.text('Qty', margin + 270, 568, 11, TextOptions(color: '#000000'));
    p.text('Price', margin + 340, 568, 11, TextOptions(color: '#000000'));
    p.text('Total', margin + 440, 568, 11, TextOptions(color: '#000000'));

    // Table rows
    final items = [
      ['Website Development', '1', '\$5,000.00', '\$5,000.00'],
      ['Hosting (Annual)', '1', '\$200.00', '\$200.00'],
      ['Maintenance Package', '12', '\$150.00', '\$1,800.00'],
    ];

    double y = 535.0;
    for (final row in items) {
      final desc = row[0];
      final qty = row[1];
      final price = row[2];
      final total = row[3];

      p.text(desc, margin + 10, y, 11);
      p.text(qty, margin + 270, y, 11);
      p.text(price, margin + 340, y, 11);
      p.text(total, margin + 440, y, 11);
      p.line(margin, y - 15, margin + pw, y - 15, '#e5e7eb', 0.5);
      y -= 30;
    }

    // Total section
    p.line(margin, y, margin + pw, y, '#000000', 1);
    p.text('Subtotal:', margin + 340, y - 25, 11);
    p.text('\$7,000.00', margin + 440, y - 25, 11);
    p.text('Tax (8%):', margin + 340, y - 45, 11);
    p.text('\$560.00', margin + 440, y - 45, 11);
    p.rect(margin + 330, y - 75, 202, 25, '#2563eb');
    p.text(
      'Total Due:',
      margin + 340,
      y - 63,
      12,
      TextOptions(color: '#ffffff'),
    );
    p.text(
      '\$7,560.00',
      margin + 440,
      y - 63,
      12,
      TextOptions(color: '#ffffff'),
    );

    // Footer
    p.text(
      'Thank you for your business!',
      margin,
      80,
      12,
      TextOptions(align: TextAlign.center, width: pw, color: '#666666'),
    );
    p.text(
      'Payment due within 30 days',
      margin,
      62,
      10,
      TextOptions(align: TextAlign.center, width: pw, color: '#999999'),
    );
  });

  final bytes = doc.build();

  final dir = Directory('examples');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final out = File('examples/invoice.pdf');
  out.writeAsBytesSync(bytes);
  print('Created examples/invoice.pdf');
  print('File size: ${bytes.length} bytes');

  // Test measureText
  print('\nmeasureText test:');
  print('"Hello" at 12pt = ${measureText('Hello', 12).toStringAsFixed(2)}pt');
  print(
    '"Hello World" at 24pt = ${measureText('Hello World', 24).toStringAsFixed(2)}pt',
  );
}
