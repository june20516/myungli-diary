// IA 계약(docs/ia/screens.json)의 화면 모델. 생성기(tool/gen_ia.dart)도 쓰므로
// Flutter와 dart:ui를 import하지 않는 순수 Dart로 둡니다.

/// 화면이 열리는 방식.
enum IaPresentation {
  /// 전체 화면 페이지.
  page('page'),

  /// 바텀시트 Half.
  halfSheet('half-sheet'),

  /// 바텀시트 Full.
  fullSheet('full-sheet'),

  /// 시스템 화면(알림 등).
  system('system');

  new(this.json);

  /// screens.json에 적힌 값.
  final String json;

  /// screens.json 값에서 찾습니다. 없으면 [ArgumentError].
  static IaPresentation fromJson(String value) => values.firstWhere(
    (presentation) => presentation.json == value,
    orElse: () => throw ArgumentError.value(value, 'presentation'),
  );
}

/// 화면을 볼 수 있는 인증 상태.
enum IaAuth {
  /// 로그인 전만.
  guest,

  /// 로그인 후만.
  member,

  /// 둘 다.
  any;

  /// screens.json 값에서 찾습니다. 없으면 [ArgumentError].
  static IaAuth fromJson(String value) => values.firstWhere(
    (auth) => auth.name == value,
    orElse: () => throw ArgumentError.value(value, 'auth'),
  );
}

/// 화면에서 다른 화면으로 나가는 길.
class IaExit {
  /// 나가는 길을 만듭니다.
  const new({required this.to, required this.trigger});

  /// 도착 화면 id.
  final String to;

  /// 나가는 조건 설명.
  final String trigger;
}

/// IA 화면 한 개.
class IaScreen {
  /// 화면을 만듭니다.
  const new({
    required this.id,
    required this.tab,
    required this.presentation,
    required this.auth,
    required this.states,
    required this.exits,
    required this.components,
  });

  /// 화면 id. 예: `onboard-call`.
  final String id;

  /// 속한 탭 id. 탭에 속하지 않으면 null.
  final String? tab;

  /// 열리는 방식.
  final IaPresentation presentation;

  /// 볼 수 있는 인증 상태.
  final IaAuth auth;

  /// 상태 id 목록.
  final List<String> states;

  /// 나가는 길 목록.
  final List<IaExit> exits;

  /// 쓰는 컴포넌트 id 목록.
  final List<String> components;
}

/// id를 lowerCamelCase로 바꿉니다. 점(.)과 하이픈(-)이 단어 경계입니다.
///
/// 예: `evidence-sheet.lock.cta` → `evidenceSheetLockCta`.
/// 생성기와 ARB 키 규칙이 같이 씁니다.
String iaKey(String id) {
  final words = id.split(RegExp('[.-]')).where((word) => word.isNotEmpty);
  final buffer = StringBuffer();
  for (final word in words) {
    if (buffer.isEmpty) {
      buffer.write(word);
    } else {
      buffer
        ..write(word[0].toUpperCase())
        ..write(word.substring(1));
    }
  }
  return buffer.toString();
}
