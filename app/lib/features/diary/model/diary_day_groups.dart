import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';

/// [diaries]에서 날짜가 같은 이웃을 한 묶음으로 만듭니다(목록 날짜 묶음, A72).
///
/// server 순서(날짜 내림차순, 같은 날 작성 순)를 바꾸지 않고, 묶음 안 순서도 받은 그대로입니다.
/// 떨어져 있는 같은 날짜는 묶지 않습니다. 받은 쪽들을 이어 붙인 목록을 넘기면 두 쪽에 나뉜
/// 같은 날도 한 묶음이 됩니다.
List<List<DiarySummary>> groupDiariesByDate(List<DiarySummary> diaries) {
  final groups = <List<DiarySummary>>[];
  for (final diary in diaries) {
    if (groups.isNotEmpty && groups.last.first.date == diary.date) {
      groups.last.add(diary);
    } else {
      groups.add([diary]);
    }
  }
  return groups;
}
