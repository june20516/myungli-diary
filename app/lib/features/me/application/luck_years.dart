import 'package:myungli_diary/core/api/gen/model/daeun.dart';

/// [thisYear](기기 오늘의 연도)가 속한 대운의 자리(`Daeun.periods` 순서)입니다.
///
/// 대운 i는 `periods[i].startYear`(계약 값, server S94)부터 다음 대운 시작 전까지입니다. 첫 대운 전이면
/// null입니다. 기기 오늘 기준이라 해가 바뀌면 화면이 새 [thisYear]로 다시 셉니다(Review Focus 4).
int? currentDaeunIndex(Daeun daeun, {required int thisYear}) {
  int? current;
  for (final (index, period) in daeun.periods.indexed) {
    if (period.startYear <= thisYear) current = index;
  }
  return current;
}
