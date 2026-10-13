/// E2E·흐름 테스트가 덮는 IA 경로·상태·결정을 선언합니다.
///
/// 테스트(`test/flows`, `patrol_test`)에서만 import합니다. 값은 `tool/ia_coverage.dart`가
/// 소스의 리터럴로 읽으므로 **문자열 리터럴만** 씁니다(변수·보간 금지).
///
/// 형식 예:
/// ```dart
/// covers(const Covers(exits: ['launch>welcome'], decisions: ['D50']));
/// ```
final class Covers {
  /// 덮는 대상을 선언합니다.
  ///
  /// * [exits]: IA 경로 `'<출발 화면>><도착 화면>'`. 예: `'launch>welcome'`
  /// * [states]: 화면 상태 `'<화면>:<상태>'`. 예: `'launch:offline'`
  /// * [decisions]: 결정 id. 예: `'D50'`
  const new({
    this.exits = const [],
    this.states = const [],
    this.decisions = const [],
  });

  /// 덮는 IA 경로.
  final List<String> exits;

  /// 덮는 화면 상태.
  final List<String> states;

  /// 덮는 결정 id.
  final List<String> decisions;
}

/// 테스트 본문에서 [declared]를 선언합니다. 실행 시에는 아무 일도 하지 않고,
/// 커버리지 도구가 소스에서 읽는 표지입니다.
void covers(Covers declared) {}
