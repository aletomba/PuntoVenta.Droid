import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> initializeObservability({
  required FutureOr<void> Function() appRunner,
}) async {
  if (_sentryDsn.isEmpty) {
    appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) => options.dsn = _sentryDsn,
    appRunner: appRunner,
  );
}
