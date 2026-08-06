import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/features/ingest/ingest_bridge.dart';
import 'package:spend_tracker/features/ingest/sms_sender_filter.dart';
import 'package:spend_tracker/models/transaction.dart';

void main() {
  group('SmsSenderFilter', () {
    test('detects personal PK mobiles including spaced and +92 forms', () {
      expect(SmsSenderFilter.isPersonalMobile('0305 6150087'), isTrue);
      expect(SmsSenderFilter.isPersonalMobile('03056150087'), isTrue);
      expect(SmsSenderFilter.isPersonalMobile('+923056150087'), isTrue);
      expect(SmsSenderFilter.isPersonalMobile('923056150087'), isTrue);
      expect(SmsSenderFilter.isPersonalMobile('3056150087'), isTrue);
    });

    test('does not treat wallet short codes as personal mobiles', () {
      expect(SmsSenderFilter.isPersonalMobile('3737'), isFalse);
      expect(SmsSenderFilter.isPersonalMobile('8558'), isFalse);
      expect(SmsSenderFilter.isPersonalMobile('18258'), isFalse);
      expect(SmsSenderFilter.isNumericShortCode('3737'), isTrue);
      expect(SmsSenderFilter.isNumericShortCode('18258'), isTrue);
    });

    test('shouldAcceptSmsSender rejects personal mobiles only', () {
      expect(SmsSenderFilter.shouldAcceptSmsSender('0305 6150087'), isFalse);
      expect(SmsSenderFilter.shouldAcceptSmsSender('3737'), isTrue);
      expect(SmsSenderFilter.shouldAcceptSmsSender(null), isTrue);
      expect(SmsSenderFilter.shouldAcceptSmsSender(''), isTrue);
    });
  });

  group('IngestBridge.eventFromNativeMap', () {
    const spamBody =
        '3737 Trx ID 15569158646. You have Received KHALIDA BIBI Rs.10000 '
        'from with Easypaisa Account 0340-8932674 and your new Easypaisa '
        'account balance is Rs.26,624.57';

    test('drops SMS spoof from personal mobile even with wallet wording', () {
      expect(
        IngestBridge.eventFromNativeMap({
          'source': 'sms',
          'sender': '0305 6150087',
          'text': spamBody,
          'timestamp': 1,
        }),
        isNull,
      );
    });

    test('keeps SMS from Easypaisa short code 3737', () {
      final event = IngestBridge.eventFromNativeMap({
        'source': 'sms',
        'sender': '3737',
        'text':
            'Trx ID 15569158646. You have received Rs.10000 from KHALIDA BIBI '
            'with Easypaisa Account. TID: 12345.',
        'timestamp': 1,
      });
      expect(event, isNotNull);
      expect(event!.source, TransactionSource.sms);
      // Short codes are not used as merchant titles.
      expect(event.notificationTitle, isNull);
    });

    test('does not filter non-SMS notification events by sender', () {
      final event = IngestBridge.eventFromNativeMap({
        'source': 'notification',
        'title': 'Money Received',
        'package': 'com.echarge.easypaisa',
        'text': 'You have received Rs.100.00',
        'timestamp': 1,
      });
      expect(event, isNotNull);
      expect(event!.source, TransactionSource.notification);
    });
  });
}
