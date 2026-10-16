import 'dart:async';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/api/fake/fake_schedule_store.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';

/// member 시나리오와 같은 2026-10-13 일정(하루 종일·09:07·19:00)과 10-20 일정 하나.
List<Map<String, Object?>> memberSchedules() => [
  {
    'id': 'all-day',
    'date': '2026-10-13',
    'allDay': true,
    'title': '엄마 생신',
    'createdAt': '2026-10-01T03:00:00Z',
    'updatedAt': '2026-10-01T03:00:00Z',
  },
  {
    'id': 'morning',
    'date': '2026-10-13',
    'allDay': false,
    'time': '09:07',
    'title': '팀 주간 회의',
    'memo': '안건 정리',
    'createdAt': '2026-10-10T08:30:00Z',
    'updatedAt': '2026-10-11T01:15:00Z',
  },
  {
    'id': 'evening',
    'date': '2026-10-13',
    'allDay': false,
    'time': '19:00',
    'title': '요가 수업',
    'createdAt': '2026-10-05T12:00:00Z',
    'updatedAt': '2026-10-05T12:00:00Z',
  },
  {
    'id': 'dentist',
    'date': '2026-10-20',
    'allDay': false,
    'time': '14:00',
    'title': '치과 정기 검진',
    'createdAt': '2026-10-12T06:20:00Z',
    'updatedAt': '2026-10-12T06:20:00Z',
  },
];

/// 일정·일기 목록 operation을 [FakeScheduleStore]로 답하는 테스트 서버.
///
/// [offline]·[timeout]이면 서버에 닿기 전에 연결 오류·시간 초과로 끝나 요청 기록이 남지
/// 않습니다. [hold]가 있으면 일정 쓰기(POST·PATCH·DELETE) 응답을 그 Completer가 끝날 때까지
/// 붙잡습니다. [holdNextGet]은 다음 GET 하나를 붙잡습니다. GET은 받은 시점의 목록으로
/// 답하므로, 붙잡힌 GET은 그 뒤의 변경을 모르는 늦은 응답이 됩니다.
final class ScheduleTestServer extends Interceptor {
  /// [seed] 일정으로 시작합니다.
  new({List<Map<String, Object?>>? seed})
    : store = FakeScheduleStore(
        seed: seed ?? memberSchedules(),
        nowUtc: () => DateTime.utc(2026, 10, 13, 3),
      );

  /// 대역 일정 저장소.
  final FakeScheduleStore store;

  /// 연결 없음 흉내.
  bool offline = false;

  /// 시간 초과 흉내.
  bool timeout = false;

  final _getHolds = <Completer<void>>[];

  /// 다음 GET 하나의 응답을 돌려준 Completer가 끝날 때까지 붙잡습니다.
  Completer<void> holdNextGet() {
    final gate = Completer<void>();
    _getHolds.add(gate);
    return gate;
  }

  /// 일정 쓰기 응답을 붙잡는 문.
  Completer<void>? hold;

  /// 일정 만들기·고치기가 이 status의 problem으로 답합니다(null이면 정상).
  int? writeFailureStatus;

  /// `listDiaries`가 이 status의 problem으로 답합니다(null이면 [diaryDates]로 답함).
  int? diaryFailureStatus;

  /// `listDiaries`가 돌려줄 일기 날짜.
  List<String> diaryDates = const [];

  /// 서버에 닿은 요청 기록(메서드, 경로, 쿼리, 헤더, 본문).
  final requests = <RequestOptions>[];

  /// [method]·경로 접두 [pathPrefix]로 닿은 요청.
  List<RequestOptions> requestsOf(String method, String pathPrefix) => [
    for (final request in requests)
      if (request.method == method && request.path.startsWith(pathPrefix))
        request,
  ];

  /// 이 서버를 거치는 생성 클라이언트.
  DefaultApi client() {
    final dio = Dio(BaseOptions(baseUrl: 'http://schedule.test'));
    dio.interceptors.add(this);
    return DefaultApi(dio);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (offline || timeout) {
      handler.reject(
        offline
            ? DioException.connectionError(
                requestOptions: options,
                reason: '테스트 서버: 오프라인',
              )
            : DioException.receiveTimeout(
                timeout: const Duration(seconds: 20),
                requestOptions: options,
              ),
        true,
      );
      return;
    }
    requests.add(options);
    if (options.method == 'GET') {
      // 받은 시점의 목록으로 답을 정해 두고, 붙잡혔으면 풀릴 때 보냅니다.
      final answer = _tryAnswer(options);
      if (_getHolds.isNotEmpty) {
        await _getHolds.removeAt(0).future;
      }
      _send(options, handler, answer);
      return;
    }
    final gate = hold;
    if (gate != null) {
      await gate.future;
    }
    _send(options, handler, _tryAnswer(options));
  }

  Object _tryAnswer(RequestOptions options) {
    try {
      return _answer(options);
    } on FakeProblem catch (problem) {
      return problem;
    }
  }

  void _send(
    RequestOptions options,
    RequestInterceptorHandler handler,
    Object answer,
  ) {
    if (answer case (final int status, final Object? body)) {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: status,
          data: body,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/json'],
          }),
        ),
        true,
      );
      return;
    }
    final problem = answer as FakeProblem;
    handler.reject(
      DioException.badResponse(
        statusCode: problem.status,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: problem.status,
          data: {
            'type': 'about:blank',
            'title': problem.title,
            'status': problem.status,
            'code': problem.code,
            'traceId': 'test',
          },
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
        ),
      ),
      true,
    );
  }

  (int, Object?) _answer(RequestOptions options) {
    final query = options.queryParameters;
    final path = options.path;
    final writeFailure = writeFailureStatus;
    if (writeFailure != null &&
        (options.method == 'POST' || options.method == 'PATCH')) {
      throw FakeProblem(writeFailure, 'service.unavailable', 'Down', '실패');
    }
    if (path == '/v1/diaries') {
      final failure = diaryFailureStatus;
      if (failure != null) {
        throw FakeProblem(failure, 'service.unavailable', 'Down', '실패');
      }
      return (
        200,
        {
          'items': [
            for (final date in diaryDates)
              {'date': date, 'excerpt': '일기', 'featuredTags': <Object>[]},
          ],
        },
      );
    }
    if (path == '/v1/schedules') {
      return switch (options.method) {
        'GET' => (200, store.list(from: query['from'], to: query['to'])),
        _ => (
          201,
          store.create(
            options.data,
            idempotencyKey: options.headers['Idempotency-Key'] as String?,
          ),
        ),
      };
    }
    final id = path.substring('/v1/schedules/'.length);
    if (options.method == 'DELETE') {
      store.delete(id);
      return (204, null);
    }
    return (200, store.update(id, options.data));
  }
}
