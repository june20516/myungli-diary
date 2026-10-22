import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/features/diary/model/diary_write_entry.dart';

void main() {
  test('0편은 first, 1~9편은 more, 10편 이상은 full입니다', () {
    expect(diaryWriteEntryOf(0), DiaryWriteEntry.first);
    expect(diaryWriteEntryOf(1), DiaryWriteEntry.more);
    expect(diaryWriteEntryOf(9), DiaryWriteEntry.more);
    expect(diaryWriteEntryOf(10), DiaryWriteEntry.full);
    expect(diaryWriteEntryOf(11), DiaryWriteEntry.full);
  });
}
