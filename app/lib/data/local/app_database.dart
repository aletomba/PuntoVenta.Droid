import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [LocalSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'puntoventa'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
