import 'package:myungli_diary/core/clock/calendar_date.dart';

/// problem 응답의 `errors[]` 한 줄(계약 `FieldError`).
///
/// `field`는 본문 안이면 JSON Pointer(`/date`), 쿼리 매개변수면 그 이름(`from`)입니다.
/// `code`는 `request.invalid`에서 위반한 JSON Schema keyword,
/// `request.inconsistent`에서 `required_by_status`·`forbidden_by_status`입니다.
typedef FakeFieldError = ({String field, String code});

/// 대역 서버가 계약의 오류 응답(problem)으로 답할 때 던집니다.
final class FakeProblem implements Exception {
  /// [status]와 [code]의 problem 응답을 만듭니다.
  const new(
    this.status,
    this.code,
    this.title,
    this.detail, {
    this.errors = const [],
  });

  /// 400 `request.invalid`: [field]가 [keyword]를 어겼습니다.
  new invalid(String field, String keyword, String detail)
    : this(
        400,
        'request.invalid',
        'Invalid request',
        detail,
        errors: [(field: field, code: keyword)],
      );

  /// 422 `request.inconsistent`: [field]가 상태 짝([rule])을 어겼습니다.
  new inconsistent(String field, String rule, String detail)
    : this(
        422,
        'request.inconsistent',
        'Inconsistent request',
        detail,
        errors: [(field: field, code: rule)],
      );

  /// HTTP status.
  final int status;

  /// `Problem.code`.
  final String code;

  /// 개발자용 영어 제목.
  final String title;

  /// 설명.
  final String detail;

  /// `errors[]`. 비어 있으면 응답에 넣지 않습니다.
  final List<FakeFieldError> errors;

  @override
  String toString() => 'FakeProblem($status $code: $detail)';
}

/// 날짜 쿼리 매개변수 [name]의 값 [value]를 읽습니다.
///
/// [required]인데 없으면 `required`, 없는 날짜거나 형식이 틀리면 `format`의 400입니다.
/// 없고 선택이면 null입니다.
CalendarDate? parseDateParameter(
  String name,
  Object? value, {
  required bool required,
}) {
  if (value == null) {
    if (required) {
      throw FakeProblem.invalid(name, 'required', '$name가 없습니다.');
    }
    return null;
  }
  try {
    return CalendarDate.parse('$value');
  } on FormatException {
    throw FakeProblem.invalid(
      name,
      'format',
      '$name는 있는 YYYY-MM-DD 날짜여야 합니다: $value',
    );
  }
}

/// [from]~[to](둘 다 포함) 범위 검사: [to]가 [from]보다 앞서면 400입니다.
///
/// 역순 범위는 계약에 전용 code가 없어 `request.invalid`의 `minimum`으로 둡니다.
void checkDateOrder(CalendarDate? from, CalendarDate? to) {
  if (from != null && to != null && to.compareTo(from) < 0) {
    throw FakeProblem.invalid('to', 'minimum', 'to가 from보다 앞섭니다.');
  }
}
