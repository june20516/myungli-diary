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

    test('JSON이 아닌 502는 UnexpectedError', () {
      final error = appErrorFrom(
        _badResponse(502, '<html>Bad Gateway</html>', contentType: 'text/html'),
      );
      expect(error, isA<UnexpectedError>());
    });

    test('Content-Type이 problem+json이 아니면 UnexpectedError', () {
      final error = appErrorFrom(
        _badResponse(
          400,
          {'status': 400, 'code': 'request.invalid'},
          contentType: 'application/json',
        ),
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
