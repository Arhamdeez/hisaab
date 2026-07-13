import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spend_tracker/core/support/crash_buffer.dart';
import 'package:spend_tracker/core/support/issue_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashBuffer', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores and reads the latest crash', () async {
      await CrashBuffer.record(
        StateError('test failure'),
        StackTrace.fromString('#0 main\n#1 run'),
      );

      final snapshot = await CrashBuffer.latest();
      expect(snapshot, isNotNull);
      expect(snapshot!.error, contains('test failure'));
      expect(snapshot.stack, contains('#0 main'));
    });

    test('clear removes stored crash', () async {
      await CrashBuffer.record(Exception('x'), StackTrace.current);
      await CrashBuffer.clear();
      expect(await CrashBuffer.latest(), isNull);
    });
  });

  group('IssueReport', () {
    test('buildBody includes user message and omits crash when disabled', () async {
      SharedPreferences.setMockInitialValues({});
      await CrashBuffer.record(Exception('hidden'), StackTrace.current);

      final body = await IssueReport.buildBody(
        userMessage: 'App froze on home',
        includeCrash: false,
        packageInfo: PackageInfo(
          appName: 'HISAAB',
          packageName: 'com.arham.hisaab',
          version: '0.1.0',
          buildNumber: '1',
        ),
      );

      expect(body, contains('App froze on home'));
      expect(body, contains('0.1.0'));
      expect(body, isNot(contains('hidden')));
    });
  });
}
