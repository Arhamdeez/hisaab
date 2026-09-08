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

    test('rejects other hosts and empty text', () {
      expect(
        ShortcutsIngest.eventFromUri(
          Uri.parse('https://example.com/import?text=x'),
        ),
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

  group('ShortcutsIngest.eventFromRaw', () {
    test('accepts a plain SMS body from the App Intent', () {
      final event = ShortcutsIngest.eventFromRaw(
        'Rs.500 sent to Ali via JazzCash',
      );
      expect(event, isNotNull);
      expect(event!.text, 'Rs.500 sent to Ali via JazzCash');
      expect(event.source, TransactionSource.sms);
    });

    test('pulls text= from a messy unencoded URL', () {
      final event = ShortcutsIngest.eventFromRaw(
        'hisaab://import?text=Rs.500 sent to Ali via JazzCash',
      );
      expect(event, isNotNull);
      expect(event!.text, contains('Rs.500'));
    });

    test('ignores blank input', () {
      expect(ShortcutsIngest.eventFromRaw(''), isNull);
      expect(ShortcutsIngest.eventFromRaw('   '), isNull);
    });

    test('does not ingest a capture URL', () {
      expect(
        ShortcutsIngest.eventFromUri(Uri.parse('hisaab://capture')),
        isNull,
      );
      expect(ShortcutsIngest.isCaptureUri(Uri.parse('hisaab://capture')), isTrue);
      expect(
        ShortcutsIngest.isCaptureUri(Uri.parse('hisaab://import?text=x')),
        isFalse,
      );
    });
  });
}
