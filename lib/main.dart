import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/database/app_database.dart';
import 'core/repositories/transaction_repository.dart';
import 'features/backup/backup_service.dart';
import 'features/dedup/deduplicator.dart';
import 'features/ingest/gmail_service.dart';
import 'features/ingest/ingest_service.dart';
import 'providers/app_preferences.dart';
import 'providers/transaction_provider.dart';
import 'screens/app_bootstrap.dart';
import 'core/brand.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final database = AppDatabase();
  final repository = TransactionRepository(database);
  await repository.deleteLegacySeedData();

  final deduplicator = Deduplicator(repository);
  final gmailService = GmailService();
  final ingestService = IngestService(
    repository: repository,
    database: database,
    gmailService: gmailService,
  );
  final backupService = BackupService(repository);

  await ingestService.initialize();

  await AppPreferences.load();

  runApp(
    SpendTrackerApp(
      repository: repository,
      deduplicator: deduplicator,
      ingestService: ingestService,
      backupService: backupService,
    ),
  );
}

class SpendTrackerApp extends StatelessWidget {
  const SpendTrackerApp({
    super.key,
    required this.repository,
    required this.deduplicator,
    required this.ingestService,
    required this.backupService,
  });

  final TransactionRepository repository;
  final Deduplicator deduplicator;
  final IngestService ingestService;
  final BackupService backupService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(
            repository: repository,
            deduplicator: deduplicator,
          )..load(),
        ),
        ChangeNotifierProvider.value(value: ingestService),
        Provider.value(value: backupService),
        ChangeNotifierProvider.value(value: AppPreferences.instance),
      ],
      child: MaterialApp(
        title: AppBrand.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AppBootstrap(),
      ),
    );
  }
}
