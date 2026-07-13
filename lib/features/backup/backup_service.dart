import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data/local_data_persistence.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction.dart';
import '../../providers/category_catalog.dart';

/// Outcome of an export operation, used to drive UI feedback.
class BackupResult {
  const BackupResult._({
    required this.status,
    this.count = 0,
    this.message,
  });

  const BackupResult.success(int count)
      : this._(status: BackupStatus.success, count: count);
  const BackupResult.failure(String message)
      : this._(status: BackupStatus.failure, message: message);

  final BackupStatus status;
  final int count;
  final String? message;

  bool get isSuccess => status == BackupStatus.success;
}

enum BackupStatus { success, failure }

/// Local-only backup: exports all transactions to a plain, human-readable
/// text file the user can save or share. Nothing leaves the device unless the
/// user explicitly shares the file.
class BackupService {
  BackupService(this._repository);

  final TransactionRepository _repository;

  /// Replaces the on-device SQLite database from a picked `.sqlite` file.
  /// Fully close and reopen the app after a successful restore.
  Future<BackupResult> importSqliteFile(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        return const BackupResult.failure('Backup file not found');
      }

      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, LocalDataPersistence.dbFileName));
      await target.parent.create(recursive: true);
      await source.copy(target.path);

      return BackupResult._(
        status: BackupStatus.success,
        message: 'Database restored — fully close and reopen HISAAB',
      );
    } catch (e) {
      debugPrint('Backup import failed: $e');
      return BackupResult.failure('Could not restore database: $e');
    }
  }

  Future<BackupResult> exportToFile() async {
    try {
      final transactions = await _repository.getAll();
      transactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      final text = _buildText(transactions);
      final dir = await getTemporaryDirectory();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File(p.join(dir.path, 'hisaab_backup_$stamp.txt'));
      await file.writeAsString(text);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'HISAAB backup',
        text: 'HISAAB transactions backup (${transactions.length} entries)',
      );

      return BackupResult.success(transactions.length);
    } catch (e) {
      debugPrint('Backup export failed: $e');
      return const BackupResult.failure('Could not create backup');
    }
  }

  String _buildText(List<Transaction> transactions) {
    final now = DateTime.now();
    final dateFmt = DateFormat('d MMM yyyy');
    final stampFmt = DateFormat('d MMM yyyy, h:mm a');

    var totalSpent = 0.0;
    var totalIncome = 0.0;
    for (final t in transactions) {
      if (t.isDebit) {
        totalSpent += t.amount;
      } else {
        totalIncome += t.amount;
      }
    }

    final buffer = StringBuffer()
      ..writeln('HISAAB — Transactions Backup')
      ..writeln('Exported: ${stampFmt.format(now)}')
      ..writeln('Currency: PKR')
      ..writeln('Entries: ${transactions.length}')
      ..writeln()
      ..writeln('Total spent:  ${formatCurrency(totalSpent)}')
      ..writeln('Total income: ${formatCurrency(totalIncome)}')
      ..writeln()
      ..writeln('=' * 40)
      ..writeln();

    if (transactions.isEmpty) {
      buffer.writeln('No transactions recorded yet.');
      return buffer.toString();
    }

    String? currentMonth;
    for (final t in transactions) {
      final month = formatMonthYear(t.occurredAt);
      if (month != currentMonth) {
        if (currentMonth != null) buffer.writeln();
        buffer
          ..writeln(month.toUpperCase())
          ..writeln('-' * month.length);
        currentMonth = month;
      }

      final sign = t.isDebit ? '-' : '+';
      final amount = '$sign${formatCurrency(t.amount)}';
      buffer.writeln(
        '${dateFmt.format(t.occurredAt)}  •  '
        '${t.merchant} (${CategoryCatalog.instance.resolve(t.categoryId).label})  •  $amount',
      );
    }

    return buffer.toString();
  }
}
