import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/observability.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeObservability(
    appRunner: () => runApp(const ProviderScope(child: PuntoVentaApp())),
  );
}
