/// 고치거나 지우려던 일정이 server에 이미 없습니다(`updateSchedule`·`deleteSchedule` 404, A41).
///
/// 404이면서 code가 `schedule.not_found`일 때만 이것입니다(draft.5, #219 ②). code가 다른
/// 404는 일반 오류입니다. 화면은 목록을 다시 받은 뒤 닫고 일반 오류 toast를 띄웁니다.
final class ScheduleGone implements Exception {
  /// 이미 없는 일정.
  const new();

  @override
  String toString() => 'ScheduleGone';
}
