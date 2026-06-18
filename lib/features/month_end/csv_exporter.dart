import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/transaction.dart';
import '../../providers/category_catalog.dart';

class CsvExporter {
  static Future<void> exportMonth({
    required List<Transaction> transactions,
    required int year,
    required int month,
  }) async {
    final buffer = StringBuffer()
      ..writeln('Date,Merchant,Category,Type,Amount,Currency,Source,Status');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    for (final t in transactions) {
      buffer.writeln([
        dateFormat.format(t.occurredAt),
        _escape(t.merchant),
        _escape(CategoryCatalog.instance.resolve(t.categoryId).label),
        t.type.name,
        t.amount.toStringAsFixed(2),
        t.currency,
        t.source.name,
        t.status.name,
      ].join(','));
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/spend_tracker_${year}_${month.toString().padLeft(2, '0')}.csv',
    );
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Spend Tracker — ${DateFormat('MMMM yyyy').format(DateTime(year, month))}',
    );
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String categoryBreakdownJson(List<CategorySummary> summaries) =>
      jsonEncode(
        summaries
            .map(
              (s) => {
                'category': s.categoryId,
                'total': s.total,
                'count': s.count,
              },
            )
            .toList(),
      );
}
