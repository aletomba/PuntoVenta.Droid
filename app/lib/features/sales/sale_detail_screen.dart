import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/sales/sales_repository.dart';
import 'sale_display_formatters.dart';

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({required this.saleId, super.key});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(saleDetailsProvider(saleId));
    final session = ref.watch(authSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de venta')),
      body: details.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar la venta: $error'),
          ),
        ),
        data: (saleDetails) {
          if (saleDetails == null) {
            return const Center(child: Text('La venta no existe.'));
          }

          final sale = saleDetails.sale;
          final isVoided = sale.status == 'voided';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Venta ${sale.id}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(formatSaleDateTime(context, sale.date)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estado'),
                trailing: Text(isVoided ? 'Anulada' : 'Activa'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Medio de pago'),
                trailing: Text(paymentMethodLabel(sale.paymentMethod)),
              ),
              const Divider(),
              ...saleDetails.items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.description),
                  subtitle: Text(
                    '${item.quantity} × '
                    '\$ ${formatMoneyCents(item.unitPriceCents)}',
                  ),
                  trailing: Text(
                    '\$ ${formatMoneyCents(item.quantity * item.unitPriceCents)}',
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total'),
                titleTextStyle: Theme.of(context).textTheme.titleLarge,
                trailing: Text(
                  '\$ ${formatMoneyCents(sale.totalCents)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (isVoided && sale.voidReason != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Motivo de anulación'),
                  subtitle: Text(sale.voidReason!),
                ),
              if (isVoided && sale.voidedAt != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anulada el'),
                  subtitle: Text(formatSaleDateTime(context, sale.voidedAt!)),
                ),
              if (!isVoided)
                session.when(
                  data: (currentSession) {
                    if (currentSession?.role == AuthRole.admin) {
                      return FilledButton.icon(
                        onPressed: () =>
                            _voidSale(context, ref, sale.id, currentSession!),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Anular venta'),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        currentSession?.role == AuthRole.cashier
                            ? 'Solo Admin puede anular ventas.'
                            : 'Inicia sesión con una cuenta Admin para anular.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No se pudo verificar el rol: $error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _voidSale(
  BuildContext context,
  WidgetRef ref,
  String saleId,
  AuthSession session,
) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => const _VoidSaleReasonDialog(),
  );
  if (reason == null) {
    return;
  }

  try {
    await ref
        .read(salesRepositoryProvider)
        .voidSale(
          saleId: saleId,
          actorUserId: session.userId,
          actorRole: session.role == AuthRole.admin
              ? SaleActorRole.admin
              : SaleActorRole.cashier,
          reason: reason,
        );
    ref.invalidate(saleDetailsProvider(saleId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venta anulada localmente; queda pendiente de sync.'),
        ),
      );
    }
  } on SaleValidationException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  } on SaleAuthorizationException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _VoidSaleReasonDialog extends StatefulWidget {
  const _VoidSaleReasonDialog();

  @override
  State<_VoidSaleReasonDialog> createState() => _VoidSaleReasonDialogState();
}

class _VoidSaleReasonDialogState extends State<_VoidSaleReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular venta'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _reasonController,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Ingresa el motivo de anulación.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Anular')),
      ],
    );
  }
}
