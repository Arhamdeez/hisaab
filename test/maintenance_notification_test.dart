import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/parser/transaction_parser.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  final parser = TransactionParser();

  group('rejects bank maintenance / service outage alerts', () {
    test('rejects Raqami RAAST maintenance notice', () {
      expect(
        parser.parse(
          'Dear Customer, Raqami RAAST services will be unavailable due to maintenance from 05:00 AM to 09:00 AM on 11 July 2026. You may experience intermittent service disruptions during this period. For any queries, please call 051 — 111 — 727 — 264.',
          source: TransactionSource.notification,
          packageName: 'com.raqamidigital.cbt',
          notificationTitle: 'Raqami Islamic Digital Bank Limited',
        ),
        isNull,
      );
    });

    test('rejects BRD RAAST system maintenance notice', () {
      expect(
        parser.parse(
          'RAAST system maintenance has been scheduled for Saturday, 11th July 2026, from 5:00 AM to 9:00 AM. During this period, RAAST payment services will be temporarily unavailable. We apologize for any inconvenience caused.',
          source: TransactionSource.notification,
          packageName: 'app.com.brd',
          notificationTitle: 'Important Notification ⚠️',
        ),
        isNull,
      );
    });
  });
}
