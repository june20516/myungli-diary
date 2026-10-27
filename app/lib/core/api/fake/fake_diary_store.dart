import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/fake/fake_diary_list.dart';
import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:uuid/uuid.dart';

/// 대역 서버의 일기 저장소. 대역 인스턴스 안에만 있어 앱을 다시 켜면 처음 상태로 돌아갑니다.
///
/// 계약(`listDiaries`·`createDiary`·`getDiary`·`updateDiary`·`deleteDiary`)의
/// 규칙을 따릅니다.
/// * 일기는 id(uuid)로 찾습니다. 하루에 여러 편이고, 살아 있는 일기는 10편까지입니다.
///   넘으면 422 `diary.day_full`입니다.
/// * 만들기는 201이고, 같은 `Idempotency-Key`로 같은 본문이 다시 오면 처음 응답을 돌려줍니다.
///   고치기는 본문만 바꿉니다(태그·`rulesetVersion`·가이드 질문·`createdAt`은 처음 값).
/// * 날짜 기록(태그·가이드 질문·`rulesetVersion`·`dayKind`)은 그날 첫 편을 쓸 때 `daily`
///   (시나리오의 `getDaily` 본문)에서 가져와 같은 날 일기에 똑같이 붙습니다. 대역은 날짜마다
///   다른 일진을 계산하지 않습니다. fixture에서 시작한 날짜 기록에 `dayKind`가 없으면 1.1.0 전에
///   만든 기록처럼 끝까지 비워 둡니다(S116).
/// * 지운 일기는 목록·보기에서 사라집니다(404 `diary.not_found`). 되살리기는 대역이 구현하지
///   않습니다(앱이 부르지 않음).
/// * 오늘(`today`) 이후 날짜는 422 `diary.future_date`입니다.
/// * 목록은 날짜 내림차순, 같은 날은 작성 순입니다. 요약의 `excerpt`는 본문 앞 100자,
///   `featuredTags`는 대표 태그이고, `tag`는 전체 태그(`tags.all`)로 거릅니다.
final class FakeDiaryStore {
  /// [summaries](`DiarySummary` JSON, `id`·`createdAt` 포함)와 [diaries](`Diary`
  /// JSON)로 시작합니다. 같은 id면 전체 일기가 앞섭니다. 요약만 있는 일기는 `excerpt`를
  /// 본문으로 씁니다.
  new({
    required List<Map<String, Object?>> summaries,
    required List<Map<String, Object?>> diaries,
    required Map<String, Object?>? daily,
    required this._today,
    required this._nowUtc,
  }) : _daily = daily ?? const {} {
    // 전체 일기를 먼저 넣어, 그 날짜의 날짜 기록(태그 전체·가이드 질문)이 요약 기반 기록보다
    // 앞서게 합니다.
    diaries.forEach(_seed);
    for (final summary in summaries) {
      if (_diaries.containsKey(summary['id'])) {
        continue;
      }
      final featured = summary['featuredTags'] as List<Object?>? ?? const [];
      final createdAt = summary['createdAt']! as String;
      _seed({
        'id': summary['id'],
        'date': summary['date'],
        'body': summary['excerpt'],
        'tags': {
          'featured': featured,
          'all': [for (final tag in featured) (tag! as Map)['key']],
        },
        'rulesetVersion': _daily['rulesetVersion'] ?? 'fake',
        'createdAt': createdAt,
        'updatedAt': createdAt,
      });
    }
  }

  /// 본문 글자 수 범위(계약 `DiaryInput.body`).
  static const int minBodyLength = 1;

  /// 본문 글자 수 상한(계약 `DiaryInput.body`).
  static const int maxBodyLength = 10000;

  /// 목록 요약 `excerpt`의 글자 수(계약 `DiarySummary.excerpt`).
  static const int excerptLength = 100;

  /// 하루에 살아 있을 수 있는 일기 수(D83 ②).
  static const int dayLimit = 10;

  final Map<String, Object?> _daily;
  final CalendarDate _today;
  final DateTime Function() _nowUtc;
  final _uuid = const Uuid();

  /// id → 살아 있는 일기(`Diary` JSON).
  final _diaries = <String, Map<String, Object?>>{};

  /// 날짜(`YYYY-MM-DD`) → 날짜 기록(`tags`·`guideQuestion`·`rulesetVersion`·
  /// `dayKind`). 그날 일기를 다 지워도 남습니다.
  final _dayRecords = <String, Map<String, Object?>>{};

  /// `Idempotency-Key` → (요청 본문, 처음 응답).
  final _idempotent =
      <String, ({Map<String, Object?> input, Map<String, Object?> response})>{};

  /// 지금까지 내준 가장 늦은 `createdAt`. 새 일기가 같은 날 앞선 일기 뒤에 서도록 합니다.
  DateTime _latestCreatedAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  /// `getDiary`: [id] 일기(`Diary` JSON).
  Map<String, Object?> get(String id) => Map.of(_find(id));

  /// `createDiary`: [body](`DiaryInput` JSON)의 날짜에 새 일기를 씁니다.
  Map<String, Object?> create(Object? body, {String? idempotencyKey}) {
    final input = decodeJsonObject(body);
    if (idempotencyKey != null) {
      // 서버는 24시간 응답을 재생합니다. 그 사이 일기를 지워도 같은 응답이라 대역도 같습니다.
      final previous = _idempotent[idempotencyKey];
      if (previous != null) {
        if (!mapEquals(previous.input, input)) {
          throw const FakeProblem(
            422,
            'idempotency.mismatch',
            'Idempotency key reused',
            '같은 Idempotency-Key에 다른 본문이 왔습니다.',
          );
        }
        return Map.of(previous.response);
      }
    }
    final text = _bodyOf(input);
    final date = _dateOf(input);
    if (date.compareTo(_today) > 0) {
      throw const FakeProblem(
        422,
        'diary.future_date',
        'Future date',
        '오늘 이후 날짜의 일기는 쓸 수 없습니다.',
      );
    }
    final key = date.toIso();
    final liveCount = _diaries.values.where((d) => d['date'] == key).length;
    if (liveCount >= dayLimit) {
      throw const FakeProblem(
        422,
        'diary.day_full',
        'Day full',
        '그 날짜의 일기가 이미 $dayLimit편입니다.',
        errors: [(field: '/date', code: 'diary.day_full')],
      );
    }
    final now = _nextCreatedAt().toIso8601String();
    final diary = <String, Object?>{
      'id': _uuid.v4(),
      'date': key,
      'body': text,
      ..._dayRecords.putIfAbsent(key, _newDayRecord),
      'createdAt': now,
      'updatedAt': now,
    };
    _diaries[diary['id']! as String] = diary;
    if (idempotencyKey != null) {
      _idempotent[idempotencyKey] = (input: input, response: diary);
    }
    return Map.of(diary);
  }

  /// `updateDiary`: [id] 일기의 본문을 [body](`DiaryBodyInput` JSON)로 바꿉니다.
  Map<String, Object?> update(String id, Object? body) {
    final current = _find(id);
    final updated = {
      ...current,
      'body': _bodyOf(decodeJsonObject(body)),
      'updatedAt': _timestamp(),
    };
    _diaries[id] = updated;
    return Map.of(updated);
  }

  /// `deleteDiary`: [id] 일기를 지웁니다.
  void delete(String id) {
    _find(id);
    _diaries.remove(id);
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
            // 날짜 기록의 값입니다. 기록에 없으면(1.2.0 전 날짜) 생략합니다.
            if (_dayRecords[diary['date']]?['dayKind'] != null)
              'dayKind': _dayRecords[diary['date']]!['dayKind'],
            'id': diary['id'],
            'date': diary['date'],
            'createdAt': diary['createdAt'],
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

  Map<String, Object?> _find(String id) {
    final diary = _diaries[id];
    if (diary == null) {
      throw FakeProblem(
        404,
        'diary.not_found',
        'Diary not found',
        '일기가 없습니다: $id',
      );
    }
    return diary;
  }

  /// 일기를 [diary]로 넣고, 그 날짜의 날짜 기록이 없으면 이 일기에서 만듭니다(처음 상태).
  void _seed(Map<String, Object?> diary) {
    final stored = Map.of(diary);
    _diaries[stored['id']! as String] = stored;
    _dayRecords.putIfAbsent(stored['date']! as String, () => _recordOf(stored));
    final createdAt = DateTime.parse(stored['createdAt']! as String);
    if (createdAt.isAfter(_latestCreatedAt)) {
      _latestCreatedAt = createdAt;
    }
  }

  static Map<String, Object?> _recordOf(Map<String, Object?> diary) => {
    'tags': diary['tags'],
    'rulesetVersion': diary['rulesetVersion'],
    if (diary['guideQuestion'] != null) 'guideQuestion': diary['guideQuestion'],
    if (diary['dayKind'] != null) 'dayKind': diary['dayKind'],
  };

  /// 그날 첫 편의 날짜 기록: `daily`의 태그·가이드 질문·`rulesetVersion`·`dayKind`.
  Map<String, Object?> _newDayRecord() {
    final guide = _daily['guide'];
    return {
      if (guide is Map<String, Object?> && guide['text'] != null)
        'guideQuestion': guide['text'],
      'tags':
          _daily['tags'] ?? const {'featured': <Object?>[], 'all': <Object?>[]},
      'rulesetVersion': _daily['rulesetVersion'] ?? 'fake',
      if (_daily['dayKind'] != null) 'dayKind': _daily['dayKind'],
    };
  }

  /// 이미 내준 `createdAt`보다 늦은 지금 시각. 대역 시계는 멈춰 있을 수 있어 1ms씩 밀어
  /// 작성 순이 목록 순서가 되게 합니다.
  DateTime _nextCreatedAt() {
    final now = _nowUtc();
    final next = now.isAfter(_latestCreatedAt)
        ? now
        : _latestCreatedAt.add(const Duration(milliseconds: 1));
    return _latestCreatedAt = next;
  }

  /// `DiaryInput.date`. 없거나 문자열이 아니거나 없는 날짜면 400입니다.
  static CalendarDate _dateOf(Map<String, Object?> input) {
    final date = input['date'];
    if (!input.containsKey('date')) {
      throw FakeProblem.invalid('/date', 'required', 'date가 없습니다.');
    }
    if (date is! String) {
      throw FakeProblem.invalid('/date', 'type', 'date는 문자열이어야 합니다.');
    }
    try {
      return CalendarDate.parse(date);
    } on FormatException {
      throw FakeProblem.invalid('/date', 'format', '없는 날짜입니다: $date');
    }
  }

  /// `DiaryInput.body`. 없거나 문자열이 아니거나 길이 범위 밖이면 400입니다.
  static String _bodyOf(Map<String, Object?> input) {
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
