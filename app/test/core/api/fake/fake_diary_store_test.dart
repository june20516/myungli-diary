import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/fake/fake_diary_store.dart';
import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

final _now = DateTime.utc(2026, 10, 13, 3);

Map<String, Object?> _summary(
  String id,
  String date,
  String excerpt, [
  List<Map<String, Object?>> featured = const [],
]) => {
  'id': id,
  'date': date,
  'createdAt': '${date}T12:00:00Z',
  'excerpt': excerpt,
  'featuredTags': featured,
};

const _daily = <String, Object?>{
  'rulesetVersion': 'r1',
  'dayKind': 'yongsin_day',
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

List<Object?> _items(Map<String, Object?> list) =>
    list['items']! as List<Object?>;

List<Object?> _ids(Map<String, Object?> list) => [
  for (final item in _items(list)) (item! as Map)['id'],
];

void main() {
  test('처음 목록은 fixture 요약 그대로이고 날짜 내림차순입니다', () {
    final store = _store(
      summaries: [
        _summary('a', '2026-10-05', '정리'),
        _summary('b', '2026-10-12', '점심', [
          {'key': 'cheoneul_gwiin', 'polarity': 'good'},
        ]),
      ],
    );
    final items = _items(store.list());
    expect([for (final item in items) (item! as Map)['id']], ['b', 'a']);
    expect((items.first! as Map)['featuredTags'], [
      {'key': 'cheoneul_gwiin', 'polarity': 'good'},
    ]);
    expect(store.get('b')['body'], '점심');
  });

  test('전체 일기 fixture가 있으면 같은 id의 요약보다 앞섭니다', () {
    final store = _store(
      summaries: [_summary('a', '2026-10-13', '앞부분')],
      diaries: [
        {
          'id': 'a',
          'date': '2026-10-13',
          'body': '전체 본문',
          'tags': {'featured': <Object>[], 'all': <Object>[]},
          'rulesetVersion': 'r1',
          'createdAt': '2026-10-13T12:10:00Z',
          'updatedAt': '2026-10-13T12:10:00Z',
        },
      ],
    );
    expect(store.get('a')['body'], '전체 본문');
  });

  test('create는 id를 만들고 그날 daily의 태그·질문·rulesetVersion을 기록합니다', () {
    final store = _store();
    final diary = store.create({'date': '2026-10-11', 'body': '새 일기'});
    expect(diary['id'], isA<String>());
    expect(diary['body'], '새 일기');
    expect(diary['tags'], _daily['tags']);
    expect(diary['guideQuestion'], (_daily['guide']! as Map)['text']);
    expect(diary['rulesetVersion'], 'r1');
    expect(diary['dayKind'], 'yongsin_day');
    expect(diary['createdAt'], '2026-10-13T03:00:00.000Z');
    expect(store.get(diary['id']! as String)['body'], '새 일기');
    final items = _items(store.list());
    expect((items.single! as Map)['excerpt'], '새 일기');
  });

  test('같은 날 둘째 편은 첫 편의 날짜 기록을 쓰고 작성 순으로 나옵니다', () {
    final store = _store();
    final first = store.create({'date': '2026-10-11', 'body': '첫째'});
    final second = store.create({'date': '2026-10-11', 'body': '둘째'});
    expect(second['id'], isNot(first['id']));
    expect(second['tags'], first['tags']);
    expect(second['dayKind'], first['dayKind']);
    expect(_ids(store.list()), [first['id'], second['id']]);
  });

  test('그날 성격을 기록하기 전(1.1.0 전)에 쓴 날짜 기록은 dayKind가 없습니다', () {
    final store = _store(summaries: [_summary('a', '2026-10-12', '점심')]);
    expect(store.get('a').containsKey('dayKind'), isFalse);
    final later = store.create({'date': '2026-10-12', 'body': '저녁'});
    expect(later.containsKey('dayKind'), isFalse);
  });

  test('목록 요약에 날짜 기록의 dayKind가 붙고, 기록이 없는 날짜는 생략합니다 (D96)', () {
    final store = _store(summaries: [_summary('a', '2026-10-12', '점심')]);
    final created = store.create({'date': '2026-10-11', 'body': '새 일기'});
    final byId = {
      for (final item in _items(store.list()))
        (item! as Map)['id']: item as Map<String, Object?>,
    };
    expect(byId[created['id']]!['dayKind'], 'yongsin_day');
    expect(byId['a']!.containsKey('dayKind'), isFalse);
  });

  test('새 일기는 시계가 멈춰 있어도 fixture의 같은 날 일기 뒤에 섭니다', () {
    final store = _store(summaries: [_summary('a', '2026-10-13', '먼저')]);
    final created = store.create({'date': '2026-10-13', 'body': '나중'});
    expect(_ids(store.list()), ['a', created['id']]);
  });

  test('update는 본문만 바뀝니다(태그·질문·createdAt은 처음 값)', () {
    final store = _store(
      summaries: [
        _summary('a', '2026-10-12', '처음', [
          {'key': 'clash', 'polarity': 'bad'},
        ]),
      ],
    );
    final before = store.get('a');
    final after = store.update('a', {'body': '고친 본문'});
    expect(after['body'], '고친 본문');
    expect(after['tags'], before['tags']);
    expect(after['createdAt'], before['createdAt']);
    expect(
      () => store.update('nope', {'body': '없음'}),
      throwsA(_problem(404, 'diary.not_found')),
    );
  });

  test('목록 excerpt는 본문 앞 100자입니다', () {
    final store = _store()..create({'date': '2026-10-10', 'body': '가' * 150});
    expect((_items(store.list()).single! as Map)['excerpt'], '가' * 100);
  });

  test('오늘 이후 날짜는 422 diary.future_date입니다', () {
    expect(
      () => _store().create({'date': '2026-10-14', 'body': '내일'}),
      throwsA(_problem(422, 'diary.future_date')),
    );
  });

  test('열한 번째는 422 diary.day_full이고 지우면 다시 쓸 수 있습니다', () {
    final store = _store();
    final ids = [
      for (var n = 0; n < FakeDiaryStore.dayLimit; n++)
        store.create({'date': '2026-10-10', 'body': '$n'})['id']! as String,
    ];
    expect(
      () => store.create({'date': '2026-10-10', 'body': '넘침'}),
      throwsA(_problem(422, 'diary.day_full')),
    );
    store.delete(ids.first);
    expect(store.create({'date': '2026-10-10', 'body': '다시'}), isNotEmpty);
  });

  test('빈 본문·10000자 초과·없는 필드·형식이 틀린 날짜는 400입니다', () {
    final store = _store();
    expect(
      () => store.create({'date': '2026-10-10', 'body': ''}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.create({'date': '2026-10-10', 'body': '가' * 10001}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.create({'date': '2026-10-10'}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.create({'body': '날짜 없음'}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.create({'date': '2026-02-30', 'body': '없는 날'}),
      throwsA(_problem(400, 'request.invalid')),
    );
    expect(
      () => store.create('not json'),
      throwsA(_problem(400, 'request.malformed')),
    );
    expect(store.create('{"date":"2026-10-10","body":"문자열 본문"}'), isNotEmpty);
  });

  test('같은 Idempotency-Key는 같은 일기를, 다른 본문이면 422를 줍니다', () {
    final store = _store();
    final input = {'date': '2026-10-10', 'body': '일기'};
    final first = store.create(input, idempotencyKey: 'k');
    expect(store.create(input, idempotencyKey: 'k')['id'], first['id']);
    expect(_items(store.list()), hasLength(1));
    expect(
      () => store.create({...input, 'body': '다름'}, idempotencyKey: 'k'),
      throwsA(_problem(422, 'idempotency.mismatch')),
    );
  });

  test('delete 뒤 get은 404이고, 없는 id delete도 404 diary.not_found입니다', () {
    final store = _store(summaries: [_summary('a', '2026-10-12', '점심')])
      ..delete('a');
    expect(() => store.get('a'), throwsA(_problem(404, 'diary.not_found')));
    expect(() => store.delete('a'), throwsA(_problem(404, 'diary.not_found')));
    expect(_items(store.list()), isEmpty);
  });

  test('tag는 전체 태그(all)로 거르고, 범위·쪽 넘김은 계약대로입니다', () {
    final store = _store(
      summaries: [
        for (var day = 1; day <= 5; day++)
          _summary('d$day', '2026-10-0$day', '$day'),
      ],
    )..create({'date': '2026-10-06', 'body': '태그 있음'});
    final tagged = _items(store.list(tag: 'yongsin_day'));
    expect([for (final item in tagged) (item! as Map)['date']], ['2026-10-06']);

    final first = store.list(from: '2026-10-02', to: '2026-10-05', limit: '2');
    expect(_items(first), hasLength(2));
    final second = store.list(
      from: '2026-10-02',
      to: '2026-10-05',
      limit: '2',
      cursor: first['nextCursor'],
    );
    expect(_ids(second), ['d3', 'd2']);
    expect(second.containsKey('nextCursor'), isFalse);
  });
}
