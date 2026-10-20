import 'package:myungli_diary/core/api/fake/fake_diary_list.dart';
import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 대역 서버의 일기 저장소. 대역 인스턴스 안에만 있어 앱을 다시 켜면 처음 상태로 돌아갑니다.
///
/// 계약(`listDiaries`·`getDiary`·`putDiary`·`deleteDiary`)의 규칙을 따릅니다.
/// * 하루 1편입니다. 처음 쓰면 201, 고치면 200이고, 고칠 때는 본문만 바꿉니다(태그·
///   `rulesetVersion`·가이드 질문·`createdAt`은 처음 값).
/// * 처음 쓸 때 태그·가이드 질문·`rulesetVersion`은 `daily`(시나리오의 `getDaily` 본문)에서
///   가져옵니다. 대역은 날짜마다 다른 일진을 계산하지 않습니다.
/// * 오늘(`today`) 이후 날짜는 422 `diary.future_date`, 없는 일기는 404
///   `diary.not_found`입니다.
/// * 목록 요약의 `excerpt`는 본문 앞 100자, `featuredTags`는 대표 태그입니다. `tag`는 전체
///   태그(`tags.all`)로 거릅니다.
final class FakeDiaryStore {
  /// [summaries](`DiarySummary` JSON)와 [diaries](`Diary` JSON)로 시작합니다. 같은 날짜면
  /// 전체 일기가 앞섭니다. 요약만 있는 날은 `excerpt`를 본문으로 씁니다.
  new({
    required List<Map<String, Object?>> summaries,
    required List<Map<String, Object?>> diaries,
    required Map<String, Object?>? daily,
    required this._today,
    required this._nowUtc,
  }) : _daily = daily ?? const {} {
    final seededAt = _timestamp();
    for (final summary in summaries) {
      final date = summary['date']! as String;
      final featured = summary['featuredTags'] as List<Object?>? ?? const [];
      _diaries[date] = {
        'date': date,
        'body': summary['excerpt'],
        'tags': {
          'featured': featured,
          'all': [for (final tag in featured) (tag! as Map)['key']],
        },
        'rulesetVersion': _daily['rulesetVersion'] ?? 'fake',
        'createdAt': seededAt,
        'updatedAt': seededAt,
      };
    }
    for (final diary in diaries) {
      _diaries[diary['date']! as String] = Map.of(diary);
    }
  }

  /// 본문 글자 수 범위(계약 `DiaryInput.body`).
  static const int minBodyLength = 1;

  /// 본문 글자 수 상한(계약 `DiaryInput.body`).
  static const int maxBodyLength = 10000;

  /// 목록 요약 `excerpt`의 글자 수(계약 `DiarySummary.excerpt`).
  static const int excerptLength = 100;

  final Map<String, Object?> _daily;
  final CalendarDate _today;
  final DateTime Function() _nowUtc;

  /// 날짜(`YYYY-MM-DD`) → 일기(`Diary` JSON).
  final _diaries = <String, Map<String, Object?>>{};

  /// `getDiary`: [date] 일기(`Diary` JSON).
  Map<String, Object?> get(String date) => Map.of(_find(_parseDate(date)));

  /// `putDiary`: [date]에 [body](`DiaryInput` JSON)를 쓰거나 고칩니다.
  ({int status, Map<String, Object?> diary}) put(String date, Object? body) {
    final day = _parseDate(date);
    final text = _bodyOf(body);
    if (day.compareTo(_today) > 0) {
      throw const FakeProblem(
        422,
        'diary.future_date',
        'Future date',
        '오늘 이후 날짜의 일기는 쓸 수 없습니다.',
      );
    }
    final key = day.toIso();
    final now = _timestamp();
    final existing = _diaries[key];
    if (existing != null) {
      final updated = {...existing, 'body': text, 'updatedAt': now};
      _diaries[key] = updated;
      return (status: 200, diary: Map.of(updated));
    }
    final guide = _daily['guide'];
    final created = <String, Object?>{
      'date': key,
      'body': text,
      if (guide is Map<String, Object?> && guide['text'] != null)
        'guideQuestion': guide['text'],
      'tags':
          _daily['tags'] ?? const {'featured': <Object?>[], 'all': <Object?>[]},
      'rulesetVersion': _daily['rulesetVersion'] ?? 'fake',
      'createdAt': now,
      'updatedAt': now,
    };
    _diaries[key] = created;
    return (status: 201, diary: Map.of(created));
  }

  /// `deleteDiary`: [date] 일기를 지웁니다.
  void delete(String date) {
    final day = _parseDate(date);
    _find(day);
    _diaries.remove(day.toIso());
  }

  /// `listDiaries`: 요약 목록 한 쪽(`DiaryList` JSON). 범위·쪽 넘김은 [filterDiaryList]입니다.
  Map<String, Object?> list({
    Object? from,
    Object? to,
    Object? tag,
    Object? cursor,
    Object? limit,
  }) {
    final tagKey = tag?.toString();
    final items = [
      for (final diary in _diaries.values)
        if (tagKey == null || _allTags(diary).contains(tagKey))
          {
            'date': diary['date'],
            'excerpt': _excerptOf(diary['body']! as String),
            'featuredTags':
                (diary['tags']! as Map<String, Object?>)['featured'] ??
                const <Object?>[],
          },
    ];
    return filterDiaryList(
      {'items': items},
      from: from,
      to: to,
      cursor: cursor,
      limit: limit,
    );
  }

  Map<String, Object?> _find(CalendarDate date) {
    final diary = _diaries[date.toIso()];
    if (diary == null) {
      throw FakeProblem(
        404,
        'diary.not_found',
        'Diary not found',
        '일기가 없습니다: ${date.toIso()}',
      );
    }
    return diary;
  }

  /// 경로의 날짜. 없는 날짜거나 형식이 틀리면 400입니다.
  static CalendarDate _parseDate(String date) =>
      parseDateParameter('date', date, required: true)!;

  /// `DiaryInput.body`. 없거나 문자열이 아니거나 길이 범위 밖이면 400입니다.
  static String _bodyOf(Object? request) {
    final input = decodeJsonObject(request);
    final body = input['body'];
    if (!input.containsKey('body')) {
      throw FakeProblem.invalid('/body', 'required', 'body가 없습니다.');
    }
    if (body is! String) {
      throw FakeProblem.invalid('/body', 'type', 'body는 문자열이어야 합니다.');
    }
    final length = body.runes.length;
    if (length < minBodyLength) {
      throw FakeProblem.invalid('/body', 'minLength', 'body가 비어 있습니다.');
    }
    if (length > maxBodyLength) {
      throw FakeProblem.invalid(
        '/body',
        'maxLength',
        'body는 $maxBodyLength자 이하여야 합니다.',
      );
    }
    return body;
  }

  static String _excerptOf(String body) {
    final runes = body.runes;
    return runes.length <= excerptLength
        ? body
        : String.fromCharCodes(runes.take(excerptLength));
  }

  static Iterable<Object?> _allTags(Map<String, Object?> diary) =>
      (diary['tags']! as Map<String, Object?>)['all'] as List<Object?>? ??
      const [];

  String _timestamp() => _nowUtc().toIso8601String();
}
