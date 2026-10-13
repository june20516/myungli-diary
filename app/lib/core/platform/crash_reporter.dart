import 'package:myungli_diary/core/ia/gen/ia.g.dart';

final Set<String> _screenIdSet = {for (final screen in iaScreens) screen.id};

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// IA 화면 id이면 그대로, 아니면 null. release에서도 거릅니다(D64 ②).
String? sanitizeBreadcrumb(String screenId) =>
    _screenIdSet.contains(screenId) ? screenId : null;

/// UUID 형식이면 그대로, 아니면 null. 계정 id 밖의 값은 보내지 않습니다(D64 ②).
String? sanitizeAccountId(String? accountId) =>
    accountId != null && _uuidPattern.hasMatch(accountId) ? accountId : null;

/// 비정상 종료 보고(Crashlytics).
///
/// 일기 본문, 출생 정보, 호칭은 어떤 경로로도 넘기지 않습니다(D64 ②).
/// 자유 문자열 custom key는 두지 않습니다. 구현은 [sanitizeBreadcrumb]·
/// [sanitizeAccountId]를 거쳐야 합니다.
abstract interface class CrashReporter {
  /// 오류를 보고합니다.
  void record(Object error, StackTrace stack);

  /// 사용자 식별값을 정합니다. UUID가 아니면 무시하고, null이면 지웁니다.
  void setUser(String? accountId);

  /// 화면 이동 흔적을 남깁니다. IA 화면 id가 아니면 남기지 않습니다.
  void breadcrumb(String screenId);
}
