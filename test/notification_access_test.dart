import 'package:flutter_test/flutter_test.dart';
import 'package:spend_tracker/core/brand.dart';
import 'package:spend_tracker/features/ingest/ingest_bridge.dart';
import 'package:spend_tracker/features/ingest/notification_access.dart';

void main() {
  group('NotificationAccessOpenResult', () {
    test('fromMap parses native payload', () {
      final result = NotificationAccessOpenResult.fromMap({
        'opened': true,
        'via': 'ACTION_NOTIFICATION_LISTENER_SETTINGS',
        'manufacturer': 'samsung',
        'model': 'SM-S931U1',
        'sdkInt': 35,
      });

      expect(result.opened, isTrue);
      expect(result.via, 'ACTION_NOTIFICATION_LISTENER_SETTINGS');
      expect(result.manufacturer, 'samsung');
      expect(result.model, 'SM-S931U1');
      expect(result.sdkInt, 35);
    });
  });

  group('NotificationAccess manual steps', () {
    test('samsung path mentions security settings', () {
      final steps = NotificationAccess.manualStepsFor('samsung');
      expect(steps.first, 'Open Settings');
      expect(steps.join(' '), contains('Security'));
      expect(steps.last, contains(AppBrand.name));
    });

    test('xiaomi path mentions special permissions', () {
      final steps = NotificationAccess.manualStepsFor('Xiaomi');
      expect(steps.join(' '), contains('Special permissions'));
    });

    test('default path covers generic Android', () {
      final steps = NotificationAccess.manualStepsFor('Google');
      expect(steps.join(' '), contains('Notification access'));
    });
  });
}
