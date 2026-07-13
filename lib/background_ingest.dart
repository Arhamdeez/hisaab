import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/app_database.dart';
import 'core/repositories/transaction_repository.dart';
import 'features/ingest/ingest_processor.dart';
import 'features/notifications/notification_service.dart';
import 'providers/app_preferences.dart';

const _bgRescanKey = 'bg_ingest_rescan';
const _doneChannel = MethodChannel('com.arham.hisaab/background_ingest');

/// Headless Android entry — processes queued payment alerts without opening the UI.
@pragma('vm:entry-point')
Future<void> ingestBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  var created = 0;
  try {
    final prefs = await SharedPreferences.getInstance();
    final rescan = prefs.getBool(_bgRescanKey) ?? false;
    await prefs.setBool(_bgRescanKey, false);

    await AppPreferences.load();
    await NotificationService.instance.initialize();

    final database = AppDatabase();
    try {
      final processor = IngestProcessor(
        repository: TransactionRepository(database),
      );
      created = await processor.processPendingQueue(rescanSources: rescan);
    } finally {
      await database.close();
    }

    await _doneChannel.invokeMethod<void>('done', created);
  } catch (e, st) {
    debugPrint('background ingest failed: $e\n$st');
    try {
      await _doneChannel.invokeMethod<void>('error', e.toString());
    } catch (_) {}
  }
}
