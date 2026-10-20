import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/fake/fake_diary_store.dart';
import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

final _now = DateTime.utc(2026, 10, 13, 3);

Map<String, Object?> _summary(
  String date,
  String excerpt, [
  List<Map<String, Object?>> featured = const [],
]) => {'date': date, 'excerpt': excerpt, 'featuredTags': featured};

const _daily = <String, Object?>{
  'rulesetVersion': 'r1',
  'tags': {
    'featured': [
      {'key': 'cheoneul_gwiin', 'polarity': 'good'},
    ],
    'all': ['cheoneul_gwiin', 'yongsin_day'],
  },
  'guide': {
    'text': {
      'segments': [
        {'text': '오늘 눈길이 갔던 장면을 적어 볼까요?'},
      ],
    },
  },
};

FakeDiaryStore _store({
  List<Map<String, Object?>> summaries = const [],
  List<Map<String, Object?>> diaries = const [],
}) => FakeDiaryStore(
  summaries: summaries,
  diaries: diaries,
  daily: _daily,
  today: CalendarDate(2026, 10, 13),
  nowUtc: () => _now,
);

Matcher _problem(int status, String code) => isA<FakeProblem>()
    .having((p) => p.status, 'status', status)
    .having((p) => p.code, 'code', code);

void main() {
  test('처음 목록은 fixture 요약 그대로이고 날짜 내림차순입니다', () {
    final store = _store(
      summaries: [
        _summary('2026-10-05', '정리'),
        _summary('2026-10-12', '점심', [
          {'key': 'cheoneul_gwiin', 'polarity': 'good'},
        ]),
      ],
    );
    final list = store.list();
    final items = list['items']! as List<Object?>;
    expect(
      [for (final item in items) (item! as Map)['date']],
      ['2026-10-12', '2026-10-05'],
    );
    expect((items.first! as Map)['featuredTags'], [
      {'key': 'cheoneul_gwiin', 'polarity': 'good'},
    ]);
    expect(store.get('2026-10-12')['body'], '점심');
  });

  test('전체 일기 fixture가 있으면 요약보다 앞섭니다', () {
    final store = _store(
      summaries: [_summary('2026-10-13', '앞부분')],
      diaries: [
        {
          'date': '2026-10-13',
          'body': '전체 본문',
          'tags': {'featured': <Object>[], 'all': <Object>[]},
          'rulesetVersion': 'r1',
          'createdAt': '2026-10-13T12:10:00Z',
          'updatedAt': '2026-10-13T12:10:00Z',
        },
      ],
    );
    expect(store.get('2026-10-13')['body'], '전체 본문');
  });

  test('새 날짜 put은 201이고 그날 daily의 태그·질문·rulesetVersion을 기록합니다', () {
    final store = _store();
    final result = store.put('2026-10-11', {'body': '새 일기'});
    expect(result.status, 201);
    expect(result.diary['body'], '새 일기');
    expect(result.diary['tags'], _daily['tags']);
    expect(result.diary['guideQuestion'], (_daily['guide']! as Map)['text']);
    expect(result.diary['rulesetVersion'], 'r1');
    expect(result.diary['createdAt'], '2026-10-13T03:00:00.000Z');
    expect(store.get('2026-10-11')['body'], '새 일기');
    final items = store.list()['items']! as List<Object?>;
    expect((items.single! as Map)['excerpt'], '새 일기');
  });

  test('같은 날 put은 200이고 본문만 바뀝니다(태그·질문은 처음 값)', () {
    final store = _store(
      summaries: [
        _summary('2026-10-12', '처음', [
          {'key': 'clash', 'polarity': 'bad'},
        ]),
      ],
    );
    final before = store.get('2026-10-12');
    final result = store.put('2026-10-12', {'body': '고친 본문'});
    expect(result.status, 200);
    expect(result.diary['body'], '고친 본문');
    expect(result.diary['tags'], before['tags']);
    expect(result.diary['createdAt'], before['createdAt']);
  });

  test('목록 excerpt는 본문 앞 100자입니다', () {
    final store = _store()..put('2026-10-10', {'body': '가' * 150});
    final items = store.list()['items']! as List<Object?>;
    expect((items.single! as Map)['excerpt'], '가' * 100);
  });

  test('오늘 이후 날짜는 422 diary.future_date입니다', () {
    expect(
      () => _store().put('2026-10-14', {'body': '내일'}),
      throwsA(_problem(422, 'diary.future_date')),
    );
  });

  test('빈 본문·10000자 초과·형식이 틀린 날짜는 400 request.invalid입니다', () {
    final store = _store();
    expect(
      () => store.put('2026-10-10', {'body': ''}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.put('2026-10-10', {'body': '가' * 10001}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.put('2026-10-10', <String, Object?>{}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.put('2026-10-10', 'not json'),
      throwsA(_problem(400, 'request.malformed')),
    );
    expect(store.put('2026-10-10', '{"body":"문자열 본문"}').status, 201);
    expect(
      () => store.get('2026-02-30'),
      throwsA(_problem(400, 'request.invalid')),
    );
  });

  test('delete 뒤 get은 404이고, 없는 날 delete도 404 diary.not_found입니다', () {
    final store = _store(summaries: [_summary('2026-10-12', '점심')])
      ..delete('2026-10-12');
    expect(
      () => store.get('2026-10-12'),
      throwsA(_problem(404, 'diary.not_found')),
    );
    expect(
      () => store.delete('2026-10-12'),
      throwsA(_problem(404, 'diary.not_found')),
    );
    expect(store.list()['items'], isEmpty);
  });

  test('tag는 전체 태그(all)로 거르고, 범위·쪽 넘김은 계약대로입니다', () {
    final store = _store(
      summaries: [
        for (var day = 1; day <= 5; day++) _summary('2026-10-0$day', '$day'),
      ],
    )..put('2026-10-06', {'body': '태그 있음'});
    final tagged = store.list(tag: 'yongsin_day')['items']! as List<Object?>;
    expect([for (final item in tagged) (item! as Map)['date']], ['2026-10-06']);

    final first = store.list(from: '2026-10-02', to: '2026-10-05', limit: '2');
    expect((first['items']! as List<Object?>).length, 2);
    final second = store.list(
      from: '2026-10-02',
      to: '2026-10-05',
      limit: '2',
      cursor: first['nextCursor'],
    );
    expect(
      [
        for (final item in second['items']! as List<Object?>)
          (item! as Map)['date'],
      ],
      ['2026-10-03', '2026-10-02'],
    );
    expect(second.containsKey('nextCursor'), isFalse);
  });
}
