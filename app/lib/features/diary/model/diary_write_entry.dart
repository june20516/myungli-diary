import 'package:myungli_diary/features/diary/data/diary_repository.dart';

/// 그날 일기를 쓰는 입구의 상태(D83 ②).
enum DiaryWriteEntry {
  /// 아직 한 편도 없음: 첫 일기 쓰기.
  first,

  /// 한 편 이상, 상한 아래: 한 편 더 쓰기.
  more,

  /// 상한([diaryDayLimit])에 닿음: 더 쓰지 못함.
  full,
}

/// 그날 일기가 [count]편일 때의 쓰기 입구 상태.
DiaryWriteEntry diaryWriteEntryOf(int count) {
  if (count >= diaryDayLimit) {
    return DiaryWriteEntry.full;
  }
  return count == 0 ? DiaryWriteEntry.first : DiaryWriteEntry.more;
}
