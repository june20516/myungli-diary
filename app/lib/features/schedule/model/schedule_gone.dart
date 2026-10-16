/// 고치거나 지우려던 일정이 server에 이미 없습니다(`updateSchedule`·`deleteSchedule` 404, A41).
///
/// 계약에 일정 404 code가 없어 status로만 판단합니다. 화면은 목록을 다시 받은 뒤 닫고
/// 일반 오류 toast를 띄웁니다.
final class ScheduleGone implements Exception {
  /// 이미 없는 일정.
  const new();

  @override
  String toString() => 'ScheduleGone';
}
