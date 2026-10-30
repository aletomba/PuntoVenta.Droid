import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/features/sales/cart_provider.dart';
import 'package:punto_venta/features/sales/ticket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'ticket-service-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          expect(call.method, 'getTemporaryDirectory');
          return temporaryDirectory.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await temporaryDirectory.delete(recursive: true);
  });

  test('generates a PDF ticket with the sale ID in its filename', () async {
    const cart = CartState(
      items: [
        CartItem(
          id: 'line-1',
          description: 'Yerba',
          unitPriceCents: 1250,
          quantity: 2,
        ),
      ],
    );

    final file = await TicketService().generatePdf(
      saleId: 'sale-123',
      cart: cart,
      paymentMethod: 'cash',
      date: DateTime.utc(2026, 10, 29),
    );

    expect(file.path, endsWith('ticket_sale-123.pdf'));
    expect(await file.exists(), isTrue);
    final bytes = await file.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
