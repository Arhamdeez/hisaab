import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final logoBytes = await rootBundle.load('assets/images/logo.png');
  await ui.instantiateImageCodec(logoBytes.buffer.asUint8List());

  final database = AppDatabase();
  final repository = TransactionRepository(database);
  final deduplicator = Deduplicator(repository);
  final gmailService = GmailService();
  final ingestService = IngestService(
    repository: repository,
    database: database,
    gmailService: gmailService,
  );
  final backupService = BackupService(repository);

  // Drain background captures into SQLite before the first frame so the inbox
  // is complete even if OS notifications already expired.
  await ingestService.initialize();

  runApp(
    SpendTrackerApp(
      repository: repository,
      deduplicator: deduplicator,
      ingestService: ingestService,
      backupService: backupService,
    ),
  );

  unawaited(_warmFontsAndPrefs(repository));
}

Future<void> _warmFontsAndPrefs(TransactionRepository repository) async {
  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400);
  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600);
  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700);
  await GoogleFonts.pendingFonts();
  await repository.deleteLegacySeedData();
  await AppPreferences.load();
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
      child: _IngestSync(
        child: MaterialApp(
          title: AppBrand.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const AppBootstrap(),
        ),
      ),
    );
  }
}

/// Keeps transaction lists in sync when new captures arrive or are reviewed.
class _IngestSync extends StatefulWidget {
  const _IngestSync({required this.child});

  final Widget child;

  @override
  State<_IngestSync> createState() => _IngestSyncState();
}

class _IngestSyncState extends State<_IngestSync> {
  IngestService? _ingest;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ingest = context.read<IngestService>();
    if (_ingest == ingest) return;
    _ingest?.removeListener(_onIngest);
    _ingest = ingest;
    _ingest!.addListener(_onIngest);
  }

  @override
  void dispose() {
    _ingest?.removeListener(_onIngest);
    super.dispose();
  }

  void _onIngest() {
    if (!mounted) return;
    context.read<TransactionProvider>().reload();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
