@Tags(['contract'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/day_kind.dart';
import 'package:myungli_diary/core/api/gen/model/direction.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/focus_slot.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god_group.dart';
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
  'start': start,
  'end': end,
  'huangdaoLucky': true,
  'reasons': ['yongsin'],
});

const _names = GlossaryNames({
  'color': {'wood': '초록'},
  'tag': {'cheoneul_gwiin': '천을귀인', 'harmony': '합', 'yangin': '양인'},
  'ten_god_group': {'siksang': '식상'},
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
    final morning = _slot(
      '2026-10-13T09:30:00+09:00',
      '2026-10-13T11:30:00+09:00',
    );

    test('+09:00 응답을 Asia/Seoul 기준 HH:mm~HH:mm으로 씁니다', () {
      expect(formatFocusRange(morning, 'Asia/Seoul', 'ko'), '09:30~11:30');
    });

    test('UTC로 바뀐 같은 순간도 Asia/Seoul 기준 같은 값입니다', () {
      expect(
        formatFocusRange(
          _slot('2026-10-13T00:30:00Z', '2026-10-13T02:30:00Z'),
          'Asia/Seoul',
          'ko',
        ),
        '09:30~11:30',
      );
    });

    test('America/New_York이면 그 시간대 값입니다', () {
      // 2026-10-13은 서머타임(UTC-4)이라 한국 09:30은 전날 20:30입니다.
      expect(
        formatFocusRange(morning, 'America/New_York', 'ko'),
        '20:30~22:30',
      );
    });

    test('범위 표기는 언어별입니다(ko ~, ja 〜, en to, 그 밖은 en)', () {
      expect(formatFocusRange(morning, 'Asia/Seoul', 'ja'), '09:30〜11:30');
      expect(formatFocusRange(morning, 'Asia/Seoul', 'en'), '09:30 to 11:30');
      expect(formatFocusRange(morning, 'Asia/Seoul', 'fr'), '09:30 to 11:30');
    });

    test(
      '명세 lucky-card time의 clock, timeZone, 언어별 format, repeat를 따릅니다(V52)',
      () {
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
        expect(value.containsKey('join'), isFalse);
        expect(
          (time['repeat']! as Map<String, Object?>)['max'],
          maxFocusTimePicks,
        );
        final format = value['format']! as Map<String, Object?>;
        for (final MapEntry(key: language, value: pattern) in format.entries) {
          expect(
            formatFocusRange(morning, 'Asia/Seoul', language),
            (pattern! as String)
                .replaceFirst('HH:mm', '09:30')
                .replaceFirst('HH:mm', '11:30'),
            reason: language,
          );
        }
      },
    );
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
      expect(items.map((i) => i.variant), LuckyCardVariant.luckyValues);
      expect(items.map((i) => i.value), [
        '초록',
        l10n.direction8E,
        '3',
        '09:30~11:30',
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

    test('집중 시간 구간이 둘이면 구간마다 시간 칩 하나를 계약 순서대로 만듭니다(V52)', () {
      final json = memberDailyJson();
      final cards = json['cards']! as Map<String, Object?>;
      final focus = cards['focusTime']! as Map<String, Object?>;
      final first =
          (focus['picks']! as List<Object?>).first! as Map<String, Object?>;
      focus['picks'] = [
        first,
        {
          ...first,
          'start': '2026-10-13T13:30:00+09:00',
          'end': '2026-10-13T15:30:00+09:00',
        },
      ];
      final items = luckyItemsOf(
        Daily.fromJson(json),
        _names,
        l10n,
        'Asia/Seoul',
      );
      final times = items
          .where((item) => item.variant == LuckyCardVariant.time)
          .toList();
      expect(times.map((item) => item.value), ['09:30~11:30', '13:30~15:30']);
      expect(times.map((item) => item.ordinal), [0, 1]);
      expect(times.map((item) => item.name).toSet(), {l10n.todayLuckyTimeName});
      expect(times.first.explain, same(times.last.explain));
      expect(items, hasLength(5));
    });

    test('en, ja 문구면 시간 칩 값도 그 언어의 범위 표기입니다', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      expect(
        luckyItemsOf(daily, _names, en, 'Asia/Seoul').last.value,
        '09:30 to 11:30',
      );
      expect(
        luckyItemsOf(daily, _names, ja, 'Asia/Seoul').last.value,
        '09:30〜11:30',
      );
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

    test('time_unknown notice가 있으면 true이고 문장이 비어도 true입니다', () {
      final json = memberDailyJson();
      expect(hasTimeUnknownNotice(Daily.fromJson(json)), isFalse);
      json['notices'] = [
        {
          'code': 'time_unknown',
          'text': {'segments': <Object>[]},
        },
      ];
      expect(hasTimeUnknownNotice(Daily.fromJson(json)), isTrue);
    });

    test('모르는 notice code(열린 enum)는 건너뛰고 time_unknown만 봅니다', () {
      // A66: NoticeCode는 열린 enum이라 모르는 code가 와도 응답이 실패하지 않습니다.
      final json = memberDailyJson()
        ..['notices'] = [
          {
            'code': 'added_after_freeze',
            'text': {
              'segments': [
                {'text': '새 안내'},
              ],
            },
          },
        ];
      expect(hasTimeUnknownNotice(Daily.fromJson(json)), isFalse);
      (json['notices'] as List<Object?>).add({
        'code': 'time_unknown',
        'text': {
          'segments': [
            {'text': '시간 모름'},
          ],
        },
      });
      expect(hasTimeUnknownNotice(Daily.fromJson(json)), isTrue);
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

    test(
      '보이는 필드(행운 값, 설명, 가이드, 음력, 십성 묶음, 대표 태그, 시간 모름, 반응 가능)가 바뀌면 다른 화면 값입니다',
      () {
        final base = _display(Daily.fromJson(memberDailyJson()));
        void expectChanged(void Function(Map<String, dynamic> json) change) {
          final json = memberDailyJson();
          change(json);
          expect(_display(Daily.fromJson(json)), isNot(base));
        }

        Map<String, dynamic> cards(Map<String, dynamic> json) =>
            json['cards'] as Map<String, dynamic>;
        expectChanged(
          (json) =>
              (cards(json)['number'] as Map<String, dynamic>)['number'] = 8,
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
              json['lunar'] = {'month': 9, 'day': 3, 'isLeapMonth': false},
        );
        expectChanged((json) => json['dayStemTenGodGroup'] = 'siksang');
        expectChanged(
          (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
            {'key': 'harmony', 'polarity': 'good'},
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
      },
    );

    test('같은 값이면 hashCode도 같습니다', () {
      final a = _display(Daily.fromJson(memberDailyJson()));
      final b = _display(Daily.fromJson(memberDailyJson()));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('skippedFeaturedTagKeysOf(D76, A112)', () {
    const names = GlossaryNames({
      'tag': {
        'cheoneul_gwiin': '천을귀인',
        'clash': '충',
        'gongmang': '공망',
        'yangin': '양인',
      },
    });

    Daily dailyWith(List<Map<String, String>> featured) {
      final json = memberDailyJson();
      (json['tags'] as Map<String, dynamic>)['featured'] = featured;
      return Daily.fromJson(json);
    }

    test('사전에 이름이 없거나 한자 글자표에 없는 대표 태그 키를 응답 순서로 줍니다', () {
      expect(
        skippedFeaturedTagKeysOf(
          dailyWith([
            {'key': 'hwagae', 'polarity': 'neutral'},
            {'key': 'cheoneul_gwiin', 'polarity': 'good'},
            // 이름은 있지만 글자표(A112)에 없는 키도 그리지 못합니다.
            {'key': 'yangin', 'polarity': 'bad'},
            {'key': 'unknown_key', 'polarity': 'bad'},
          ]),
          names,
        ),
        ['hwagae', 'yangin', 'unknown_key'],
      );
      expect(
        skippedFeaturedTagKeysOf(Daily.fromJson(memberDailyJson()), names),
        isEmpty,
      );
    });
  });

  group('오늘 화면 값(D108, D112)', () {
    Daily dailyWith(void Function(Map<String, dynamic> json) change) {
      final json = memberDailyJson();
      change(json);
      return Daily.fromJson(json);
    }

    const readings = GlossaryNames({
      'stem': {'gyeong': '경'},
      'branch': {'shin': '신'},
      'tag': {'cheoneul_gwiin': '천을귀인', 'harmony': '합', 'yangin': '양인'},
      'ten_god_group': {'siksang': '식상'},
    });

    TodayDisplay displayOf(Daily daily, [GlossaryNames names = readings]) =>
        todayDisplayOf(daily, names, _l10n, 'Asia/Seoul');

    test('음력은 ARB 틀이고 윤달이면 윤달 틀, 응답에 없으면 null입니다', () {
      expect(displayOf(Daily.fromJson(memberDailyJson())).lunarText, isNull);
      expect(
        displayOf(
          dailyWith(
            (json) =>
                json['lunar'] = {'month': 9, 'day': 3, 'isLeapMonth': false},
          ),
        ).lunarText,
        _l10n.todayDateLunar(9, 3),
      );
      expect(
        displayOf(
          dailyWith(
            (json) =>
                json['lunar'] = {'month': 6, 'day': 1, 'isLeapMonth': true},
          ),
        ).lunarText,
        _l10n.todayDateLunarLeap(6, 1),
      );
    });

    test('일진은 한자와 사전 독음(괄호)이고, 독음이 없으면 한자만입니다', () {
      final daily = Daily.fromJson(memberDailyJson());
      expect(displayOf(daily).iljinText, _l10n.todayDateIljin('庚申(경신)'));
      expect(displayOf(daily, _names).iljinText, _l10n.todayDateIljin('庚申'));
    });

    test('날의 성격은 enum과 ARB 이름, 십성 묶음은 enum과 사전 이름입니다', () {
      final plain = displayOf(Daily.fromJson(memberDailyJson()));
      expect(plain.dayKind, DayKind.yongsinDay);
      expect(plain.dayKindLabel, _l10n.dayKindYongsinDay);
      expect(plain.tenGodGroup, isNull);
      expect(plain.tenGodGroupLabel, isNull);

      final grouped = displayOf(
        dailyWith((json) => json['dayStemTenGodGroup'] = 'siksang'),
      );
      expect(grouped.tenGodGroup, TenGodGroup.siksang);
      expect(grouped.tenGodGroupLabel, '식상');
      // 사전에 이름이 없으면 이름만 비고, 화면은 그 태그를 그리지 않습니다.
      expect(
        displayOf(
          dailyWith((json) => json['dayStemTenGodGroup'] = 'siksang'),
          const GlossaryNames({}),
        ).tenGodGroupLabel,
        isNull,
      );
    });

    test('대표 태그는 앞 둘이고, 그릴 수 없는 태그는 빼되 순번(rank)은 응답 순서입니다', () {
      final display = displayOf(
        dailyWith(
          (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
            {'key': 'yangin', 'polarity': 'bad'},
            {'key': 'harmony', 'polarity': 'good'},
            {'key': 'cheoneul_gwiin', 'polarity': 'good'},
          ],
        ),
      );
      expect([for (final tag in display.featured) tag.rank], [1]);
      expect(display.featured.single.key, 'harmony');
      expect(display.featured.single.glyph, '合');
      expect(display.featured.single.label, '합');
      // 1순위를 그리지 못해도 보조 문장은 그대로이고 그 위 태그만 없습니다.
      expect(display.body, isNotNull);
      expect(display.bodyTag, isNull);
    });

    test('member: 1순위 천을귀인이 보조 문장 위 태그이고 보조 문장은 fortune.tag입니다', () {
      final daily = Daily.fromJson(memberDailyJson());
      final display = displayOf(daily);
      expect(display.featured.single.rank, 0);
      expect(display.featured.single.glyph, '天');
      expect(display.bodyTag, display.featured.single);
      expect(display.body?.slot, daily.fortune.tag?.slot);
      expect(display.body?.text.toJson(), daily.fortune.tag?.text.toJson());
    });

    test('대표 태그가 없는 날(D112)은 fortune.tag가 와도 보조 문장이 없습니다', () {
      final display = displayOf(
        dailyWith(
          (json) =>
              (json['tags'] as Map<String, dynamic>)['featured'] = <Object>[],
        ),
      );
      expect(display.featured, isEmpty);
      expect(display.body, isNull);
      expect(display.bodyTag, isNull);
    });

    test('fortune.tag가 없으면 보조 문장이 없습니다', () {
      final display = displayOf(
        dailyWith(
          (json) => (json['fortune'] as Map<String, dynamic>).remove('tag'),
        ),
      );
      expect(display.body, isNull);
    });

    test('시간 모름은 time_unknown notice가 있는지입니다(문구는 화면의 ARB)', () {
      expect(displayOf(Daily.fromJson(memberDailyJson())).timeUnknown, isFalse);
      expect(
        displayOf(
          dailyWith(
            (json) => json['notices'] = [
              {
                'code': 'time_unknown',
                'text': {'segments': <Object>[]},
              },
            ],
          ),
        ).timeUnknown,
        isTrue,
      );
    });
  });
}
