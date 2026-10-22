import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';

/// 모든 요청에 [respond]가 정한 대로 답합니다.
final class _Scripted extends Interceptor {
  new(this.respond);

  final void Function(RequestOptions, RequestInterceptorHandler) respond;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) =>
      respond(options, handler);
}

/// 같은 날 두 편을 id 정렬 순서와 반대인 채로(createdAt은 계약 순서) 답합니다.
void _twoDiariesNotSorted(
  RequestOptions options,
  RequestInterceptorHandler handler,
) {
  Map<String, Object?> summary(String id, String createdAt) => {
    'id': id,
    'date': '2026-10-12',
    'createdAt': createdAt,
    'excerpt': '본문',
    'featuredTags': <Object?>[],
  };
  handler.resolve(
    Response<Object?>(
      requestOptions: options,
      statusCode: 200,
      data: {
        'items': [
          summary('diary-z', '2026-10-12T09:00:00Z'),
          summary('diary-a', '2026-10-12T10:00:00Z'),
        ],
      },
    ),
  );
}

void _fail(
  DioExceptionType type,
  RequestOptions options,
  RequestInterceptorHandler handler,
) => handler.reject(DioException(requestOptions: options, type: type));

/// 500 problem+json 응답 → `ProblemError`.
void _serverProblem(RequestOptions options, RequestInterceptorHandler handler) {
  handler.reject(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: 500,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/problem+json'],
        }),
        data: {
          'type': 'about:blank',
          'title': '서버 오류',
          'status': 500,
          'code': 'server.internal',
          'traceId': 'trace-1',
        },
      ),
    ),
  );
}

(ProviderContainer, FakeCrashReporter) _container(
  void Function(RequestOptions, RequestInterceptorHandler) respond,
) {
  final crash = FakeCrashReporter();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
    ..interceptors.add(_Scripted(respond));
  final container = ProviderContainer(
    overrides: [
      restClientProvider.overrideWithValue(DefaultApi(dio)),
      crashReporterProvider.overrideWithValue(crash),
    ],
  );
  addTearDown(container.dispose);
  return (container, crash);
}

/// autoDispose가 기다리는 도중 버리지 않도록 구독을 유지한 채 받습니다.
Future<List<DiarySummary>> _load(ProviderContainer container) {
  final provider = diariesOnProvider(CalendarDate(2026, 10, 12));
  container.listen(provider, (_, _) {});
  return container.read(provider.future);
}

void main() {
  group('diariesOnProvider', () {
    test('성공하면 server가 준 순서 그대로입니다(다시 정렬하지 않음)', () async {
      final (container, crash) = _container(_twoDiariesNotSorted);
      final list = await _load(container);
      // id로 다시 정렬하는 회귀를 잡습니다(응답 순서 z, a는 id 정렬과 다름).
      expect(list.map((item) => item.id), ['diary-z', 'diary-a']);
      expect(crash.errors, isEmpty);
    });

    test('OfflineError면 빈 목록이고 보고하지 않습니다', () async {
      final (container, crash) = _container(
        (o, h) => _fail(DioExceptionType.connectionError, o, h),
      );
      expect(await _load(container), isEmpty);
      expect(crash.errors, isEmpty);
    });

    test('TimeoutError면 빈 목록이고 보고하지 않습니다', () async {
      final (container, crash) = _container(
        (o, h) => _fail(DioExceptionType.receiveTimeout, o, h),
      );
      expect(await _load(container), isEmpty);
      expect(crash.errors, isEmpty);
    });

    test('ProblemError(500 problem+json)면 빈 목록이고 보고하지 않습니다', () async {
      final (container, crash) = _container(_serverProblem);
      expect(await _load(container), isEmpty);
      expect(crash.errors, isEmpty);
    });

    test('UnexpectedError면 빈 목록이고 crash 요약을 한 번 남깁니다', () async {
      final (container, crash) = _container(
        (o, h) => _fail(DioExceptionType.unknown, o, h),
      );
      expect(await _load(container), isEmpty);
      expect(crash.errors, hasLength(1));
      expect(crash.errors.single.errorType, 'UnexpectedError');
    });
  });
}
