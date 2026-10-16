import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// `listDiaries` fixture 본문(`DiaryList` JSON)의 `items`를 [from]~[to](둘 다 포함,
/// 각각 선택)로 거르고 계약대로 날짜 내림차순으로 돌려줍니다. 다른 필드는 그대로입니다.
///
/// 쿼리 매개변수로는 fixture 파일을 나눌 수 없어, 한 fixture를 범위마다 걸러 씁니다.
Map<String, Object?> filterDiaryList(
  Map<String, Object?> body, {
  required Object? from,
  required Object? to,
}) {
  final start = parseDateParameter('from', from, required: false);
  final end = parseDateParameter('to', to, required: false);
  checkDateOrder(start, end);
  final rawItems = body['items'];
  final items = [
    for (final item in rawItems is List<Object?> ? rawItems : const <Object?>[])
      if (item is Map<String, Object?> && _inRange(item, start, end)) item,
  ]..sort((a, b) => (b['date']! as String).compareTo(a['date']! as String));
  return {...body, 'items': items};
}

bool _inRange(
  Map<String, Object?> item,
  CalendarDate? start,
  CalendarDate? end,
) {
  final date = CalendarDate.parse(item['date']! as String);
  return (start == null || date.compareTo(start) >= 0) &&
      (end == null || date.compareTo(end) <= 0);
}
