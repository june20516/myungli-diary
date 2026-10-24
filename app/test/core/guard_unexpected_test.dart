import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/fakes.dart';

void main() {
  test('성공하면 값을 그대로 돌려주고 아무것도 기록하지 않습니다', () async {
    final reporter = FakeCrashReporter();
    expect(await guardUnexpected(reporter, () async => 7), 7);
    expect(reporter.errors, isEmpty);
  });

  test('AppError는 감싸지 않고 기록하지 않습니다', () async {
    final reporter = FakeCrashReporter();
    const offline = OfflineError();
    await expectLater(
      guardUnexpected<void>(reporter, () async => throw offline),
      throwsA(same(offline)),
    );
    expect(reporter.errors, isEmpty);
  });

  test('그 밖의 오류는 요약만 기록하고 UnexpectedError로 감쌉니다(D64)', () async {
    final reporter = FakeCrashReporter();
    final cause = StateError('하늘 1990-05-15');
    await expectLater(
      guardUnexpected<void>(reporter, () async => throw cause),
      throwsA(
        isA<UnexpectedError>().having((e) => e.cause, 'cause', same(cause)),
      ),
    );
    expect(reporter.errors, hasLength(1));
    expect(reporter.errors.single.errorType, 'StateError');
    expect(reporter.errors.single.code, isNull);
  });

  group('recordUnlessAppError', () {
    test('AppError는 기록하지 않습니다', () {
      final reporter = FakeCrashReporter();
      recordUnlessAppError(reporter, const OfflineError(), StackTrace.empty);
      recordUnlessAppError(
        reporter,
        const ProblemError(
          code: 'billing.provider_unavailable',
          status: 503,
          fieldErrors: [],
          traceId: 't',
        ),
        StackTrace.empty,
      );
      expect(reporter.errors, isEmpty);
    });

    test('UnexpectedError는 감싼 원인의 타입으로 한 번 기록합니다', () {
      final reporter = FakeCrashReporter();
      recordUnlessAppError(
        reporter,
        UnexpectedError(StateError('하늘 1990-05-15')),
        StackTrace.empty,
      );
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.errorType, 'StateError');
      expect(reporter.errors.single.code, isNull);
      expect(reporter.errors.single.status, isNull);
    });

    test('그 밖의 오류는 그 타입으로 한 번 기록합니다', () {
      final reporter = FakeCrashReporter();
      recordUnlessAppError(reporter, ArgumentError('x'), StackTrace.empty);
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.errorType, 'ArgumentError');
    });
  });
}
