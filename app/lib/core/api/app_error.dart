import 'dart:convert';

import 'package:dio/dio.dart';

/// 모든 통신 실패를 하나로 모은 타입입니다.
///
/// 사용자 문구는 `errorMessage`(error_messages.dart)가 만듭니다.
sealed class AppError implements Exception {
  /// 하위 타입이 상속하는 기본 생성자입니다.
  const new();
}

/// 네트워크에 연결할 수 없습니다.
final class OfflineError extends AppError {
  /// 연결 오류.
  const new();
}

/// 연결·송신·수신 시간이 초과됐습니다.
final class TimeoutError extends AppError {
  /// 시간 초과.
  const new();
}

/// server가 보낸 RFC 9457 problem+json 오류입니다.
final class ProblemError extends AppError {
  /// problem 응답을 담습니다.
  const new({
    required this.code,
    required this.status,
    required this.fieldErrors,
    required this.traceId,
  });

  /// 오류 코드. 사용자 문구를 고르는 기준입니다.
  final String code;

  /// HTTP status.
  final int status;

  /// 필드별 위반 목록. 없으면 빈 목록입니다.
  final List<FieldProblem> fieldErrors;

  /// 문의 시 server 로그를 찾는 값. 계약상 필수지만 없으면 빈 문자열입니다.
  final String traceId;
}

/// problem 본문의 `errors[]` 한 항목입니다.
final class FieldProblem {
  /// 위반 위치와 위반 code를 담습니다.
  const new(this.pointer, this.code);

  /// 위반 위치(JSON Pointer 또는 parameter 이름).
  final String pointer;

  /// 위반 code(예 `required_by_status`).
  final String code;
}

/// 그 밖의 예상하지 못한 실패입니다(취소, 인증서 오류, problem이 아닌 응답 등).
final class UnexpectedError extends AppError {
  /// 원인 객체를 담습니다.
  const new(this.cause);

  /// 원인(대개 [DioException]).
  final Object cause;
}

const _problemContentType = 'application/problem+json';

/// [DioException]을 [AppError]로 바꿉니다.
AppError appErrorFrom(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
      return const OfflineError();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutError();
    case DioExceptionType.badResponse:
      return _parseProblem(e.response) ?? UnexpectedError(e);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnexpectedError(e);
  }
}

ProblemError? _parseProblem(Response<Object?>? response) {
  if (response == null) {
    return null;
  }
  final mediaType = response.headers
      .value(Headers.contentTypeHeader)
      ?.split(';')
      .first
      .trim()
      .toLowerCase();
  if (mediaType != _problemContentType) {
    return null;
  }
  final body = _decodeBody(response.data);
  if (body is! Map<String, Object?>) {
    return null;
  }
  final code = body['code'];
  final status = body['status'];
  if (code is! String || status is! int) {
    return null;
  }
  final traceId = body['traceId'];
  return ProblemError(
    code: code,
    // 문구 대역은 실제 전송 상태 기준이라 HTTP status를 우선합니다.
    status: response.statusCode ?? status,
    fieldErrors: _parseFieldErrors(body['errors']),
    traceId: traceId is String ? traceId : '',
  );
}

/// `responseType: plain` 등으로 JSON 텍스트가 오면 해석합니다.
Object? _decodeBody(Object? data) {
  if (data is! String) {
    return data;
  }
  try {
    return jsonDecode(data);
  } on FormatException {
    return null;
  }
}

List<FieldProblem> _parseFieldErrors(Object? raw) {
  if (raw is! List<Object?>) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map<String, Object?> &&
          item['field'] is String &&
          item['code'] is String)
        FieldProblem(item['field']! as String, item['code']! as String),
  ];
}
