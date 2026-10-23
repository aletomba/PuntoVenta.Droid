import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:punto_venta/features/scanner/scanner_formats.dart';

void main() {
  group('supportedBarcodeFormats', () {
    test('incluye solo los formatos del MVP', () {
      expect(
        supportedBarcodeFormats,
        containsAll(<BarcodeFormat>[
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.qrCode,
        ]),
      );
      expect(supportedBarcodeFormats, hasLength(6));
      expect(supportedBarcodeFormats, isNot(contains(BarcodeFormat.all)));
    });
  });

  group('normalizeScannedCode', () {
    test('recorta espacios alrededor del código', () {
      expect(normalizeScannedCode('  7791234567890 '), '7791234567890');
    });

    test('devuelve null para códigos vacíos o nulos', () {
      expect(normalizeScannedCode(null), isNull);
      expect(normalizeScannedCode(''), isNull);
      expect(normalizeScannedCode('   '), isNull);
    });
  });
}
