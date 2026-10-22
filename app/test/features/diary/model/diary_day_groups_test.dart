import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/features/diary/model/diary_day_groups.dart';

DiarySummary _diary(String id, String date) => DiarySummary(
  id: id,
  date: date,
  createdAt: DateTime.utc(2026, 10, 1, 9),
  excerpt: id,
  featuredTags: const [],
);

List<List<String>> _ids(List<List<DiarySummary>> groups) => [
  for (final group in groups) [for (final diary in group) diary.id],
];

void main() {
  test('같은 날 이웃만 묶는다', () {
    final groups = groupDiariesByDate([
      _diary('a', '2026-10-12'),
      _diary('b', '2026-10-12'),
      _diary('c', '2026-10-11'),
      _diary('d', '2026-10-10'),
      _diary('e', '2026-10-10'),
    ]);
    expect(_ids(groups), [
      ['a', 'b'],
      ['c'],
      ['d', 'e'],
    ]);
  });

  test('떨어져 있는 같은 날짜는 이웃이 아니므로 묶지 않는다', () {
    final groups = groupDiariesByDate([
      _diary('a', '2026-10-12'),
      _diary('b', '2026-10-11'),
      _diary('c', '2026-10-12'),
    ]);
    expect(_ids(groups), [
      ['a'],
      ['b'],
      ['c'],
    ]);
  });

  test('순서를 바꾸지 않는다', () {
    // 같은 날 안에서는 받은(작성) 순서 그대로, 묶음 순서도 받은 순서 그대로입니다.
    final groups = groupDiariesByDate([
      _diary('z', '2026-10-12'),
      _diary('a', '2026-10-12'),
      _diary('m', '2026-10-12'),
      _diary('b', '2026-10-09'),
    ]);
    expect(_ids(groups), [
      ['z', 'a', 'm'],
      ['b'],
    ]);
  });

  test('빈 목록은 빈 목록', () {
    expect(groupDiariesByDate(const []), isEmpty);
  });

  test('한 날짜가 두 쪽에 나뉘어도 이어 붙인 뒤 한 묶음', () {
    final firstPage = [_diary('a', '2026-10-12'), _diary('b', '2026-10-11')];
    final nextPage = [_diary('c', '2026-10-11'), _diary('d', '2026-10-10')];
    expect(_ids(groupDiariesByDate(firstPage)), [
      ['a'],
      ['b'],
    ]);
    expect(_ids(groupDiariesByDate([...firstPage, ...nextPage])), [
      ['a'],
      ['b', 'c'],
      ['d'],
    ]);
  });
}
