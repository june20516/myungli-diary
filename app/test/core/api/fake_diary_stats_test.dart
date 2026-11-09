import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/fake/fake_diary_stats.dart';
import 'package:myungli_diary/core/api/gen/model/diary_stats.dart';

DiarySummaryJson _entry(
  String id,
  String date, {
  String? dayKind,
  List<(String, String)> tags = const [],
}) => {
  'id': id,
  'date': date,
  'createdAt': '${date}T09:00:00Z',
  'excerpt': '본문',
  'featuredTags': [
    for (final (key, polarity) in tags) {'key': key, 'polarity': polarity},
  ],
  'dayKind': ?dayKind,
};

Map<String, int> _dayKinds(Map<String, Object> stats) => {
  for (final item in stats['dayKinds']! as List<Object?>)
    (item! as Map)['dayKind']! as String: (item as Map)['days']! as int,
};

void main() {
  group('FakeDiaryStats.compute', () {
    final entries = [
      _entry(
        'a1',
        '2026-10-12',
        dayKind: 'yongsin_day',
        tags: [('cheoneul_gwiin', 'good')],
      ),
      _entry(
        'a2',
        '2026-10-12',
        dayKind: 'yongsin_day',
        tags: [('cheoneul_gwiin', 'good')],
      ),
      _entry(
        'b1',
        '2026-10-08',
        dayKind: 'gisin_day',
        tags: [('clash', 'bad')],
      ),
      _entry('c1', '2026-10-05'),
    ];

    test('편수는 편 단위, 그날 성격은 날짜 단위로 셉니다', () {
      final stats = FakeDiaryStats.compute(entries);

      expect(stats['entryCount'], 4);
      final kinds = _dayKinds(stats);
      expect(kinds['yongsin_day'], 1, reason: '같은 날 두 편은 한 번');
      expect(kinds['gisin_day'], 1);
    });

    test('dayKind 네 값이 모두 있고, dayKind 없는 날은 어디에도 세지 않습니다', () {
      final kinds = _dayKinds(FakeDiaryStats.compute(entries));

      expect(kinds.keys.toSet(), {
        'gwiin_day',
        'yongsin_day',
        'gisin_day',
        'ordinary_day',
      });
      expect(kinds['gwiin_day'], 0);
      expect(kinds['ordinary_day'], 0);
      expect(kinds.values.fold<int>(0, (a, b) => a + b), 2);
    });

    test('태그는 날짜 수 내림차순, 같으면 키 오름차순이고 최대 3개입니다', () {
      final stats = FakeDiaryStats.compute([
        _entry(
          '1',
          '2026-10-01',
          tags: [('zeta', 'good'), ('beta', 'neutral')],
        ),
        _entry('2', '2026-10-02', tags: [('zeta', 'good'), ('alpha', 'bad')]),
        _entry('3', '2026-10-03', tags: [('gamma', 'bad')]),
        _entry('4', '2026-10-03', tags: [('gamma', 'bad')]),
      ]);

      final tags = stats['topTags']! as List<Object?>;
      expect(
        [for (final tag in tags) ((tag! as Map)['tag']! as Map)['key']],
        ['zeta', 'alpha', 'beta'],
      );
      expect((tags.first! as Map)['days'], 2);
    });

    test('polarity는 그 태그가 붙은 가장 최근 날짜의 값입니다', () {
      final stats = FakeDiaryStats.compute([
        _entry('1', '2026-10-01', tags: [('x', 'good')]),
        _entry('2', '2026-10-09', tags: [('x', 'bad')]),
      ]);

      final tag =
          ((stats['topTags']! as List<Object?>).single! as Map)['tag']! as Map;
      expect(tag['polarity'], 'bad');
    });

    test('일기가 없으면 편수 0, 막대 넷 모두 0, 태그 없음이고 DiaryStats로 읽힙니다', () {
      final stats = FakeDiaryStats.compute(const []);

      expect(stats['entryCount'], 0);
      expect(_dayKinds(stats).values, [0, 0, 0, 0]);
      expect(stats['topTags'], isEmpty);
      expect(() => DiaryStats.fromJson(stats), returnsNormally);
    });
  });
}
