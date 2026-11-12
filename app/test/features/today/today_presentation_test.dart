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
import 'package:myungli_diary/design/components/today/time_band.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

import '../../../tool/common/openapi_spec.dart';
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
    todayDisplayOf(daily, _names, _l10n, 'Asia/Seoul', beforeDayStart: false);

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

    test('명세 time의 clock, timeZone, format, periods를 따릅니다(V52, V115)', () {
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
      // 구간 반복(repeat)은 7.0.0에서 지웠고 낮 칩 하나, 밤 칩 하나입니다(V115).
      expect(time.containsKey('repeat'), isFalse);
      final periods = (time['periods']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(periods.map((period) => period['id']), [
        for (final period in AppTimeOfDay.values) period.name,
      ]);
      expect(periods.map((period) => period['source']), [
        'DailyResponse.focus_time',
        'DailyResponse.night_focus_time',
      ]);
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
    });
  });

  group('luckyItemsOf', () {
    late AppLocalizations l10n;
    late Daily daily;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('ko'));
      daily = Daily.fromJson(memberDailyJson());
    });

    List<LuckyItem> items({required bool beforeDayStart, Daily? from}) =>
        luckyItemsOf(
          from ?? daily,
          _names,
          l10n,
          'Asia/Seoul',
          beforeDayStart: beforeDayStart,
        );

    test('색은 glossary, 방향은 ARB, 숫자는 그대로, 시간은 낮과 밤 칩의 프로필 시간대 범위입니다', () {
      final lucky = items(beforeDayStart: false);
      expect(lucky.map((i) => i.variant), [
        ...LuckyCardVariant.luckyValues,
        LuckyCardVariant.time,
      ]);
      expect(lucky.map((i) => i.value), [
        '초록',
        l10n.direction8E,
        '3',
        '15:30~17:30',
        '01:30~03:30',
      ]);
      // 시간 칩 이름은 그 칩의 시트 제목입니다(a11y.timeLabel).
      expect(lucky.map((i) => i.name), [
        l10n.todayLuckyColorName,
        l10n.todayLuckyDirectionName,
        l10n.todayLuckyNumberName,
        l10n.todayLuckyTimeDayTitle,
        l10n.todayLuckyTimeNightTitle,
      ]);
      expect(lucky.first.element, FiveElement.wood);
      expect(lucky.first.explain, daily.cards.color.text.text);
      final [_, _, _, day, night] = lucky;
      expect(day.period, AppTimeOfDay.day);
      expect(day.word, isNull);
      expect(day.explain, daily.cards.focusTime.text.text);
      expect(night.period, AppTimeOfDay.night);
      expect(night.word, l10n.todayLuckyTimeNightTonight);
      expect(night.explain, daily.cards.nightFocusTime!.text.text);
    });

    test('낮 구간 시작 전에는 밤 칩이 전날 밤 카드이고 때 낱말이 새벽입니다(D122 ⑦, V116)', () {
      final night = items(beforeDayStart: true).last;
      final previous = daily.cards.previousNightFocusTime!;
      expect(night.period, AppTimeOfDay.night);
      expect(night.word, l10n.todayLuckyTimeNightDawn);
      expect(
        night.value,
        formatFocusRange(previous.picks.first, 'Asia/Seoul', 'ko'),
      );
      expect(night.explain, previous.text.text);
    });

    test('고른 밤 카드가 응답에 없으면 밤 칩만 없습니다(선택 필드)', () {
      final json = memberDailyJson();
      final cards = (json['cards']! as Map<String, Object?>)
        ..remove('previousNightFocusTime');
      final withoutPrevious = Daily.fromJson(json);
      // 07:30 전에는 전날 밤이 없으면 오늘 밤으로 대신하지 않습니다(A134).
      expect(
        items(beforeDayStart: true, from: withoutPrevious).map((i) => i.period),
        [null, null, null, AppTimeOfDay.day],
      );
      expect(
        items(beforeDayStart: false, from: withoutPrevious).last.period,
        AppTimeOfDay.night,
      );
      cards.remove('nightFocusTime');
      final dayOnly = Daily.fromJson(json);
      for (final before in [true, false]) {
        expect(items(beforeDayStart: before, from: dayOnly), hasLength(4));
      }
    });

    test('구간이 둘인 옛 규칙 버전 카드도 칩마다 첫 구간 하나입니다(D122 ⑤)', () {
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
      final times = items(
        beforeDayStart: false,
        from: Daily.fromJson(json),
      ).where((item) => item.variant == LuckyCardVariant.time).toList();
      expect(times.map((item) => item.value), ['15:30~17:30', '01:30~03:30']);
    });

    test('en, ja 문구면 시간 칩 값도 그 언어의 범위 표기입니다', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final ja = await AppLocalizations.delegate.load(const Locale('ja'));
      List<LuckyItem> times(AppLocalizations l10n) => luckyItemsOf(
        daily,
        _names,
        l10n,
        'Asia/Seoul',
        beforeDayStart: false,
      ).where((item) => item.variant == LuckyCardVariant.time).toList();
      expect(times(en).first.value, '15:30 to 17:30');
      expect(times(ja).first.value, '15:30〜17:30');
    });

    test('glossary에 색 이름이 없으면 값 id를 그대로 씁니다', () {
      final items = luckyItemsOf(
        daily,
        const GlossaryNames({}),
        l10n,
        'Asia/Seoul',
        beforeDayStart: false,
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

  group('행운 색 둘인 날(D119 ②③④)', () {
    const names = GlossaryNames({
      'color': {'water': '검정', 'earth': '노랑', 'wood': '초록'},
    });
    final pair = Daily.fromJson(dailyFixtureJson('daily-pair-virtue'));

    List<LuckyItem> items(Daily daily) =>
        luckyItemsOf(daily, names, _l10n, 'Asia/Seoul', beforeDayStart: false);

    test('secondColor가 있으면 색 항목 하나에 둘째 색이 붙고 칩 수는 같습니다', () {
      final lucky = items(pair);
      expect(lucky, hasLength(items(Daily.fromJson(memberDailyJson())).length));
      final color = lucky.first;
      expect(color.variant, LuckyCardVariant.color);
      expect(color.value, '검정');
      expect(color.element, FiveElement.water);
      expect(color.explain, pair.cards.color.text.text);
      final second = color.secondColor!;
      expect(second.element, FiveElement.earth);
      expect(second.value, '노랑');
      expect(second.explain, pair.cards.secondColor!.text.text);
      // 다른 항목에는 둘째 색이 없습니다.
      expect(
        lucky.skip(1).map((item) => item.secondColor),
        everyElement(isNull),
      );
    });

    test('secondColor가 없는 날은 둘째 색이 없습니다(선택 필드, 오류 아님)', () {
      final json = dailyFixtureJson('daily-pair-virtue');
      (json['cards'] as Map<String, dynamic>).remove('secondColor');
      expect(items(Daily.fromJson(json)).first.secondColor, isNull);
      expect(
        items(Daily.fromJson(memberDailyJson())).first.secondColor,
        isNull,
      );
    });

    test('숫자는 server가 첫째 색 기준으로 준 값 그대로입니다(D119 ③)', () {
      final number = items(pair)
          .singleWhere((item) => item.variant == LuckyCardVariant.number);
      expect(number.value, '${pair.cards.number.number}');
    });

    test('공유 이미지 색은 첫째 색 칸 하나입니다(D119 ④)', () async {
      await initializeDateFormatting('ko');
      final image = shareImageContentOf(
        date: CalendarDate(2026, 10, 19),
        daily: pair,
        names: names,
        l10n: _l10n,
        locale: const Locale('ko'),
        timezone: 'Asia/Seoul',
      );
      final colors = image.items.where(
        (item) => item.variant == LuckyCardVariant.color,
      );
      expect(colors, hasLength(1));
      expect(colors.single.value, '검정');
      expect(colors.single.secondColor, isNull);
    });

    test('두 색 카드는 같은 슬롯이라 근거는 카드 id로 각자의 문장을 찾습니다(A134)', () {
      final first = dailyCardSlotId(
        pair.cards.color.text,
        DailyCardField.color,
      );
      final second = dailyCardSlotId(
        pair.cards.secondColor!.text,
        DailyCardField.secondColor,
      );
      expect(first, 'daily.color#color');
      expect(second, 'daily.color#secondColor');
      expect(dailySlotText(pair, first), same(pair.cards.color.text));
      expect(dailySlotText(pair, second), same(pair.cards.secondColor!.text));
      final single = Daily.fromJson(memberDailyJson());
      expect(dailySlotText(single, 'daily.color#secondColor'), isNull);
    });

    test('둘째 색이 바뀌면 오늘 화면 값도 다릅니다(SeepOnChange)', () {
      final json = dailyFixtureJson('daily-pair-virtue');
      ((json['cards'] as Map<String, dynamic>)['secondColor']
              as Map<String, dynamic>)['element'] =
          'wood';
      TodayDisplay display(Daily daily) => todayDisplayOf(
        daily,
        names,
        _l10n,
        'Asia/Seoul',
        beforeDayStart: false,
      );
      expect(display(Daily.fromJson(json)), isNot(display(pair)));
    });
  });

  group('낮 구간 시작과 밤 카드(D122 ⑦, A134)', () {
    test('프로필 벽시계 07:30 전이면 낮 구간 시작 전입니다', () {
      expect(isBeforeDayStart(DateTime.utc(2026, 10, 13)), isTrue);
      expect(isBeforeDayStart(DateTime.utc(2026, 10, 13, 7, 29)), isTrue);
      expect(isBeforeDayStart(DateTime.utc(2026, 10, 13, 7, 30)), isFalse);
      expect(isBeforeDayStart(DateTime.utc(2026, 10, 13, 23, 59)), isFalse);
    });

    test('밤 카드 근거 id는 카드마다 다르고 dailySlotText가 그 카드 문장을 찾습니다', () {
      final daily = Daily.fromJson(memberDailyJson());
      final cards = daily.cards;
      final day = focusTimePickOf(
        cards,
        AppTimeOfDay.day,
        beforeDayStart: true,
      )!;
      final tonight = focusTimePickOf(
        cards,
        AppTimeOfDay.night,
        beforeDayStart: false,
      )!;
      final previous = focusTimePickOf(
        cards,
        AppTimeOfDay.night,
        beforeDayStart: true,
      )!;
      // 세 카드가 같은 슬롯이라 슬롯만으로는 낮 카드가 찾아집니다.
      expect(
        {cards.focusTime.text.slot, tonight.card.text.slot},
        {'daily.focus_time'},
      );
      expect(day.card, same(cards.focusTime));
      expect(tonight.card, same(cards.nightFocusTime));
      expect(previous.card, same(cards.previousNightFocusTime));
      expect({
        day.evidenceSlotId,
        tonight.evidenceSlotId,
        previous.evidenceSlotId,
      }, hasLength(3));
      expect(
        dailySlotText(daily, day.evidenceSlotId),
        same(cards.focusTime.text),
      );
      expect(
        dailySlotText(daily, tonight.evidenceSlotId),
        same(cards.nightFocusTime!.text),
      );
      expect(
        dailySlotText(daily, previous.evidenceSlotId),
        same(cards.previousNightFocusTime!.text),
      );
      // 슬롯 id만 주면 이전처럼 그 슬롯의 첫 카드(낮)입니다.
      expect(
        dailySlotText(daily, 'daily.focus_time'),
        same(cards.focusTime.text),
      );
      expect(dailySlotText(daily, 'daily.color#nightFocusTime'), isNull);
      expect(dailySlotText(daily, 'daily.focus_time#unknown'), isNull);
    });

    test('계약 secondColor는 선택 필드이고 color와 같은 ColorCard입니다(D119 ②)', () {
      final schemas =
          (loadOpenApi()['components']! as Map<String, Object?>)['schemas']!
              as Map<String, Object?>;
      final cards = schemas['DailyCards']! as Map<String, Object?>;
      expect(cards['required'], isNot(contains('secondColor')));
      final properties = cards['properties']! as Map<String, Object?>;
      expect(properties['secondColor'], properties['color']);
      // 두 카드는 같은 슬롯이라 카드 id(A134)로 근거를 나눕니다.
      expect(cards['description'], contains('같은 슬롯 `daily.color`'));
    });

    test('카드 필드 이름은 계약 DailyCards의 필드 이름과 같습니다', () {
      final schemas =
          (loadOpenApi()['components']! as Map<String, Object?>)['schemas']!
              as Map<String, Object?>;
      final cards = schemas['DailyCards']! as Map<String, Object?>;
      expect(
        DailyCardField.values.map((field) => field.name).toSet(),
        (cards['properties']! as Map<String, Object?>).keys.toSet(),
      );
    });

    test('오늘 화면 값은 낮 구간 시작 전후로 밤 칩이 달라 같은 값이 아닙니다', () {
      final daily = Daily.fromJson(memberDailyJson());
      TodayDisplay at({required bool before}) => todayDisplayOf(
        daily,
        _names,
        _l10n,
        'Asia/Seoul',
        beforeDayStart: before,
      );
      expect(at(before: true), isNot(at(before: false)));
      expect(at(before: false), at(before: false));
    });
  });

  group('timeBandOf(V117)', () {
    const names = GlossaryNames({
      'branch': {
        'ja': '자',
        'chuk': '축',
        'in': '인',
        'myo': '묘',
        'jin': '진',
        'sa': '사',
        'o': '오',
        'mi': '미',
        'shin': '신',
        'yu': '유',
        'sul': '술',
        'hae': '해',
      },
    });
    final daily = Daily.fromJson(memberDailyJson());

    TimeBand band(
      DateTime wallNow, {
      AppLocalizations? l10n,
      bool? beforeDayStart,
    }) => timeBandOf(
      daily: daily,
      names: names,
      l10n: l10n ?? _l10n,
      beforeDayStart: beforeDayStart ?? isBeforeDayStart(wallNow),
      wallNow: wallNow,
    );

    test('07:30부터는 낮 일곱 칸 다음 밤 다섯 칸이고 두 칩의 시진에 고리입니다', () {
      final shown = band(DateTime.utc(2026, 10, 13, 12));
      expect(shown.cells.map((cell) => cell.label).join(), '진사오미신유술해자축인묘');
      expect(shown.cells.map((cell) => cell.period), [
        for (var i = 0; i < 7; i++) AppTimeOfDay.day,
        for (var i = 0; i < 5; i++) AppTimeOfDay.night,
      ]);
      // 낮 신시(fixture 15:30~17:30)와 오늘 밤 축시(01:30~03:30).
      expect(
        [
          for (final cell in shown.cells)
            if (cell.picked) cell.label,
        ],
        ['신', '축'],
      );
      expect(shown.startTick.time, '07:30');
      expect(shown.startTick.dayWord, isNull);
      expect(shown.boundaryTick.time, '21:30');
      expect(shown.endTick.time, '07:30');
      expect(shown.endTick.dayWord, _l10n.todayLuckyTimeBandTomorrow);
      expect(shown.dayHead, _l10n.todayLuckyTimeBandDay);
      expect(shown.nightHead, _l10n.todayLuckyTimeBandNight);
      expect(shown.nowLabel, _l10n.todayLuckyTimeBandNow('12:00'));
      // 07:30부터 4시간 30분 = 24시간의 270/1440.
      expect(shown.nowFraction, closeTo(270 / 1440, 1e-9));
      expect(shown.hanjaLabels, isFalse);
    });

    test('07:30 전에는 전날 21:30부터 밤 다섯 칸이 앞이고 고리는 전날 밤 카드 시진입니다', () {
      final shown = band(DateTime.utc(2026, 10, 13, 0, 10));
      expect(shown.cells.map((cell) => cell.label).join(), '해자축인묘진사오미신유술');
      expect(shown.startTick.time, '21:30');
      expect(shown.startTick.dayWord, _l10n.todayLuckyTimeBandYesterday);
      expect(shown.boundaryTick.time, '07:30');
      expect(shown.endTick.time, '21:30');
      expect(shown.endTick.dayWord, isNull);
      final previous = daily.cards.previousNightFocusTime!.picks.first.branch;
      expect(
        [
          for (final cell in shown.cells)
            if (cell.picked) cell.label,
        ],
        [names.valueName('branch', previous.value), '신'],
      );
      // 전날 21:30부터 2시간 40분.
      expect(shown.nowFraction, closeTo(160 / 1440, 1e-9));
    });

    test('연 때 07:30 전이면 07:30을 지나도 순서와 고리는 그대로이고 지금 줄만 움직입니다(A134 ⑧)', () {
      final opened = band(DateTime.utc(2026, 10, 13, 7, 29));
      final later = band(DateTime.utc(2026, 10, 13, 8), beforeDayStart: true);
      expect(
        later.cells.map((cell) => (cell.label, cell.picked)),
        opened.cells.map((cell) => (cell.label, cell.picked)),
      );
      expect(later.startTick.time, opened.startTick.time);
      // 전날 21:30부터 10시간 30분.
      expect(later.nowFraction, closeTo(630 / 1440, 1e-9));
      expect(later.nowLabel, _l10n.todayLuckyTimeBandNow('08:00'));
    });

    test('밤 카드가 없으면 밤 칸에 고리가 없습니다', () {
      final json = memberDailyJson();
      (json['cards']! as Map<String, Object?>).remove('nightFocusTime');
      final shown = timeBandOf(
        daily: Daily.fromJson(json),
        names: names,
        l10n: _l10n,
        beforeDayStart: false,
        wallNow: DateTime.utc(2026, 10, 13, 12),
      );
      expect(
        [
          for (final cell in shown.cells)
            if (cell.picked) cell.period,
        ],
        [AppTimeOfDay.day],
      );
    });

    test('en은 지지 한자이고 한자 글꼴을 쓰며, 사전에 이름이 없으면 ko도 한자입니다', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final english = band(DateTime.utc(2026, 10, 13, 12), l10n: en);
      expect(english.cells.map((cell) => cell.label).join(), '辰巳午未申酉戌亥子丑寅卯');
      expect(english.hanjaLabels, isTrue);
      final unnamed = timeBandOf(
        daily: daily,
        names: const GlossaryNames({}),
        l10n: _l10n,
        beforeDayStart: false,
        wallNow: DateTime.utc(2026, 10, 13, 12),
      );
      expect(unnamed.cells.first.label, '辰');
      expect(unnamed.hanjaLabels, isFalse);
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
          '내 사주에 필요한 기운이 들어와 일이 잘 풀리기 쉬운 날이에요.',
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

    test('공유 이미지 시간은 밤 카드가 있어도 낮 칩 하나입니다(V116)', () async {
      await initializeDateFormatting('ko');
      final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
      final image = shareImageContentOf(
        date: CalendarDate(2026, 10, 13),
        daily: Daily.fromJson(memberDailyJson()),
        names: _names,
        l10n: l10n,
        locale: const Locale('ko'),
        timezone: 'Asia/Seoul',
      );
      final times = image.items.where(
        (item) => item.variant == LuckyCardVariant.time,
      );
      expect(times.map((item) => item.period), [AppTimeOfDay.day]);
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
              json['lunar'] = {'month': 6, 'day': 1, 'isLeapMonth': false},
        );
        expectChanged((json) => json['dayStemTenGodGroup'] = 'siksang');
        expectChanged(
          (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
            {'key': 'cheoneul_gwiin', 'polarity': 'good'},
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
        'harmony': '합',
        'ten_god_rush.bigyeop': '비겁이 많은 날',
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
      // member의 대표 태그(합, 비겁이 많은 날)는 둘 다 이름과 글자표(A112)에 있어 모두 그릴 수 있습니다.
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
      'ten_god_group': {'bigyeop': '비겁', 'siksang': '식상'},
    });

    TodayDisplay displayOf(Daily daily, [GlossaryNames names = readings]) =>
        todayDisplayOf(
          daily,
          names,
          _l10n,
          'Asia/Seoul',
          beforeDayStart: false,
        );

    test('음력은 ARB 틀이고 윤달이면 윤달 틀, 응답에 없으면 null입니다', () {
      expect(
        displayOf(Daily.fromJson(memberDailyJson())).lunarText,
        _l10n.todayDateLunar(9, 3),
      );
      expect(
        displayOf(dailyWith((json) => json.remove('lunar'))).lunarText,
        isNull,
      );
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

    test('일진은 사전 값 이름을 독음으로 쓰지 않아 한자만입니다(A133, #1069 전)', () {
      final daily = Daily.fromJson(memberDailyJson());
      // 사전에 천간, 지지 이름이 있어도 독음 자리에 쓰지 않습니다.
      expect(displayOf(daily).iljinText, _l10n.todayDateIljin('庚申'));
      expect(displayOf(daily, _names).iljinText, _l10n.todayDateIljin('庚申'));
    });

    test('날의 성격은 enum과 ARB 이름, 십성 묶음은 enum과 사전 이름입니다', () {
      final member = displayOf(Daily.fromJson(memberDailyJson()));
      expect(member.dayKind, DayKind.yongsinDay);
      expect(member.dayKindLabel, _l10n.dayKindYongsinDay);
      expect(member.tenGodGroup, TenGodGroup.bigyeop);
      expect(member.tenGodGroupLabel, '비겁');
      // 십성 묶음이 없는 응답(옛 규칙 버전)은 둘 다 비어 있습니다.
      final plain = displayOf(
        dailyWith((json) {
          json
            ..remove('dayStemTenGod')
            ..remove('dayStemTenGodGroup');
        }),
      );
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

    test('member: 1순위 합이 보조 문장 위 태그이고 보조 문장은 fortune.tag입니다', () {
      final daily = Daily.fromJson(memberDailyJson());
      final display = displayOf(daily);
      expect(display.featured.single.rank, 0);
      expect(display.featured.single.glyph, '合');
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
      expect(display.featuredEmpty, isTrue);
      expect(display.body, isNull);
      expect(display.bodyTag, isNull);
    });

    test('대표 태그가 있지만 모두 그릴 수 없으면 featuredEmpty가 아니고 보조 문장은 남습니다', () {
      final display = displayOf(
        dailyWith(
          (json) => (json['tags'] as Map<String, dynamic>)['featured'] = [
            {'key': 'not_in_table', 'polarity': 'neutral'},
          ],
        ),
      );
      expect(display.featured, isEmpty);
      expect(display.featuredEmpty, isFalse);
      expect(display.body, isNotNull);
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
