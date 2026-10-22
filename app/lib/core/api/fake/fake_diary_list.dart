import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 계약 `listDiaries`의 `limit` 기본값·범위.
const int _defaultLimit = 30;
const int _minLimit = 1;
const int _maxLimit = 100;

/// 대역이 내주는 `nextCursor`의 앞머리. 뒤는 다음 쪽이 시작하는 위치(0부터)입니다.
const String _cursorPrefix = 'fake-offset-';

/// `listDiaries` fixture 본문(`DiaryList` JSON)을 요청 매개변수대로 걸러 한 쪽을 돌려줍니다.
///
/// 1. `items`를 [from]~[to](둘 다 포함, 각각 선택)와 [tag]로 거르고 계약대로 날짜
///    내림차순, 같은 날은 작성 순(`createdAt` 오름차순, 같으면 `id` 오름차순)으로 둡니다.
///    [tag]는 그 태그가 붙은 일기만입니다. 목록 항목에는 대표 태그
///    (`featuredTags`)만 있으므로 대역은 대표 태그로만 거릅니다.
/// 2. [cursor] 위치부터 [limit]개(기본 30, 1~100)를 담고, 뒤에 더 있으면 `nextCursor`를
///    붙입니다. 마지막 쪽에는 `nextCursor`가 없습니다.
///
/// `limit`이 정수가 아니거나 범위 밖이면 400 `request.invalid`(`type`·`minimum`·`maximum`)
/// 입니다. 대역이 내준 값이 아닌 `cursor`는 계약에 code가 없어 400 `request.invalid`의
/// `format`으로 둡니다. 쿼리 매개변수로는 fixture 파일을 나눌 수 없어, 한 fixture를 요청마다
/// 걸러 씁니다. 다른 필드는 그대로입니다.
Map<String, Object?> filterDiaryList(
  Map<String, Object?> body, {
  required Object? from,
  required Object? to,
  Object? tag,
  Object? cursor,
  Object? limit,
}) {
  final start = parseDateParameter('from', from, required: false);
  final end = parseDateParameter('to', to, required: false);
  checkDateOrder(start, end);
  final pageSize = _parseLimit(limit);
  final offset = _parseCursor(cursor);
  final tagKey = tag?.toString();
  final rawItems = body['items'];
  final items = [
    for (final item in rawItems is List<Object?> ? rawItems : const <Object?>[])
      if (item is Map<String, Object?> &&
          _inRange(item, start, end) &&
          (tagKey == null || _hasTag(item, tagKey)))
        item,
  ]..sort(_compareItems);
  final pageEnd = offset + pageSize;
  final page = items.skip(offset).take(pageSize).toList();
  final rest = {...body}..remove('nextCursor');
  return {
    ...rest,
    'items': page,
    if (pageEnd < items.length) 'nextCursor': '$_cursorPrefix$pageEnd',
  };
}

/// 계약 목록 순서: 날짜 내림차순 → `createdAt` 오름차순 → `id` 오름차순.
int _compareItems(Map<String, Object?> a, Map<String, Object?> b) {
  String field(Map<String, Object?> item, String name) {
    final value = item[name];
    if (value is! String) {
      throw StateError('listDiaries fixture 항목에 $name이 없거나 문자열이 아닙니다: $item');
    }
    return value;
  }

  final byDate = field(b, 'date').compareTo(field(a, 'date'));
  if (byDate != 0) {
    return byDate;
  }
  // 문자열이 아니라 시각으로 견줍니다(`...:00Z`와 `...:00.001Z`).
  final byCreatedAt = DateTime.parse(field(a, 'createdAt'))
      .compareTo(DateTime.parse(field(b, 'createdAt')));
  return byCreatedAt != 0
      ? byCreatedAt
      : field(a, 'id').compareTo(field(b, 'id'));
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

bool _hasTag(Map<String, Object?> item, String tagKey) {
  final tags = item['featuredTags'];
  return tags is List<Object?> &&
      tags.any((tag) => tag is Map<String, Object?> && tag['key'] == tagKey);
}

/// `limit`을 읽습니다. 없으면 기본값입니다.
int _parseLimit(Object? value) {
  if (value == null) {
    return _defaultLimit;
  }
  final limit = value is int ? value : int.tryParse('$value');
  if (limit == null) {
    throw FakeProblem.invalid('limit', 'type', 'limit는 정수여야 합니다: $value');
  }
  if (limit < _minLimit) {
    throw FakeProblem.invalid('limit', 'minimum', 'limit는 $_minLimit 이상입니다.');
  }
  if (limit > _maxLimit) {
    throw FakeProblem.invalid('limit', 'maximum', 'limit는 $_maxLimit 이하입니다.');
  }
  return limit;
}

/// `cursor`를 다음 쪽 시작 위치로 읽습니다. 없으면 0입니다.
int _parseCursor(Object? value) {
  if (value == null) {
    return 0;
  }
  final text = '$value';
  final offset = text.startsWith(_cursorPrefix)
      ? int.tryParse(text.substring(_cursorPrefix.length))
      : null;
  if (offset == null || offset < 0) {
    throw FakeProblem.invalid('cursor', 'format', '대역이 준 cursor가 아닙니다: $text');
  }
  return offset;
}
