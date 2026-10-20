import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/data/local/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('persists local settings', () async {
    await database.into(database.localSettings).insert(
          LocalSettingsCompanion.insert(key: 'currency', value: 'ARS'),
        );

    final settings = await database.select(database.localSettings).get();

    expect(settings.single.value, 'ARS');
  });
}
