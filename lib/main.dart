import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/data/local_data_persistence.dart';
import 'core/database/app_database.dart';
import 'core/repositories/transaction_repository.dart';
import 'core/support/crash_buffer.dart';
import 'features/backup/backup_service.dart';
import 'features/dedup/deduplicator.dart';
import 'features/ingest/ingest_bridge.dart';
import 'features/ingest/ingest_service.dart';
import 'providers/app_preferences.dart';
import 'providers/category_catalog.dart';
import 'providers/transaction_provider.dart';
import 'screens/app_bootstrap.dart';
import 'core/brand.dart';
import 'core/motion.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installCrashHandlers();
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
  final transactionProvider = TransactionProvider(
    repository: repository,
    deduplicator: deduplicator,
  );
  final ingestService = IngestService(
    repository: repository,
    onTransactionsChanged: transactionProvider.reload,
  );
  final backupService = BackupService(repository);

  // Load existing rows fast so the UI paints immediately with real data.
  await transactionProvider.load();

  if (Platform.isAndroid) {
    final migration = await IngestBridge.instance.getLegacyMigrationStatus();
    if (migration.migrated) {
      await transactionProvider.load();
    }
  }

  final prefs = await SharedPreferences.getInstance();
  await LocalDataPersistence.recoverReturningUser(
    repository: repository,
    prefs: prefs,
  );
  await LocalDataPersistence.cleanupLegacyDevDataOnce(
    repository: repository,
    prefs: prefs,
  );

  runApp(
    SpendTrackerApp(
      repository: repository,
      deduplicator: deduplicator,
      ingestService: ingestService,
      backupService: backupService,
      transactionProvider: transactionProvider,
    ),
  );

  // Drain captures off the critical path so a heavy shade scan / queue drain
  // never freezes the first frame. Rows refresh via [onTransactionsChanged].
  unawaited(ingestService.initialize());

  unawaited(_warmFontsAndPrefs(repository));
}

void _installCrashHandlers() {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    defaultOnError?.call(details);
    unawaited(
      CrashBuffer.record(
        details.exception,
        details.stack ?? StackTrace.empty,
      ),
    );
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(CrashBuffer.record(error, stack));
    return true;
  };
}

Future<void> _warmFontsAndPrefs(TransactionRepository repository) async {
  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w400);
  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600);
  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700);
  await GoogleFonts.pendingFonts();
  await AppPreferences.load();
  await CategoryCatalog.load();
}

class SpendTrackerApp extends StatelessWidget {
  const SpendTrackerApp({
    super.key,
    required this.repository,
    required this.deduplicator,
    required this.ingestService,
    required this.backupService,
    required this.transactionProvider,
  });

  final TransactionRepository repository;
  final Deduplicator deduplicator;
  final IngestService ingestService;
  final BackupService backupService;
  final TransactionProvider transactionProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: transactionProvider),
        ChangeNotifierProvider.value(value: ingestService),
        Provider.value(value: backupService),
        ChangeNotifierProvider.value(value: AppPreferences.instance),
        ChangeNotifierProvider.value(value: CategoryCatalog.instance),
      ],
      child: _IngestSync(
        child: MaterialApp(
          title: AppBrand.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          scrollBehavior: const AppScrollBehavior(),
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
    // Captures during initialize() finish before this listener exists — reload once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionProvider>().reload();
    });
  }

  @override
  void dispose() {
    _ingest?.removeListener(_onIngest);
    super.dispose();
  }

  void _onIngest() {
    // Transaction lists reload via [IngestService.onTransactionsChanged].
    // This listener only rebuilds ingest-dependent UI (settings, etc.).
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
