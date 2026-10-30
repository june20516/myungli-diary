import 'package:myungli_diary/core/api/app_error.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final RegExp _problemCodePattern = RegExp(r'^[a-z0-9_.]{1,64}$');

/// UUID 형식이면 그대로, 아니면 null. 계정 id 밖의 값은 보내지 않습니다(D64 ②).
String? sanitizeAccountId(String? accountId) =>
    accountId != null && _uuidPattern.hasMatch(accountId) ? accountId : null;

/// server가 보낸 계약 값이 app 사전(glossary)에 없습니다. 화면은 그 값을 건너뛰고, 사전과
/// 계약이 어긋났음을 알도록 이 오류를 요약해 보고합니다.
final class MissingDictionaryEntry implements Exception {
  /// 사전에 없는 용어 id(`<범주>.<값>`, 예 `tag.hwagae`).
  const new(this.termId);

  /// 사전에 없는 용어 id. 계약 enum 값이라 개인 정보가 아닙니다.
  final String termId;
}

/// 보고해도 되는 오류 요약. 원본 오류는 넘기지 않습니다(D64 ②).
///
/// `toString()`·`UnexpectedError.cause`·`DioException`의 요청·응답 본문은
/// 일기 본문이나 출생 정보를 품을 수 있어 담지 않습니다.
final class CrashSummary {
  const new _({required this.errorType, this.code, this.status});

  /// [error]에서 안전한 값(타입 이름, problem code·status)만 뽑습니다.
  factory from(Object error) => switch (error) {
    ProblemError(:final code, :final status) => CrashSummary._(
      errorType: 'ProblemError',
      // 형식이 이상한 code는 사용자 데이터를 실을 수 있어 버립니다.
      code: _problemCodePattern.hasMatch(code) ? code : null,
      status: status,
    ),
    MissingDictionaryEntry(:final termId) => CrashSummary._(
      errorType: 'MissingDictionaryEntry',
      // 계약 값 형식(소문자·숫자·`_`·`.`)이 아니면 사용자 데이터일 수 있어 버립니다.
      code: _problemCodePattern.hasMatch(termId) ? termId : null,
    ),
    _ => CrashSummary._(errorType: error.runtimeType.toString()),
  };

  /// 오류 타입 이름.
  final String errorType;

  /// `ProblemError.code` 또는 [MissingDictionaryEntry]의 용어 id. 없으면 null.
  final String? code;

  /// `ProblemError.status`. 없으면 null.
  final int? status;

  /// 보고 화면에 보이는 문자열. 세 값만 담고 없는 값은 뺍니다.
  @override
  String toString() {
    final fields = [
      'errorType: $errorType',
      if (code != null) 'code: $code',
      if (status != null) 'status: $status',
    ];
    return 'CrashSummary(${fields.join(', ')})';
  }
}

/// [action]을 실행해 결과를 돌려줍니다. 화면 동작 controller의 예상 밖 오류 가드입니다.
///
/// [AppError](이미 분류된 실패)는 그대로 던집니다. 그 밖의 오류(플랫폼 SDK 등)는 [reporter]에
/// [CrashSummary](타입 이름 등 안전한 값만, D64)로 남긴 뒤 [UnexpectedError]로 감싸 던져, 화면이
/// 일반 오류로 알릴 수 있게 합니다.
Future<T> guardUnexpected<T>(
  CrashReporter reporter,
  Future<T> Function() action,
) async {
  try {
    return await action();
  } on AppError {
    rethrow;
  } on Object catch (error, stack) {
    reporter.record(CrashSummary.from(error), stack);
    throw UnexpectedError(error);
  }
}

/// 조용히 넘기는 실패의 기록 규칙입니다. [AppError](오프라인, 503 등 이미 분류된 실패)는
/// 기록 없이 삼키고, 예상 밖 오류만 [reporter]에 [CrashSummary]로 남깁니다(D64).
///
/// [UnexpectedError]는 감싼 원인(`cause`)을 풀어 그 타입으로 기록합니다.
void recordUnlessAppError(
  CrashReporter reporter,
  Object error,
  StackTrace stack,
) {
  final unexpected = switch (error) {
    UnexpectedError(:final cause) => cause,
    AppError() => null,
    _ => error,
  };
  if (unexpected != null) {
    reporter.record(CrashSummary.from(unexpected), stack);
  }
}

/// 비정상 종료 보고(Crashlytics).
///
/// 일기 본문, 출생 정보, 호칭은 어떤 경로로도 넘기지 않습니다(D64 ②).
/// 자유 문자열 custom key는 두지 않습니다. 구현은 `sanitizeScreenId`(ia_ids.dart)·
/// [sanitizeAccountId]를 거쳐야 합니다.
abstract interface class CrashReporter {
  /// 정제된 오류 요약을 보고합니다.
  void record(CrashSummary summary, StackTrace stack);

  /// 사용자 식별값을 정합니다. UUID가 아니면 무시하고, null이면 지웁니다.
  void setUser(String? accountId);

  /// 화면 이동 흔적을 남깁니다. IA 화면 id가 아니면 남기지 않습니다.
  void breadcrumb(String screenId);
}
