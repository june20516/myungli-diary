import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';

final _date = CalendarDate(2026, 10, 13);

/// `/v1/diaries/{date}`를 [status]로 답하고 요청 경로를 남깁니다.
final class _DiaryServer extends Interceptor {
  new(this.status);

  int status;

  /// true면 200 본문을 Diary로 읽을 수 없는 모양으로 보냅니다(역직렬화 실패).
  bool brokenBody = false;
  final paths = <String>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    paths.add(options.path);
    final body = status == 200 && brokenBody
        ? <String, Object>{'date': 13}
        : status == 200
        ? <String, Object>{
            'date': '2026-10-13',
            'body': '일기',
            'tags': {'featured': <Object>[], 'all': <Object>[]},
            'rulesetVersion': 'r1',
            'createdAt': '2026-10-13T12:00:00Z',
            'updatedAt': '2026-10-13T12:00:00Z',
          }
        : <String, Object>{
            'type': 'about:blank',
            'title': 'problem',
            'status': status,
            'code': status == 404 ? 'diary.not_found' : 'service.unavailable',
          };
    final response = Response<Object?>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: [
          if (status >= 400) 'application/problem+json' else 'application/json',
        ],
      }),
      data: body,
    );
    if (status >= 400) {
      handler.reject(
        DioException.badResponse(
          statusCode: status,
          requestOptions: options,
          response: response,
        ),
        true,
      );
      return;
    }
    handler.resolve(response, true);
  }
}

/// 일기를 물으면 Dio 밖의 예외(프로그래밍 오류)를 던지는 클라이언트.
final class _BrokenApi extends DefaultApi {
  new() : super(Dio());

  @override
  Future<Response<Diary>> getDiary({
    required String date,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async => throw StateError('버그');
}

DiaryRepository _repository(_DiaryServer server) => DiaryRepository(
  DefaultApi(
    Dio(BaseOptions(baseUrl: 'https://example.test'))..interceptors.add(server),
  ),
);

void main() {
  group('DiaryRepository.existsOn', () {
    test('200이면 true이고 그날 경로를 묻습니다', () async {
      final server = _DiaryServer(200);
      expect(await _repository(server).existsOn(_date), isTrue);
      expect(server.paths, ['/v1/diaries/2026-10-13']);
    });

    test('404면 false입니다', () async {
      expect(await _repository(_DiaryServer(404)).existsOn(_date), isFalse);
    });

    test('server problem은 ProblemError입니다', () async {
      await expectLater(
        _repository(_DiaryServer(503)).existsOn(_date),
        throwsA(isA<ProblemError>()),
      );
    });

    test('Dio 밖의 예외는 바꾸지 않고 그대로 던집니다', () async {
      await expectLater(
        DiaryRepository(_BrokenApi()).existsOn(_date),
        throwsA(isA<StateError>()),
      );
    });

    test('본문을 읽지 못하면 UnexpectedError입니다', () async {
      await expectLater(
        _repository(_DiaryServer(200)..brokenBody = true).existsOn(_date),
        throwsA(isA<UnexpectedError>()),
      );
    });
  });

  group('todayDiaryExistsProvider', () {
    late FakeCrashReporter reporter;

    ProviderContainer containerFor(
      _DiaryServer server, {
      DiaryRepository? repository,
    }) {
      reporter = FakeCrashReporter();
      final container = ProviderContainer(
        overrides: [
          todayProvider.overrideWithValue(_date),
          crashReporterProvider.overrideWithValue(reporter),
          diaryRepositoryProvider.overrideWithValue(
            repository ?? _repository(server),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('오늘 일기가 있으면 true입니다', () async {
      final container = containerFor(_DiaryServer(200));
      expect(await container.read(todayDiaryExistsProvider.future), isTrue);
    });

    test('server·연결 실패(AppError)는 보고 없이 false입니다', () async {
      final container = containerFor(_DiaryServer(503));
      expect(await container.read(todayDiaryExistsProvider.future), isFalse);
      expect(reporter.errors, isEmpty);
    });

    test('본문을 읽지 못하면 한 번 보고하고 false입니다', () async {
      final container = containerFor(_DiaryServer(200)..brokenBody = true);
      expect(await container.read(todayDiaryExistsProvider.future), isFalse);
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.errorType, 'UnexpectedError');
    });

    test('AppError가 아닌 오류도 한 번 보고하고 false입니다', () async {
      final container = containerFor(
        _DiaryServer(200),
        repository: DiaryRepository(_BrokenApi()),
      );
      expect(await container.read(todayDiaryExistsProvider.future), isFalse);
      expect(reporter.errors, hasLength(1));
      expect(reporter.errors.single.errorType, 'StateError');
    });

    test('invalidate하면 다시 묻습니다(일기를 쓰고 돌아온 화면)', () async {
      final server = _DiaryServer(404);
      final container = containerFor(server);
      expect(await container.read(todayDiaryExistsProvider.future), isFalse);
      server.status = 200;
      container.invalidate(todayDiaryExistsProvider);
      expect(await container.read(todayDiaryExistsProvider.future), isTrue);
      expect(server.paths, hasLength(2));
    });
  });
}
