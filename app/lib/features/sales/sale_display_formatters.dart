import 'package:flutter/material.dart';

String formatSaleDateTime(BuildContext context, DateTime date) {
  final localDate = date.toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortDate(localDate)} · '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localDate))}';
}

String formatUtcDay(BuildContext context, DateTime day) {
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(DateTime(day.year, day.month, day.day));
}

String paymentMethodLabel(String method) => switch (method) {
  'cash' => 'Efectivo',
  'debit' => 'Débito',
  'credit' => 'Crédito',
  'transfer' => 'Transferencia',
  'other' => 'Otro',
  _ => method,
};
