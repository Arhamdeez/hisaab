import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/repositories/transaction_repository.dart';
import 'backup_preferences.dart';

/// Outcome of an export or restore, used to drive UI feedback.
class BackupResult {
  const BackupResult._({
    required this.status,
    this.count = 0,
    this.message,
  });

  const BackupResult.success(int count, {String? message})
      : this._(status: BackupStatus.success, count: count, message: message);
  const BackupResult.cancelled() : this._(status: BackupStatus.cancelled);
  const BackupResult.failure(String message)
      : this._(status: BackupStatus.failure, message: message);

  final BackupStatus status;
  final int count;
  final String? message;

  bool get isSuccess => status == BackupStatus.success;
  bool get isCancelled => status == BackupStatus.cancelled;
  bool get isFailure => status == BackupStatus.failure;
}

enum BackupStatus { success, cancelled, failure }

/// Restores a database file the user already has.
///
/// Everyday saves stay in the on-device SQLite file. The phone's own backup
/// includes that file, so a reinstall can bring transactions back without an
/// export step.
class BackupService {
  BackupService(this._repository);

  final TransactionRepository _repository;

  /// Consistent copy of the open database with preferences embedded.
  ///
  /// The live database is left unchanged. [destination] defaults to the app
  /// temp directory.
  Future<File> createSnapshotFile({Directory? destination}) async {
    final db = _repository.database;
    final live = await db.resolveFile();
    if (!await live.exists()) {
      throw StateError('Database file not found');
    }

    final dir = destination ?? await getTemporaryDirectory();
    await dir.create(recursive: true);
    final stamp = _stamp();
    final out = File(p.join(dir.path, 'hisaab_backup_$stamp.sqlite'));
    if (await out.exists()) await out.delete();

    await _writeConsistentCopy(db, out);
    await _embedPreferences(out);
    return out;
  }

  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// Replaces the on-device database with a HISAAB backup.
  ///
  /// [confirm] is called with the number of transactions in the file. Return
  /// false to leave the phone's data as it is.
  Future<BackupResult> restoreFromFile(
    String sourcePath, {
    required Future<bool> Function(int count) confirm,
    Directory? scratchDirectory,
  }) async {
    File? scratch;
    try {
      final source = File(sourcePath);
      if (!await _isSqliteFile(source)) {
        return const BackupResult.failure(
          'Choose a HISAAB backup file (.sqlite)',
        );
      }

      final scratchDir = scratchDirectory ?? await getTemporaryDirectory();
      await scratchDir.create(recursive: true);
      scratch = File(
        p.join(
          scratchDir.path,
          'hisaab_restore_${DateTime.now().microsecondsSinceEpoch}.sqlite',
        ),
      );
      await source.copy(scratch.path);

      final preview = await _readBackup(scratch);
      if (preview == null) {
        return const BackupResult.failure(
          'That file is not a backup exported from HISAAB',
        );
      }

      final accepted = await confirm(preview.count);
      if (!accepted) {
        return const BackupResult.cancelled();
      }

      await _replaceLiveFile(scratch);
      final prefs = await SharedPreferences.getInstance();
      await BackupPreferences.apply(prefs, preview.preferences);

      final count = await _repository.countTransactions();
      return BackupResult.success(
        count,
        message: count == 0
            ? 'Backup restored'
            : 'Restored $count transactions',
      );
    } catch (e) {
      debugPrint('Backup restore failed: $e');
      return BackupResult.failure('Could not restore backup: $e');
    } finally {
      if (scratch != null) {
        await _deleteIfExists(scratch);
        await _deleteSidecars(scratch);
      }
    }
  }

  Future<void> _writeConsistentCopy(AppDatabase db, File out) async {
    try {
      await db.customStatement("VACUUM INTO '${_sqlString(out.path)}'");
      return;
    } catch (e) {
      debugPrint('VACUUM INTO failed, copying database file: $e');
      if (await out.exists()) await out.delete();
    }
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    final live = await db.resolveFile();
    await live.copy(out.path);
    await _deleteSidecars(out);
  }

  Future<void> _embedPreferences(File snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final staged = AppDatabase.forFile(snapshot);
    try {
      await staged.setSyncValue(
        BackupPreferences.storageKey,
        BackupPreferences.encode(prefs),
      );
      await staged.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await staged.close();
    }
    await _deleteSidecars(snapshot);
  }

  /// Returns null when [file] is not a HISAAB export.
  Future<({int count, String preferences})?> _readBackup(File file) async {
    final probe = AppDatabase.forFile(file);
    try {
      final preferences = await probe.getSyncValue(BackupPreferences.storageKey);
      if (preferences == null) return null;
      final count = await probe.countTransactions();
      await probe.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      return (count: count, preferences: preferences);
    } catch (e) {
      debugPrint('Backup probe failed: $e');
      return null;
    } finally {
      await probe.close();
      await _deleteSidecars(file);
    }
  }

  Future<void> _replaceLiveFile(File snapshot) async {
    final previous = _repository.database;
    final live = await previous.resolveFile();
    await _repository.checkpointAndClose();

    final bak = File('${live.path}.bak');
    var replaced = false;
    try {
      await _deleteSidecars(live);
      await _deleteIfExists(bak);
      if (await live.exists()) {
        await live.rename(bak.path);
      }
      await snapshot.copy(live.path);
      replaced = true;
      await _deleteIfExists(bak);
    } catch (e) {
      if (!replaced && !await live.exists() && await bak.exists()) {
        await bak.rename(live.path);
      }
      rethrow;
    } finally {
      _repository.adoptDatabase(AppDatabase.forFile(live));
    }
  }

  static Future<bool> _isSqliteFile(File file) async {
    if (!await file.exists()) return false;
    if (await file.length() < 16) return false;
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      return String.fromCharCodes(header) == 'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  static String _sqlString(String value) => value.replaceAll("'", "''");

  static Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  static Future<void> _deleteSidecars(File database) async {
    await _deleteIfExists(File('${database.path}-wal'));
    await _deleteIfExists(File('${database.path}-shm'));
  }

}
