import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/ia/ia_ids.dart';

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final RegExp _problemCodePattern = RegExp(r'^[a-z0-9_.]{1,64}$');

/// UUID 형식이면 그대로, 아니면 null. 계정 id 밖의 값은 보내지 않습니다(D64 ②).
String? sanitizeAccountId(String? accountId) =>
    accountId != null && _uuidPattern.hasMatch(accountId) ? accountId : null;

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
    _ => CrashSummary._(errorType: error.runtimeType.toString()),
  };

  /// 오류 타입 이름.
  final String errorType;

  /// `ProblemError.code`. 없으면 null.
  final String? code;

  /// `ProblemError.status`. 없으면 null.
  final int? status;
}

/// 비정상 종료 보고(Crashlytics).
///
/// 일기 본문, 출생 정보, 호칭은 어떤 경로로도 넘기지 않습니다(D64 ②).
/// 자유 문자열 custom key는 두지 않습니다. 구현은 [sanitizeScreenId]·
/// [sanitizeAccountId]를 거쳐야 합니다.
abstract interface class CrashReporter {
  /// 정제된 오류 요약을 보고합니다.
  void record(CrashSummary summary, StackTrace stack);

  /// 사용자 식별값을 정합니다. UUID가 아니면 무시하고, null이면 지웁니다.
  void setUser(String? accountId);

  /// 화면 이동 흔적을 남깁니다. IA 화면 id가 아니면 남기지 않습니다.
  void breadcrumb(String screenId);
}
