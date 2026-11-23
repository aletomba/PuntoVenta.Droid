import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/core/app.dart';

void main() {
  testWidgets('shows the POS home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PuntoVentaApp()));

    expect(find.text('Punto de Venta'), findsOneWidget);
    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.text('Base de la aplicación lista'), findsOneWidget);
    expect(find.text('Historial de ventas'), findsOneWidget);
    expect(find.text('Cierre de caja'), findsOneWidget);
  });

  testWidgets('opens the login form from the POS home screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PuntoVentaApp()));
    await tester.tap(find.byTooltip('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
