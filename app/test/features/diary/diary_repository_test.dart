import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/diary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';

final _date = CalendarDate(2026, 10, 13);
const _id = '7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a005';

Map<String, Object> _diaryJson() => {
  'id': _id,
  'date': '2026-10-13',
  'body': '일기',
  'tags': {'featured': <Object>[], 'all': <Object>[]},
  'rulesetVersion': 'r1',
  'createdAt': '2026-10-13T12:00:00Z',
  'updatedAt': '2026-10-13T12:00:00Z',
};

Map<String, Object> _summaryJson(String id, String date) => {
  'id': id,
  'date': date,
  'createdAt':
      '$date'
      'T12:00:00Z',
  'excerpt': '일기',
  'featuredTags': <Object>[],
};

/// 요청을 남기고 [respond]가 정한 (status, 본문)으로 답합니다.
final class _Server extends Interceptor {
  new(this.respond);

  final (int, Object?) Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    final (status, data) = respond(options);
    final response = Response<Object?>(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: [
          if (status >= 400) 'application/problem+json' else 'application/json',
        ],
      }),
      data: data,
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

(int, Object?) _problem(int status, String code) => (
  status,
  <String, Object>{
    'type': 'about:blank',
    'title': 'problem',
    'status': status,
    'code': code,
  },
);

/// 일기를 물으면 Dio 밖의 예외(프로그래밍 오류)를 던지는 클라이언트.
final class _BrokenApi extends DefaultApi {
  new() : super(Dio());

  @override
  Future<Response<Diary>> getDiary({
    required String id,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async => throw StateError('버그');
}

DiaryRepository _repository(_Server server) => DiaryRepository(
  DefaultApi(
    Dio(BaseOptions(baseUrl: 'https://example.test'))..interceptors.add(server),
  ),
);

void main() {
  group('DiaryRepository.create', () {
    test('POST /v1/diaries에 date·body와 Idempotency-Key를 보냅니다', () async {
      final server = _Server((_) => (201, _diaryJson()));
      final diary = await _repository(server)
          .create(_date, '일기', idempotencyKey: 'key-1');
      expect(diary.id, _id);
      final request = server.requests.single;
      expect((request.method, request.path), ('POST', '/v1/diaries'));
      expect(jsonDecode(request.data as String), {
        'date': '2026-10-13',
        'body': '일기',
      });
      expect(request.headers['Idempotency-Key'], 'key-1');
    });

    test('422 diary.day_full은 ProblemError입니다', () async {
      final server = _Server((_) => _problem(422, 'diary.day_full'));
      await expectLater(
        _repository(server).create(_date, '일기', idempotencyKey: 'key-1'),
        throwsA(
          isA<ProblemError>().having((e) => e.code, 'code', 'diary.day_full'),
        ),
      );
    });

    test('본문을 읽지 못하면 UnexpectedError입니다', () async {
      final server = _Server((_) => (201, <String, Object>{'date': 13}));
      await expectLater(
        _repository(server).create(_date, '일기', idempotencyKey: 'key-1'),
        throwsA(isA<UnexpectedError>()),
      );
    });
  });

  group('DiaryRepository.update', () {
    test('PUT /v1/diaries/x에 body만 보냅니다', () async {
      final server = _Server((_) => (200, _diaryJson()));
      await _repository(server).update('x', '고친 일기');
      final request = server.requests.single;
      expect((request.method, request.path), ('PUT', '/v1/diaries/x'));
      expect(jsonDecode(request.data as String), {'body': '고친 일기'});
    });
  });

  group('DiaryRepository.find', () {
    test('200이면 일기이고 그 id 경로를 묻습니다', () async {
      final server = _Server((_) => (200, _diaryJson()));
      final diary = await _repository(server).find(_id);
      expect(diary?.body, '일기');
      expect(server.requests.single.path, '/v1/diaries/$_id');
    });

    test('404면 null입니다', () async {
      final server = _Server((_) => _problem(404, 'diary.not_found'));
      expect(await _repository(server).find(_id), isNull);
    });

    test('server problem은 ProblemError입니다', () async {
      final server = _Server((_) => _problem(503, 'service.unavailable'));
      await expectLater(
        _repository(server).find(_id),
        throwsA(isA<ProblemError>()),
      );
    });

    test('Dio 밖의 예외는 바꾸지 않고 그대로 던집니다', () async {
      await expectLater(
        DiaryRepository(_BrokenApi()).find(_id),
        throwsA(isA<StateError>()),
      );
    });

    test('본문을 읽지 못하면 UnexpectedError입니다', () async {
      final server = _Server((_) => (200, <String, Object>{'date': 13}));
      await expectLater(
        _repository(server).find(_id),
        throwsA(isA<UnexpectedError>()),
      );
    });
  });

  group('DiaryRepository.delete', () {
    test('DELETE /v1/diaries/x를 보냅니다', () async {
      final server = _Server((_) => (204, null));
      await _repository(server).delete('x');
      final request = server.requests.single;
      expect((request.method, request.path), ('DELETE', '/v1/diaries/x'));
    });

    test('404는 ProblemError입니다', () async {
      final server = _Server((_) => _problem(404, 'diary.not_found'));
      await expectLater(
        _repository(server).delete('x'),
        throwsA(isA<ProblemError>()),
      );
    });
  });

  group('DiaryRepository.diariesOn', () {
    test('from=to=날짜, limit 100으로 묻고 server 순서 그대로 돌려줍니다', () async {
      final server = _Server(
        (_) => (
          200,
          {
            'items': [
              _summaryJson('b', '2026-10-13'),
              _summaryJson('a', '2026-10-13'),
            ],
          },
        ),
      );
      final items = await _repository(server).diariesOn(_date);
      expect(items.map((item) => item.id), ['b', 'a']);
      expect(server.requests.single.queryParameters, {
        'from': '2026-10-13',
        'to': '2026-10-13',
        'limit': 100,
      });
    });
  });

  group('DiaryRepository.datesIn', () {
    test('nextCursor가 없을 때까지 이어 받아 날짜를 합칩니다', () async {
      final server = _Server((options) {
        final first = options.queryParameters['cursor'] == null;
        return (
          200,
          {
            'items': [
              if (first)
                _summaryJson('a', '2026-10-13')
              else
                _summaryJson('b', '2026-10-12'),
            ],
            if (first) 'nextCursor': 'c1',
          },
        );
      });
      final dates = await _repository(server)
          .datesIn(CalendarDate(2026, 10, 1), CalendarDate(2026, 10, 31));
      expect(dates, {CalendarDate(2026, 10, 13), CalendarDate(2026, 10, 12)});
      expect(server.requests, hasLength(2));
      expect(server.requests.last.queryParameters['cursor'], 'c1');
    });
  });
}
