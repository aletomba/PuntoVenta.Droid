import 'package:mobile_scanner/mobile_scanner.dart';

/// Formatos de código de barras que el MVP acepta (ver `docs/plan.md`, sección 2).
///
/// Se restringen de forma explícita para reducir falsos positivos y mejorar el
/// rendimiento del detector en dispositivos de gama baja.
const List<BarcodeFormat> supportedBarcodeFormats = <BarcodeFormat>[
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.qrCode,
];

/// Quita espacios y normaliza el código leído o ingresado a mano.
///
/// Devuelve `null` cuando el código queda vacío, para que la UI pueda pedir
/// otro intento en lugar de guardar un producto sin código.
String? normalizeScannedCode(String? raw) {
  final normalized = raw?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
