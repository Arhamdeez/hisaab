import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/ingest/shortcuts_ingest.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  group('ShortcutsIngest.eventFromUri', () {
    test('parses import text as sms by default', () {
      final event = ShortcutsIngest.eventFromUri(
        Uri.parse(
          'hisaab://import?text=Rs.500%20sent%20to%20Ali',
        ),
      );
      expect(event, isNotNull);
      expect(event!.text, 'Rs.500 sent to Ali');
      expect(event.source, TransactionSource.sms);
      expect(event.notificationTitle, isNull);
    });

    test('reads title and source query params', () {
      final event = ShortcutsIngest.eventFromUri(
        Uri.parse(
          'hisaab://import?text=Money%20received&title=JazzCash&source=sms',
        ),
      );
      expect(event, isNotNull);
      expect(event!.notificationTitle, 'JazzCash');
      expect(event.source, TransactionSource.sms);
    });

    test('rejects wrong scheme or empty text', () {
      expect(
        ShortcutsIngest.eventFromUri(Uri.parse('https://example.com/import?text=x')),
        isNull,
      );
      expect(
        ShortcutsIngest.eventFromUri(Uri.parse('hisaab://import?text=')),
        isNull,
      );
    });

    test('accepts body alias and epoch ts', () {
      final event = ShortcutsIngest.eventFromUri(
        Uri.parse(
          'hisaab://import?body=PKR%20100%20debited&ts=1700000000000',
        ),
      );
      expect(event, isNotNull);
      expect(event!.text, 'PKR 100 debited');
      expect(
        event.timestamp.millisecondsSinceEpoch,
        1700000000000,
      );
    });
  });
}
