@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, Builder, Icon, IconData, Locale, SizedBox, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/sentence/link_label.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../design/input/input_harness.dart';
import '../support/component_spec_json.dart';

Map<String, Object?> _interaction() =>
    jsonDecode(File('$componentsDir/interaction.json').readAsStringSync())
        as Map<String, Object?>;

const _durations = <String, Duration>{
  'short': Motion.short,
  'fade': Motion.fade,
  'medium': Motion.medium,
  'select': Motion.select,
  'long': Motion.long,
  'stamp': Motion.stamp,
  'breathe': Motion.breathe,
};
const _easings = <String, Cubic>{
  'seep': Motion.seep,
  'enter': Motion.enter,
  'exit': Motion.exit,
  'stamp-press': Motion.stampPress,
  'standard': Motion.standard,
};

/// `{motion.duration.stamp}` → `stamp`.
String _tokenName(Object? reference) {
  final text = reference! as String;
  return text.substring(1, text.length - 1).split('.').skip(2).join('.');
}

Duration _duration(Object? reference) => _durations[_tokenName(reference)]!;
Cubic _easing(Object? reference) => _easings[_tokenName(reference)]!;

/// `{"value": 8, "unit": "px"}` → 8.
double _px(Object? json) =>
    ((json! as Map<String, Object?>)['value']! as num).toDouble();

double _num(Object? json) => (json! as num).toDouble();

Map<String, Object?> _map(Object? json) => json! as Map<String, Object?>;

Map<String, Object?> _elements() => _map(
  _map(
    jsonDecode(File('$componentsDir/elements.json').readAsStringSync()),
  )['elements'],
);

/// [json] 아래 모든 `chevron` 값을 경로와 함께 모읍니다.
Map<String, Object?> _chevrons(Object? json, [String path = '']) => {
  if (json is Map<String, Object?>)
    for (final MapEntry(:key, :value) in json.entries) ...{
      if (key == 'chevron') '$path.$key': value,
      ..._chevrons(value, '$path.$key'),
    }
  else if (json is List<Object?>)
    for (final (i, item) in json.indexed) ..._chevrons(item, '$path[$i]'),
};

/// 명세 아이콘 이름(kebab-case) → Phosphor Regular 글리프. 대조에 쓰는 것만 둡니다.
const Map<String, IconData> _regularIcons = {
  'caret-right': PhosphorIconsRegular.caretRight,
  'sun': PhosphorIconsRegular.sun,
  'calendar-blank': PhosphorIconsRegular.calendarBlank,
  'notebook': PhosphorIconsRegular.notebook,
  'user': PhosphorIconsRegular.user,
};

void main() {
  group('ComponentSpec 대조', () {
    final specs = loadSpecComponents();

    test('명세 묶음에서 IA 컴포넌트 41개를 읽습니다', () {
      expect(specs, hasLength(41));
    });

    test('41개 전체의 variants·states 형태가 기대와 같습니다', () {
      for (final component in specs.values) {
        // variantIds·stateKeys가 형태(list/null, 문자열 id, dict/null)를 assert합니다.
        variantIds(component);
        stateKeys(component);
      }
    });

    test('명세 JSON에서 만든 ComponentSpec은 대조를 통과합니다(41개)', () {
      for (final component in specs.values) {
        final spec = ComponentSpec(
          component['id']! as String,
          variantIds(component),
          stateKeys(component),
        );
        expectSpecMatches(spec, component);
      }
    });

    test('변형·상태가 어긋나면 대조가 실패합니다', () {
      final component = specs.values.firstWhere(
        (c) => variantIds(c).isNotEmpty && stateKeys(c).isNotEmpty,
      );
      final id = component['id']! as String;
      expect(
        () => expectSpecMatches(
          ComponentSpec(id, {
            ...variantIds(component),
            'extra',
          }, stateKeys(component)),
          component,
        ),
        throwsA(isA<TestFailure>()),
      );
      expect(
        () => expectSpecMatches(
          ComponentSpec(id, variantIds(component), {
            ...stateKeys(component),
            'extra',
          }),
          component,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('등록된 컴포넌트 id가 명세에 있습니다', () {
      for (final spec in implementedComponents) {
        expect(specs.keys, contains(spec.id), reason: spec.id);
      }
    });

    for (final spec in implementedComponents) {
      test('${spec.id}: 변형·상태가 명세와 같습니다', () {
        expectSpecMatches(spec, specs[spec.id]!);
      });
    }

    test('sentence-block: 잠김 라벨 슬롯이 명세 a11y와 같습니다 (2.2.0)', () {
      final a11y = _map(specs['sentence-block']!['a11y']);
      expect(a11y['lockedNameSlot'], SentenceBlock.lockedNameSlotId);
      expect(a11y['lockedLabelSlot'], SentenceBlock.lockedLabelSlotId);
    });

    test('sentence-block: 잠김 라벨 문구가 두 슬롯의 ARB 문구에서 옵니다', () {
      expect(SentenceBlock.lockedLabelTexts.keys, [
        SentenceBlock.lockedNameSlotId,
        SentenceBlock.lockedLabelSlotId,
      ]);
      for (final locale in ['ko', 'en', 'ja']) {
        final arb = jsonDecode(
          File('lib/core/l10n/arb/app_$locale.arb').readAsStringSync(),
        ) as Map<String, Object?>;
        final l10n = lookupAppLocalizations(Locale(locale));
        for (final MapEntry(key: slotId, value: textOf)
            in SentenceBlock.lockedLabelTexts.entries) {
          expect(
            textOf(l10n),
            arb[iaKey(slotId)],
            reason: '$locale $slotId의 ARB 키 ${iaKey(slotId)}',
          );
        }
      }
    });
  });

  group('컴포넌트 2.3.0 값 대조', () {
    final specs = loadSpecComponents();

    test('링크 화살표 세 곳은 caret-right 아이콘이고 LinkLabel 값과 같습니다(V29)', () {
      final chevrons = _chevrons(specs['depth-link'])
        ..addAll(_chevrons(specs['sentence-block']));
      // depth-link parts.chevron, lockPanel.pass.chevron,
      // sentence-block open.chevron.
      expect(chevrons, hasLength(3), reason: '${chevrons.keys}');
      for (final MapEntry(key: path, value: chevron) in chevrons.entries) {
        final map = _map(chevron);
        expect(map['weight'], 'regular', reason: path);
        expect(_regularIcons[map['icon']], LinkLabel.caret, reason: path);
        // 크기·색은 링크 글자에서 이어받습니다(LinkLabel이 글리프 조각에 크기·색을 두지 않음).
        expect(map['size'], 'link-text-size', reason: path);
        expect(map['color'], 'link-color', reason: path);
        expect(_px(map['gap']), LinkLabel.gap, reason: path);
        expect(map['decorative'], isTrue, reason: path);
      }
    });

    test('mark.caution 크기는 글자 크기 × ratio입니다', () {
      final size = _map(_map(_elements()['mark.caution'])['size']);
      expect(size['of'], 'font-size');
      expect(_num(size['ratio']), AppIcon.capHeightRatio);
    });

    test('아이콘 패키지와 버전이 명세와 같습니다', () {
      final set = _map(_map(_elements()['icon'])['set']);
      expect(set['flutter'], 'phosphor_glyphs');
      final lock = File('pubspec.lock').readAsStringSync();
      final entry = RegExp(
        r'  phosphor_glyphs:\n(?:    .*\n)*?    version: "([^"]+)"',
      ).firstMatch(lock);
      expect(entry?.group(1), set['flutterVersion']);
    });

    test('tab-bar 아이콘이 명세 parts.icons와 같습니다', () {
      final icons = _map(_map(specs['tab-bar']!['parts'])['icons']);
      expect(icons.keys, ['today', 'calendar', 'diary', 'me']);
      expect(
        [for (final name in icons.values) _regularIcons[name]],
        [for (final glyph in tabGlyphs) glyph.regular],
      );
    });

    test('social-login-button disabled는 버튼 전체 opacity입니다', () {
      final disabled = _map(
        _map(specs['social-login-button']!['states'])['disabled'],
      );
      final container = _map(_map(disabled['parts'])['container']);
      expect(_num(container['opacity']), SocialLoginButton.disabledOpacity);
    });
    test('event-row list 시각 칸·최소 높이·구분선·화살표가 명세와 같습니다', () {
      final variants = (specs['event-row']!['variants']! as List<Object?>).map(
        _map,
      );
      final list = _map(variants.firstWhere((v) => v['id'] == 'list')['parts']);
      expect(_px(_map(list['timeColumn'])['width']), EventRow.timeColumnWidth);
      final row = _map(list['row']);
      expect(_px(row['minHeight']), EventRow.minHeight);
      expect(_px(_map(row['divider'])['width']), EventRow.dividerWidth);
      final chevron = _map(list['chevron']);
      expect(chevron['icon'], 'caret-right');
      expect(chevron['weight'], 'light');
      expect(_px(chevron['size']), AppIconSize.inline.logical);
      expect(
        _num(_map(specs['event-row']!['a11y'])['minTarget']),
        EventRow.minHeight,
      );
    });

    test('day-cell 크기·위치·투명도·글자 상한이 명세와 같습니다', () {
      final dayCell = specs['day-cell']!;
      final parts = _map(dayCell['parts']);
      expect(_px(_map(parts['container'])['height']), DayCell.height);
      expect(_map(parts['container'])['radius'], '{radius.sm}');
      final numberBox = _map(parts['numberBox']);
      expect(_px(numberBox['size']), DayCell.numberBoxSize);
      expect(_px(numberBox['marginTop']), DayCell.numberBoxTop);
      expect(_px(_map(parts['lunar'])['fontSize']), DayCell.lunarFontSize);
      for (final seal in ['diarySeal', 'todayOutline']) {
        expect(_px(_map(parts[seal])['size']), SealSize.cell.logical);
        expect(_map(parts[seal])['position'], 'number-box-center');
      }
      expect(_map(parts['diarySeal'])['variant'], 'soft');
      expect(_map(parts['todayOutline'])['variant'], 'outline');
      expect(_px(_map(parts['eventDot'])['size']), DayCell.eventDotSize);
      expect(_map(parts['layers'])['order'], [
        'luck-fill',
        'diary-seal',
        'today-outline',
        'number',
        'selected-underline',
        'event-dot',
      ], reason: 'DayCell.layerOrder와 같은 순서');
      expect(DayCell.layerOrder, hasLength(6));
      final outside = _map(
        _map(_map(_map(dayCell['states'])['outsideMonth'])['parts'])['number'],
      );
      expect(_num(outside['opacity']), DayCell.outsideMonthOpacity);
      final a11y = _map(dayCell['a11y']);
      expect(_num(a11y['textScaleMax']), DayCell.textScaleMax);
      expect(_num(a11y['minTarget']), lessThanOrEqualTo(DayCell.height));
      final underline = _map(_elements()['mark.underline-grow']);
      expect(_px(underline['width']), DayCell.underlineWidth);
      expect(_px(underline['height']), DayCell.underlineHeight);
      expect(_px(underline['gap']), DayCell.underlineGap);
    });

    test('calendar-month 머리·요일·격자·범례 값이 명세와 같습니다', () {
      final month = specs['calendar-month']!;
      final parts = _map(month['parts']);
      final header = _map(parts['header']);
      for (final (side, icon) in [
        ('prev', 'caret-left'),
        ('next', 'caret-right'),
      ]) {
        final button = _map(header[side]);
        expect(button['icon'], icon);
        expect(button['weight'], 'light');
        expect(_px(button['target']), CalendarMonthView.headerTarget);
      }
      expect(
        _px(_map(parts['weekdays'])['height']),
        CalendarMonthView.weekdaysHeight,
      );
      final grid = _map(parts['grid']);
      expect(_num(grid['columns']), CalendarMonthView.columns);
      expect(_px(grid['rowGap']), CalendarMonthView.gridGap);
      expect(_px(grid['columnGap']), CalendarMonthView.gridGap);
      expect(grid['cell'], 'day-cell');
      final swatch = _map(_map(parts['legend'])['swatch']);
      expect(_px(swatch['size']), CalendarMonthView.legendSwatchSize);
      expect(swatch['radius'], '{radius.xs}');
      expect(
        _num(_map(month['a11y'])['minTarget']),
        CalendarMonthView.headerTarget,
      );
    });

    test('tag.status 여백이 명세와 같습니다', () {
      final padding = _map(_map(_elements()['tag.status'])['padding']);
      expect(_px(padding['x']), StatusTag.padding.left);
      expect(_px(padding['x']), StatusTag.padding.right);
      expect(_px(padding['y']), StatusTag.padding.top);
      expect(_px(padding['y']), StatusTag.padding.bottom);
    });
  });

  group('컴포넌트 2.4.0 값 대조', () {
    final specs = loadSpecComponents();

    test('city-search region.join이 명세 언어별 구분자와 같습니다', () {
      final region = _map(_map(specs['city-search']!['parts'])['region']);
      expect(CitySearch.regionJoin, _map(region['join']));
    });

    test('city-search saving은 loading.breathe이고 점은 text.secondary입니다', () {
      final search = specs['city-search']!;
      final saving = _map(_map(search['states'])['saving']);
      expect(saving['pattern'], 'loading.breathe');
      final dots = _map(_map(saving['parts'])['dots']);
      expect(dots['fg'], '{color.text.secondary}');
      expect(
        _map(search['a11y'])['busyAnnounced'],
        lookupAppLocalizations(const Locale('ko')).actionBusy,
      );
    });

    test('input-step preface 위·아래는 space.24입니다', () {
      final preface = _map(_map(specs['input-step']!['parts'])['preface']);
      expect(preface['marginTop'], '{space.24}');
      expect(preface['marginBottom'], '{space.24}');
      expect(InputStep.prefaceGap, Space.s24);
    });

    testWidgets('skeleton textLine.type 기본은 type.body.ui입니다', (tester) async {
      final textLine = _map(_map(specs['skeleton']!['parts'])['textLine']);
      expect(_map(textLine['type'])['default'], '{type.body.ui}');
      late BuildContext inner;
      await tester.pumpWidget(
        inputApp(
          Builder(
            builder: (context) {
              inner = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        SkeletonBlock.defaultLineStyleOf(inner),
        inner.tokens.typography.bodyUi,
      );
    });
  });

  group('컴포넌트 2.5.0 값 대조', () {
    final specs = loadSpecComponents();

    Map<String, Object?> tagVariant() => _map(
      (specs['lucky-card']!['variants']! as List<Object?>)
          .map(_map)
          .firstWhere((v) => v['id'] == 'tag'),
    );

    testWidgets('lucky-card tag는 tag 아이콘(text.primary)과 굵기 600입니다(V35)', (
      tester,
    ) async {
      final parts = _map(tagVariant()['parts']);
      final lead = _map(parts['lead']);
      expect(lead['icon'], 'tag');
      expect(lead['iconColor'], '{color.text.primary}');
      final weight = _num(_map(parts['value'])['fontWeight']);
      expect(weight, 600);
      expect(LuckyChip.tagValueWeight.value, weight.toInt());

      await tester.pumpWidget(
        inputApp(
          const LuckyChip(
            item: LuckyItem.tag(tagKey: 'clash', name: '충'),
            open: false,
            onTap: null,
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, PhosphorIconsRegular.tag);
      expect(
        icon.color,
        tester.element(find.byType(Icon)).tokens.colors.textPrimary,
      );
      expect(
        tester.widget<Text>(find.byType(Text)).style!.fontWeight,
        LuckyChip.tagValueWeight,
      );
    });

    test('lucky-card tag 라벨은 태그 이름만이고 변형 id가 명세와 같습니다', () {
      expect(
        _map(specs['lucky-card']!['a11y'])['label'],
        contains('tag는 태그 이름만'),
      );
      expect({
        for (final v in LuckyCardVariant.values) v.name,
      }, variantIds(specs['lucky-card']!));
    });
  });

  group('InteractionPattern 대조', () {
    final patterns = _map(_interaction()['patterns']);

    test('enum 이름 집합이 interaction.json id의 lowerCamelCase와 같습니다', () {
      expect(
        InteractionPattern.values.map((p) => p.name).toSet(),
        patterns.keys.map(iaKey).toSet(),
      );
    });

    test('패턴마다 id·시간·곡선·대체 규칙이 명세와 같습니다', () {
      for (final pattern in InteractionPattern.values) {
        final json = _map(patterns[pattern.id]);
        expect(iaKey(pattern.id), pattern.name);
        expect(
          pattern.duration,
          _duration(json['duration']),
          reason: pattern.id,
        );
        expect(pattern.curve, _easing(json['easing']), reason: pattern.id);
        expect(
          pattern.reduceMotion.json,
          json['reduceMotion'],
          reason: pattern.id,
        );
        expect(pattern.lowEnd.json, json['lowEnd'], reason: pattern.id);
      }
    });

    test('숫자 값(흐림·크기·알파·어긋남·밝기)이 명세와 같습니다', () {
      Map<String, Object?> p(String id) => _map(patterns[id]);

      final ink = p('press.ink');
      expect(_num(_map(ink['ink'])['alpha']), PatternValues.inkAlpha);
      final release = _map(ink['release']);
      expect(
        _num((release['scale']! as List<Object?>)[1]),
        PatternValues.inkReleaseScale,
      );
      expect(_duration(release['duration']), PatternValues.releaseDuration);
      expect(_easing(release['easing']), PatternValues.releaseEasing);

      expect(
        _px(_map(p('appear.seep')['from'])['blur']),
        PatternValues.appearBlur,
      );
      expect(
        _px(_map(p('disappear.seep')['to'])['blur']),
        PatternValues.appearBlur,
      );

      final select = p('select.seep-slide');
      expect(_num(select['distance']), PatternValues.selectDistance);
      final incoming = _map(_map(select['incoming'])['from']);
      expect(_px(incoming['blur']), PatternValues.selectBlur);
      expect(_num(incoming['scale']), PatternValues.selectIncomingScale);
      final outgoing = _map(select['outgoing']);
      expect(_px(_map(outgoing['to'])['blur']), PatternValues.selectBlur);
      expect(
        _num(_map(outgoing['to'])['scale']),
        PatternValues.selectOutgoingScale,
      );
      expect(
        _duration(outgoing['duration']),
        PatternValues.selectOutgoingDuration,
      );
      expect(_easing(outgoing['easing']), PatternValues.selectOutgoingEasing);

      final breathe = p('loading.breathe');
      expect(
        _num((breathe['opacity']! as List<Object?>)[0]),
        PatternValues.breatheMinOpacity,
      );
      expect(
        Duration(milliseconds: _px(breathe['stagger']).round()),
        PatternValues.breatheStagger,
      );

      final frames = (p('seal.stamp')['keyframes']! as List<Object?>)
          .map(_map)
          .toList();
      expect(_num(frames[0]['scale']), PatternValues.stampStartScale);
      expect(_px(frames[0]['blur']), PatternValues.stampStartBlur);
      expect(_num(frames[1]['offset']), PatternValues.stampSplit);
      expect(_num(frames[1]['opacity']), PatternValues.stampSplitOpacity);
      expect(_px(frames[1]['blur']), PatternValues.stampSplitBlur);
      expect(_easing(frames[1]['easing']), PatternValues.stampFirstEasing);
      expect(_easing(frames[2]['easing']), PatternValues.stampSecondEasing);

      expect(_px(_map(p('seal.erase')['to'])['blur']), PatternValues.eraseBlur);

      for (final id in ['sheet.enter', 'sheet.exit']) {
        final scrim = _map(p(id)['scrim']);
        expect(
          _duration(scrim['duration']),
          PatternValues.scrimDuration,
          reason: id,
        );
        expect(_easing(scrim['easing']), PatternValues.scrimEasing, reason: id);
      }

      final stack = p('sheet.stack');
      final screen = _map(stack['screenBelow']);
      expect(_num(screen['scale']), PatternValues.stackScreenScale);
      expect(_num(screen['brightness']), PatternValues.stackScreenBrightness);
      final sheet = _map(stack['sheetBelow']);
      expect(_px(sheet['translateY']), PatternValues.stackSheetTranslateY);
      expect(_num(sheet['scale']), PatternValues.stackSheetScale);
      expect(_num(sheet['brightness']), PatternValues.stackSheetBrightness);

      final focus = p('focus.ring');
      expect(
        _px(_map(focus['from'])['borderWidth']),
        PatternValues.focusFromWidth,
      );
      expect(_px(_map(focus['to'])['borderWidth']), PatternValues.focusToWidth);
    });
  });
}
