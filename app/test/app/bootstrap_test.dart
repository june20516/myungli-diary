import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';

import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('오류 핸들러 (D64)', () {
    late FlutterExceptionHandler? originalFlutterHandler;
    late ErrorCallback? originalPlatformHandler;

    setUp(() {
      originalFlutterHandler = FlutterError.onError;
      originalPlatformHandler = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = originalFlutterHandler;
      PlatformDispatcher.instance.onError = originalPlatformHandler;
    });

    test('원본 예외 문자열 없이 요약만 보고합니다', () async {
      final reporter = FakeCrashReporter();
      await AssetManifest.loadFromAssetBundle(rootBundle);
      final handled = await bootstrap(
        mode: ApiMode.fake,
        scenarioId: 'new-user',
        overrides: [
          ...testOverrides(),
          crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      addTearDown(handled.dispose);

      const secret = '출생일 1990-05-17 호칭 민수';
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError(secret),
          stack: StackTrace.current,
        ),
      );
      final consumed = PlatformDispatcher.instance.onError!(
        const FormatException(secret),
        StackTrace.current,
      );

      expect(consumed, isTrue);
      expect(reporter.errors, hasLength(2));
      expect(reporter.errors, everyElement(isA<CrashSummary>()));
      expect(reporter.errors.map((e) => e.errorType), [
        'StateError',
        'FormatException',
      ]);
      final recorded = reporter.errors
          .map((e) => '${e.errorType} ${e.code} ${e.status}')
          .join();
      expect(recorded, isNot(contains('1990')));
      expect(recorded, isNot(contains('민수')));
    });
  });

  test('fake 모드는 시나리오 today의 현지 정오 시계와 시나리오 시간대를 씁니다', () async {
    final container = await bootstrapForTest('member');
    addTearDown(container.dispose);
    // member: 2026-10-13, Asia/Seoul → 정오 = UTC 03:00
    expect(
      container.read(clockProvider).nowUtc(),
      DateTime.utc(2026, 10, 13, 3),
    );
    expect(container.read(profileTimezoneProvider), 'Asia/Seoul');
    expect(container.read(todayProvider), CalendarDate(2026, 10, 13));
  });

  test('첫 프레임 전에 기기 시간대를 읽어 둡니다', () async {
    final container = await bootstrapForTest('member');
    addTearDown(container.dispose);
    expect(container.read(deviceTimezoneNameProvider).value, 'Asia/Seoul');
  });

  test('없는 시나리오면 bootstrap이 던집니다', () {
    expect(
      () => bootstrap(
        mode: ApiMode.fake,
        scenarioId: 'no-such',
        installErrorHandlers: false,
        overrides: testOverrides(),
      ),
      throwsStateError,
    );
  });
}
