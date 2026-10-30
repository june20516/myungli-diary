import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/firebase_crash_reporter.dart';

const _accountId = '0b7c2f1e-3d4a-4b5c-8d9e-0f1a2b3c4d5e';

final class _RecordingCrashlyticsApi implements CrashlyticsApi {
  final errors = <Object>[];
  final userIds = <String>[];
  final logs = <String>[];

  @override
  Future<void> recordError(Object exception, StackTrace stack) async =>
      errors.add(exception);

  @override
  Future<void> setUserIdentifier(String id) async => userIds.add(id);

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async {}
}

/// 모든 호출이 비동기로 실패합니다.
final class _FailingCrashlyticsApi implements CrashlyticsApi {
  @override
  Future<void> recordError(Object exception, StackTrace stack) =>
      Future.error(StateError('비동기 실패'));

  @override
  Future<void> setUserIdentifier(String id) => Future.error(StateError('실패'));

  @override
  Future<void> log(String message) => Future.error(StateError('실패'));

  @override
  Future<void> setCollectionEnabled({required bool enabled}) =>
      Future.error(StateError('실패'));
}

/// `FirebaseCrashlytics.instance`가 초기화 전이라 동기로 던지는 경우입니다.
final class _ThrowingCrashlyticsApi implements CrashlyticsApi {
  @override
  Future<void> recordError(Object exception, StackTrace stack) =>
      throw StateError('동기 실패');

  @override
  Future<void> setUserIdentifier(String id) => throw StateError('동기 실패');

  @override
  Future<void> log(String message) => throw StateError('동기 실패');

  @override
  Future<void> setCollectionEnabled({required bool enabled}) =>
      throw StateError('동기 실패');
}

void main() {
  group('CrashSummary.toString', () {
    test('타입, code, status만 담습니다', () {
      final summary = CrashSummary.from(
        const ProblemError(
          code: 'diary.not_found',
          status: 404,
          fieldErrors: [],
          traceId: 'trace-1',
        ),
      );
      expect(
        summary.toString(),
        'CrashSummary(errorType: ProblemError, code: diary.not_found, '
        'status: 404)',
      );
    });

    test('없는 값은 뺍니다', () {
      expect(
        CrashSummary.from(StateError('일기 본문')).toString(),
        'CrashSummary(errorType: StateError)',
      );
    });
  });

  group('FirebaseCrashReporter', () {
    test('record는 원문 오류가 아니라 CrashSummary만 싣습니다', () async {
      final api = _RecordingCrashlyticsApi();
      final summary = CrashSummary.from(StateError('일기 본문: 비밀'));
      FirebaseCrashReporter(api: api).record(summary, StackTrace.current);
      await pumpEventQueue();
      expect(api.errors, [same(summary)]);
      expect(api.errors.single.toString(), isNot(contains('비밀')));
    });

    test('setUser(null)은 빈 id', () async {
      final api = _RecordingCrashlyticsApi();
      FirebaseCrashReporter(api: api).setUser(null);
      await pumpEventQueue();
      expect(api.userIds, ['']);
    });

    test('setUser는 sanitizeAccountId를 거친 값', () async {
      final api = _RecordingCrashlyticsApi();
      FirebaseCrashReporter(api: api)
        ..setUser(_accountId)
        ..setUser('honorific@example.com');
      await pumpEventQueue();
      expect(api.userIds, [_accountId, '']);
    });

    test('breadcrumb은 sanitizeScreenId가 null이면 싣지 않음', () async {
      final api = _RecordingCrashlyticsApi();
      FirebaseCrashReporter(api: api)
        ..breadcrumb('today')
        ..breadcrumb('일기 본문');
      await pumpEventQueue();
      expect(api.logs, ['screen: today']);
    });

    test('SDK가 비동기로 실패해도 던지지 않음', () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        FirebaseCrashReporter(api: _FailingCrashlyticsApi())
          ..record(CrashSummary.from(StateError('x')), StackTrace.current)
          ..setUser(_accountId)
          ..breadcrumb('today');
        await pumpEventQueue();
      }, (error, _) => errors.add(error));
      expect(errors, isEmpty);
    });

    test('SDK가 동기로 던져도 던지지 않음', () {
      final reporter = FirebaseCrashReporter(api: _ThrowingCrashlyticsApi());
      expect(
        () => reporter
          ..record(CrashSummary.from(StateError('x')), StackTrace.current)
          ..setUser(_accountId)
          ..breadcrumb('today'),
        returnsNormally,
      );
    });
  });
}
