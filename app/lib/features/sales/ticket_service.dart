import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/money.dart';
import 'cart_provider.dart';

class TicketException implements Exception {
  const TicketException(this.message, this.cause);

  final String message;
  final Object cause;
}

class TicketService {
  Future<File> generatePdf({
    required String saleId,
    required CartState cart,
    required String paymentMethod,
    DateTime? date,
  }) async {
    try {
      final pdf = pw.Document();
      final now = date ?? DateTime.now().toUtc();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PUNTO DE VENTA',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Fecha: ${now.toLocal().toString().substring(0, 16)}'),
              pw.Text('Venta: $saleId'),
              pw.Text('Pago: ${_paymentLabel(paymentMethod)}'),
              pw.Divider(),
              ...cart.items.map(
                (item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.description),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${item.quantity} x \$ '
                          '${formatMoneyCents(item.unitPriceCents)}',
                        ),
                        pw.Text('\$ ${formatMoneyCents(item.subtotalCents)}'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '\$ ${formatMoneyCents(cart.totalCents)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('Gracias por su compra')),
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ticket_$saleId.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } on Exception catch (error, stackTrace) {
      Error.throwWithStackTrace(
        TicketException('No se pudo generar el PDF del ticket.', error),
        stackTrace,
      );
    }
  }

  Future<void> shareTicket(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Ticket de venta'),
      );
    } on Exception catch (error, stackTrace) {
      Error.throwWithStackTrace(
        TicketException('No se pudo compartir el ticket.', error),
        stackTrace,
      );
    }
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'debit':
        return 'Débito';
      case 'credit':
        return 'Crédito';
      case 'transfer':
        return 'Transferencia';
      case 'other':
        return 'Otro';
      case 'cash':
      default:
        return 'Efectivo';
    }
  }
}
