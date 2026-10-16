import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/direction.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

import '../../support/component_spec_json.dart';
import '../../support/daily_fixture.dart';

FocusSlot _slot(String start, String end) => FocusSlot.fromJson({
  'branch': 'sa',
  'pillar': {'stem': 'gi', 'branch': 'sa'},
  'start': start,
  'end': end,
  'huangdaoLucky': true,
  'score': 3,
  'reasons': ['yongsin'],
});

const _names = GlossaryNames({
  'color': {'wood': '초록'},
});

/// 비교 테스트가 쓰는 한국어 문구.
late AppLocalizations _l10n;

/// [daily]의 오늘 화면 값(서울 시간대).
TodayDisplay _display(Daily daily) =>
    todayDisplayOf(daily, _names, _l10n, 'Asia/Seoul');

void main() {
  setUpAll(ensureTimeZonesInitialized);
  setUpAll(() async {
    _l10n = await AppLocalizations.delegate.load(const Locale('ko'));
  });

  group('formatFocusRange', () {
    test('+09:00 응답을 Asia/Seoul 기준 HH:mm–HH:mm으로 씁니다', () {
      expect(
        formatFocusRange([
          _slot('2026-10-13T09:30:00+09:00', '2026-10-13T11:30:00+09:00'),
        ], 'Asia/Seoul'),
        '09:30–11:30',
      );
    });

    test('UTC로 바뀐 같은 순간도 Asia/Seoul 기준 같은 값입니다', () {
      expect(
        formatFocusRange([
          _slot('2026-10-13T00:30:00Z', '2026-10-13T02:30:00Z'),
        ], 'Asia/Seoul'),
        '09:30–11:30',
      );
    });

    test('두 칸이면 가운뎃점으로 잇습니다', () {
      expect(
        formatFocusRange([
          _slot('2026-10-13T09:30:00+09:00', '2026-10-13T11:30:00+09:00'),
          _slot('2026-10-13T13:30:00+09:00', '2026-10-13T15:30:00+09:00'),
        ], 'Asia/Seoul'),
        '09:30–11:30 · 13:30–15:30',
      );
    });

    test('America/New_York이면 그 시간대 값입니다', () {
      // 2026-10-13은 서머타임(UTC-4)이라 한국 09:30은 전날 20:30입니다.
      expect(
        formatFocusRange([
          _slot('2026-10-13T09:30:00+09:00', '2026-10-13T11:30:00+09:00'),
        ], 'America/New_York'),
        '20:30–22:30',
      );
    });

    test('칸이 없으면 빈 글자입니다', () {
      expect(formatFocusRange(const [], 'Asia/Seoul'), '');
    });

    test('명세 lucky-card time 값 형식(HH:mm–HH:mm, 이음 " · ")과 같습니다', () {
      final variants =
          loadSpecComponents()['lucky-card']!['variants']! as List<Object?>;
      final time = variants.cast<Map<String, Object?>>().singleWhere(
        (variant) => variant['id'] == 'time',
      );
      final value =
          (time['parts']! as Map<String, Object?>)['value']!
              as Map<String, Object?>;
      expect(value['clock'], '24h');
      expect(value['timeZone'], 'profile');
      String range(String start, String end) => (value['format']! as String)
          .replaceFirst('HH:mm', start)
          .replaceFirst('HH:mm', end);
      expect(
        formatFocusRange([
          _slot('2026-10-13T09:30:00+09:00', '2026-10-13T11:30:00+09:00'),
          _slot('2026-10-13T13:30:00+09:00', '2026-10-13T15:30:00+09:00'),
        ], 'Asia/Seoul'),
        [
          range('09:30', '11:30'),
          range('13:30', '15:30'),
        ].join(value['join']! as String),
      );
    });
  });

  group('luckyItemsOf', () {
    late AppLocalizations l10n;
    late Daily daily;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('ko'));
      daily = Daily.fromJson(memberDailyJson());
    });

    test('색은 glossary, 방향은 ARB, 숫자는 그대로, 시간은 프로필 시간대 범위입니다', () {
      final items = luckyItemsOf(daily, _names, l10n, 'Asia/Seoul');
      expect(items.map((i) => i.variant), [
        LuckyCardVariant.color,
        LuckyCardVariant.direction,
        LuckyCardVariant.number,
        LuckyCardVariant.time,
      ]);
      expect(items.map((i) => i.value), [
        '초록',
        l10n.direction8E,
        '3',
        '09:30–11:30',
      ]);
      expect(items.map((i) => i.name), [
        l10n.todayLuckyColorName,
        l10n.todayLuckyDirectionName,
        l10n.todayLuckyNumberName,
        l10n.todayLuckyTimeName,
      ]);
      expect(items.first.element, FiveElement.wood);
      expect(items.first.explain, daily.cards.color.text.text);
      expect(items.last.explain, daily.cards.focusTime.text.text);
    });

    test('glossary에 색 이름이 없으면 값 id를 그대로 씁니다', () {
      final items = luckyItemsOf(
        daily,
        const GlossaryNames({}),
        l10n,
        'Asia/Seoul',
      );
      expect(items.first.value, 'wood');
    });

    test('방향 8개가 모두 서로 다른 이름입니다', () {
      final names = {
        for (final direction in Direction.values)
          directionName(l10n, direction),
      };
      expect(names, hasLength(8));
    });
  });

  group('날의 성격과 notice', () {
    test(
      '날의 성격 줄은 배지 변형과 ARB 이름, 이유는 응답의 characterReason입니다(draft.3)',
      () async {
        final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
        final daily = Daily.fromJson(memberDailyJson());
        final line = dayCharacterOf(daily, l10n);
        expect(line.variant, DayCharacterVariant.good);
        expect(line.label, l10n.dayKindYongsinDay);
        expect(line.reason?.toJson(), daily.characterReason.text.toJson());
        expect(
          line.reason?.segments.single.text,
          '내게 필요한 기운이 들어와 일이 잘 풀리기 쉬운 날이에요.',
        );
        expect(daily.dayKind, DayKind.yongsinDay);
      },
    );

    test('공유 이미지 이유도 같은 characterReason입니다', () async {
      await initializeDateFormatting('ko');
      final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
      final daily = Daily.fromJson(memberDailyJson());
      final image = shareImageContentOf(
        date: CalendarDate(2026, 10, 13),
        daily: daily,
        names: _names,
        l10n: l10n,
        locale: const Locale('ko'),
        timezone: 'Asia/Seoul',
      );
      expect(image.reason?.toJson(), daily.characterReason.text.toJson());
    });

    test('time_unknown notice의 조각 글자를 잇고, 없으면 null입니다', () {
      final json = memberDailyJson();
      expect(timeUnknownNoticeOf(Daily.fromJson(json), _l10n), isNull);
      json['notices'] = [
        {
          'code': 'time_unknown',
          'text': {
            'segments': [
              {'text': '태어난 시간을 몰라 '},
              {'text': '세 기둥', 'term': 'pillar.three'},
              {'text': '으로 계산했어요.'},
            ],
          },
        },
      ];
      expect(
        timeUnknownNoticeOf(Daily.fromJson(json), _l10n),
        '태어난 시간을 몰라 세 기둥으로 계산했어요.',
      );
    });

    test('SentenceLine.isBlank는 빈 조각과 공백뿐인 조각을 빈 문장으로 봅니다', () {
      SentenceLine line(List<String> pieces) => SentenceLine(
        text: RenderedText.fromJson({
          'segments': [
            for (final piece in pieces) {'text': piece},
          ],
        }),
        slot: 'daily.fortune.head',
      );
      expect(line([]).isBlank, isTrue);
      expect(line(['', ' ', '\n']).isBlank, isTrue);
      expect(line(['오늘은']).isBlank, isFalse);
    });

    test('같은 응답은 같은 화면 값, 날의 성격이 다르면 다른 값입니다', () {
      final a = Daily.fromJson(memberDailyJson());
      final b = Daily.fromJson(memberDailyJson());
      expect(_display(a), _display(b));
      final json = memberDailyJson();
      json['dayKind'] = 'ordinary_day';
      expect(_display(Daily.fromJson(json)), isNot(_display(a)));
    });

    test('보이지 않는 필드(근거 잠금·근거·반응·규칙 버전)만 바뀌면 같은 화면 값입니다', () {
      final base = _display(Daily.fromJson(memberDailyJson()));
      final json = memberDailyJson();
      json['evidenceAccess'] = 'unlocked';
      json['rulesetVersion'] = 'r2';
      final head =
          (json['fortune'] as Map<String, dynamic>)['head']
              as Map<String, dynamic>;
      head['reaction'] = 'like';
      head['evidence'] = <Object>[];
      expect(_display(Daily.fromJson(json)), base);
    });

    test('보이는 필드(행운 값·설명·가이드·성격 이유·시간 모름·반응 가능)가 바뀌면 다른 화면 값입니다', () {
      final base = _display(Daily.fromJson(memberDailyJson()));
      void expectChanged(void Function(Map<String, dynamic> json) change) {
        final json = memberDailyJson();
        change(json);
        expect(_display(Daily.fromJson(json)), isNot(base));
      }

      Map<String, dynamic> cards(Map<String, dynamic> json) =>
          json['cards'] as Map<String, dynamic>;
      expectChanged(
        (json) => (cards(json)['number'] as Map<String, dynamic>)['number'] = 8,
      );
      expectChanged(
        (json) =>
            (cards(json)['direction'] as Map<String, dynamic>)['direction'] =
                'w',
      );
      expectChanged(
        (json) =>
            ((json['guide'] as Map<String, dynamic>)['text']
                as Map<String, dynamic>)['segments'] = [
              {'text': '다른 질문'},
            ],
      );
      expectChanged(
        (json) =>
            ((json['characterReason'] as Map<String, dynamic>)['text']
                as Map<String, dynamic>)['segments'] = [
              {'text': '다른 이유'},
            ],
      );
      expectChanged(
        (json) => json['notices'] = [
          {
            'code': 'time_unknown',
            'text': {
              'segments': [
                {'text': '시간 모름'},
              ],
            },
          },
        ],
      );
      expectChanged(
        (json) =>
            ((json['fortune'] as Map<String, dynamic>)['head']
                    as Map<String, dynamic>)['reactable'] =
                false,
      );
    });

    test('같은 값이면 hashCode도 같습니다', () {
      final a = _display(Daily.fromJson(memberDailyJson()));
      final b = _display(Daily.fromJson(memberDailyJson()));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('featuredTagsOf(D76)', () {
    RenderedText text(String value) => RenderedText.fromJson({
      'segments': [
        {'text': value},
      ],
    });

    final names = GlossaryNames(
      const {
        'tag': {'cheoneul_gwiin': '천을귀인', 'clash': '충', 'gongmang': '공망'},
      },
      meanings: {
        'tag.cheoneul_gwiin': text('어려울 때 도와주는 사람이 곁에 오는 기운이에요.'),
        'tag.clash': text(' '),
      },
    );

    Daily dailyWith(List<Map<String, String>> featured) {
      final json = memberDailyJson();
      (json['tags'] as Map<String, dynamic>)['featured'] = featured;
      return Daily.fromJson(json);
    }

    test('칩 이름은 사전 tag 이름이고 뜻은 term.meaning tag.<키>입니다', () {
      final tags = featuredTagsOf(Daily.fromJson(memberDailyJson()), names);
      expect(tags, hasLength(1));
      expect(tags.single.tagKey, 'cheoneul_gwiin');
      expect(tags.single.name, '천을귀인');
      expect(
        tags.single.explain?.segments.single.text,
        '어려울 때 도와주는 사람이 곁에 오는 기운이에요.',
      );
    });

    test('응답 순서대로 둘까지 그리고, 길흉은 쓰지 않습니다', () {
      final tags = featuredTagsOf(
        dailyWith([
          {'key': 'clash', 'polarity': 'bad'},
          {'key': 'cheoneul_gwiin', 'polarity': 'good'},
        ]),
        names,
      );
      expect([for (final tag in tags) tag.name], ['충', '천을귀인']);
    });

    test('응답이 둘을 넘어도 앞 둘만 칩이 되고 모두 tag 변형입니다', () {
      final tags = featuredTagsOf(
        dailyWith([
          {'key': 'clash', 'polarity': 'bad'},
          {'key': 'cheoneul_gwiin', 'polarity': 'good'},
          {'key': 'gongmang', 'polarity': 'bad'},
        ]),
        names,
      );
      expect([for (final tag in tags) tag.tagKey], ['clash', 'cheoneul_gwiin']);
      expect(tags.every((tag) => tag.variant == LuckyCardVariant.tag), isTrue);
    });

    test('대표 태그가 없으면 빈 목록입니다', () {
      expect(featuredTagsOf(dailyWith([]), names), isEmpty);
    });

    test('뜻 문장이 없거나 공백뿐이면 meaning이 null입니다', () {
      final tags = featuredTagsOf(
        dailyWith([
          {'key': 'clash', 'polarity': 'bad'},
        ]),
        names,
      );
      expect(tags.single.explain, isNull);
    });

    test('사전에 이름이 없는 태그는 칩을 만들지 않습니다(키를 그대로 보이지 않음)', () {
      final tags = featuredTagsOf(
        dailyWith([
          {'key': 'hwagae', 'polarity': 'neutral'},
          {'key': 'cheoneul_gwiin', 'polarity': 'good'},
        ]),
        names,
      );
      expect([for (final tag in tags) tag.tagKey], ['cheoneul_gwiin']);
    });

    test('오늘 화면 값에 대표 태그가 담기고, 바뀌면 다른 화면 값입니다', () {
      TodayDisplay display(Daily daily) =>
          todayDisplayOf(daily, names, _l10n, 'Asia/Seoul');
      final base = display(Daily.fromJson(memberDailyJson()));
      expect([for (final tag in base.tags) tag.tagKey], ['cheoneul_gwiin']);
      expect(display(Daily.fromJson(memberDailyJson())), base);
      expect(
        display(
          dailyWith([
            {'key': 'clash', 'polarity': 'bad'},
          ]),
        ),
        isNot(base),
      );
      expect(display(dailyWith([])), isNot(base));
    });
  });
}
