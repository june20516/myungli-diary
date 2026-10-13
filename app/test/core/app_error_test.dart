import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';

DioException _dioError(
  DioExceptionType type, {
  Response<Object?>? response,
  Object? error,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/v1/test'),
    type: type,
    response: response,
    error: error,
  );
}

DioException _badResponse(
  int status,
  Object? data, {
  String contentType = 'application/problem+json',
}) {
  final requestOptions = RequestOptions(path: '/v1/test');
  return _dioError(
    DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: requestOptions,
      statusCode: status,
      data: data,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: [contentType],
      }),
    ),
  );
}

void main() {
  group('appErrorFrom', () {
    test('connectionError는 OfflineError', () {
      final error = appErrorFrom(_dioError(DioExceptionType.connectionError));
      expect(error, isA<OfflineError>());
    });

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
    ]) {
      test('$type은 TimeoutError', () {
        expect(appErrorFrom(_dioError(type)), isA<TimeoutError>());
      });
    }

    test('422 problem 본문은 ProblemError로 파싱', () {
      final error = appErrorFrom(
        _badResponse(422, {
          'type': 'https://api.myungli.app/problems/request.inconsistent',
          'title': 'Inconsistent request',
          'status': 422,
          'code': 'request.inconsistent',
          'traceId': 't1',
          'errors': [
            {'field': '/birth/time/value', 'code': 'required_by_status'},
          ],
        }),
      );

      expect(error, isA<ProblemError>());
      final problem = error as ProblemError;
      expect(problem.code, 'request.inconsistent');
      expect(problem.status, 422);
      expect(problem.traceId, 't1');
      expect(problem.fieldErrors.single.pointer, '/birth/time/value');
      expect(problem.fieldErrors.single.code, 'required_by_status');
    });

    test('traceId와 errors가 없어도 ProblemError', () {
      final error = appErrorFrom(
        _badResponse(500, {'status': 500, 'code': 'internal'}),
      );

      expect(error, isA<ProblemError>());
      final problem = error as ProblemError;
      expect(problem.traceId, isEmpty);
      expect(problem.fieldErrors, isEmpty);
    });

    test('Content-Type의 charset 파라미터와 대소문자를 허용', () {
      for (final contentType in [
        'application/problem+json; charset=utf-8',
        'Application/Problem+JSON',
        '  application/problem+json ',
      ]) {
        final error = appErrorFrom(
          _badResponse(400, {
            'status': 400,
            'code': 'request.invalid',
          }, contentType: contentType),
        );
        expect(error, isA<ProblemError>(), reason: contentType);
      }
    });

    test('application/problem+json-seq는 problem이 아니다', () {
      final error = appErrorFrom(
        _badResponse(400, {
          'status': 400,
          'code': 'request.invalid',
        }, contentType: 'application/problem+json-seq'),
      );
      expect(error, isA<UnexpectedError>());
    });

    test('JSON 텍스트(String) 본문도 파싱', () {
      final error = appErrorFrom(
        _badResponse(
          422,
          '{"status":422,"code":"date.invalid","traceId":"t2",'
          '"errors":[{"field":"/a","code":"x"}]}',
        ),
      );

      expect(error, isA<ProblemError>());
      final problem = error as ProblemError;
      expect(problem.code, 'date.invalid');
      expect(problem.traceId, 't2');
      expect(problem.fieldErrors.single.pointer, '/a');
    });

    test('JSON이 아니거나 객체가 아닌 String 본문은 UnexpectedError', () {
      expect(
        appErrorFrom(_badResponse(400, 'not json')),
        isA<UnexpectedError>(),
      );
      expect(appErrorFrom(_badResponse(400, '[1]')), isA<UnexpectedError>());
    });

    test('status는 본문 값이 아니라 HTTP status를 따른다', () {
      final error = appErrorFrom(
        _badResponse(503, {'status': 400, 'code': 'x'}),
      );
      expect((error as ProblemError).status, 503);
    });

    test('JSON이 아닌 502는 UnexpectedError', () {
      final error = appErrorFrom(
        _badResponse(502, '<html>Bad Gateway</html>', contentType: 'text/html'),
      );
      expect(error, isA<UnexpectedError>());
    });

    test('Content-Type이 problem+json이 아니면 UnexpectedError', () {
      final error = appErrorFrom(
        _badResponse(400, {
          'status': 400,
          'code': 'request.invalid',
        }, contentType: 'application/json'),
      );
      expect(error, isA<UnexpectedError>());
    });

    test('code·status가 없는 problem 본문은 UnexpectedError', () {
      final error = appErrorFrom(_badResponse(400, {'status': 400}));
      expect(error, isA<UnexpectedError>());
    });

    test('cancel은 UnexpectedError이고 원인을 보존', () {
      final cancelled = _dioError(DioExceptionType.cancel);
      final error = appErrorFrom(cancelled);

      expect(error, isA<UnexpectedError>());
      expect((error as UnexpectedError).cause, same(cancelled));
    });

    test('badCertificate와 unknown은 UnexpectedError', () {
      expect(
        appErrorFrom(_dioError(DioExceptionType.badCertificate)),
        isA<UnexpectedError>(),
      );
      expect(
        appErrorFrom(_dioError(DioExceptionType.unknown)),
        isA<UnexpectedError>(),
      );
    });
  });
}
