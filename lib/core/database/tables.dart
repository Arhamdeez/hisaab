import 'package:drift/drift.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  TextColumn get type => text()();
  TextColumn get merchant => text()();
  TextColumn get category => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => text()();
  TextColumn get rawText => text().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(1.0))();
  TextColumn get status => text()();
  TextColumn get fingerprint => text()();
  TextColumn get linkedSources => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MonthlySummaries extends Table {
  TextColumn get yearMonth => text()();
  RealColumn get totalDebit => real()();
  RealColumn get totalCredit => real()();
  TextColumn get byCategoryJson => text()();
  IntColumn get transactionCount => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {yearMonth};
}

class ParserRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get pattern => text()();
  TextColumn get sourceHint => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
