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
    await database
        .into(database.localSettings)
        .insert(LocalSettingsCompanion.insert(key: 'currency', value: 'ARS'));

    final settings = await database.select(database.localSettings).get();

    expect(settings.single.value, 'ARS');
  });

  test('migrates schema v1 to v2 and preserves local settings', () async {
    await database.close();
    database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (db) {
          db.execute(
            'CREATE TABLE local_settings ('
            '"key" TEXT NOT NULL, '
            '"value" TEXT NOT NULL, '
            'PRIMARY KEY ("key"))',
          );
          db.execute(
            "INSERT INTO local_settings (\"key\", \"value\") "
            "VALUES ('currency', 'ARS')",
          );
          db.execute('PRAGMA user_version = 1');
        },
      ),
    );

    final settings = await database.select(database.localSettings).get();
    final products = await database.select(database.products).get();

    expect(settings.single.value, 'ARS');
    expect(products, isEmpty);
    expect(database.schemaVersion, 2);
  });
}
