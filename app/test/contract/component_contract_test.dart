@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart'
    show
        Border,
        BoxDecoration,
        BoxShape,
        Brightness,
        BuildContext,
        Builder,
        Center,
        DecoratedBox,
        Icon,
        IconData,
        Locale,
        SingleChildScrollView,
        SizedBox,
        Text,
        TextEditingController,
        Widget;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/five_element.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/score_item.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/calendar/fortune_verdict.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/scroll_hint.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/saju/band_table.dart';
import 'package:myungli_diary/design/components/saju/luck_pillar.dart';
import 'package:myungli_diary/design/components/saju/ohaeng_bar.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/hanja_glyphs.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/link_label.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/share_image.dart';
import 'package:myungli_diary/design/components/today/tag_sentence_list.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/elements/ohaeng_cell.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/design/elements/skeleton_bone.dart';
import 'package:myungli_diary/design/elements/status_tag.dart';
import 'package:myungli_diary/design/elements/stem_chip.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/theme/ohaeng_colors.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

import '../design/input/input_harness.dart';
import '../support/component_spec_json.dart';
import 'component_pending.dart';

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
  'page': Motion.pageDuration,
};
const _easings = <String, Cubic>{
  'seep': Motion.seep,
  'enter': Motion.enter,
  'exit': Motion.exit,
  'stamp-press': Motion.stampPress,
  'standard': Motion.standard,
  'page': Motion.pageEasing,
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

/// `"#06C755"`와 투명도 → [Color]. 투명도가 없으면 불투명입니다.
Color _hexColor(Object? hex, [Object? opacity]) {
  final value = int.parse((hex! as String).substring(1), radix: 16);
  return Color.from(
    alpha: opacity == null ? 1 : _num(opacity),
    red: ((value >> 16) & 0xFF) / 255,
    green: ((value >> 8) & 0xFF) / 255,
    blue: (value & 0xFF) / 255,
  );
}

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

/// `{size.icon.16}` → [AppIconSize.s16].
AppIconSize _iconSize(Object? reference) => AppIconSize.values.singleWhere(
  (size) => reference == '{size.icon.${size.logical.toInt()}}',
  orElse: () => fail('모르는 아이콘 크기 $reference'),
);

/// 대기 중인 대조의 실패가 기대한 실패(`PendingCheck.failure`가 든 `TestFailure`)인지 봅니다.
/// 실패하지 않았으면 대기 목록에서 지우라고, 다른 실패면 그 실패를 그대로 알립니다.
void _expectPendingFailure(String key, PendingCheck pending, Object? failure) {
  if (failure == null) {
    fail(
      '"$key"는 대기(${pending.reason})인데 대조가 통과합니다. '
      'knownPendingChecks에서 지우세요.',
    );
  }
  if (failure is! TestFailure ||
      !(failure.message ?? '').contains(pending.failure)) {
    fail(
      '"$key"는 대기(${pending.reason})인데 기대한 실패 '
      '"${pending.failure}"가 아닌 다른 이유로 실패합니다: $failure',
    );
  }
}

/// 대조 [check]를 돌립니다. [key]가 [knownPendingChecks]에 있으면 아직 6.0.0을 따라잡지
/// 않은 대조라 기대한 실패가 나야 하고, 통과하면 대기 목록에서 지우라고 실패합니다(ratchet).
void _contractCheck(String key, void Function() check) {
  final pending = knownPendingChecks[key];
  if (pending == null) {
    check();
    return;
  }
  Object? failure;
  try {
    check();
  } on Object catch (error) {
    failure = error;
  }
  _expectPendingFailure(key, pending, failure);
}

/// [_contractCheck]의 위젯 판.
Future<void> _contractCheckWidgets(
  String key,
  Future<void> Function() check,
) async {
  final pending = knownPendingChecks[key];
  if (pending == null) {
    await check();
    return;
  }
  Object? failure;
  try {
    await check();
  } on Object catch (error) {
    failure = error;
  }
  _expectPendingFailure(key, pending, failure);
}

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

    test('명세 묶음(6.0.0)에서 컴포넌트 56개를 읽습니다', () {
      expect(specs, hasLength(56));
    });

    test('계약 id는 모두 등록됐거나 대기 목록에 있고, 둘은 겹치지 않습니다', () {
      final registered = {for (final spec in implementedComponents) spec.id};
      expect(
        registered.intersection(knownPendingComponents.keys.toSet()),
        isEmpty,
        reason: '등록한 컴포넌트는 knownPendingComponents에서 지웁니다',
      );
      expect({
        ...registered,
        ...knownPendingComponents.keys,
      }, specs.keys.toSet());
    });

    test('대기 대조 키는 등록된 컴포넌트를 가리킵니다', () {
      final registered = {for (final spec in implementedComponents) spec.id};
      for (final key in knownPendingChecks.keys) {
        expect(registered, contains(key.split(' ').first), reason: key);
      }
    });

    test('56개 전체의 variants·states 형태가 기대와 같습니다', () {
      for (final component in specs.values) {
        // variantIds·stateKeys가 형태(list/null, 문자열 id, dict/null)를 assert합니다.
        variantIds(component);
        stateKeys(component);
      }
    });

    test('명세 JSON에서 만든 ComponentSpec은 대조를 통과합니다(56개)', () {
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
        _contractCheck(
          '${spec.id} spec',
          () => expectSpecMatches(spec, specs[spec.id]!),
        );
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
        ..addAll(_chevrons(specs['explain-sheet']));
      // depth-link navigate.chevron, lockPanel.pass.chevron,
      // explain-sheet diaryLink.chevron. 근거 진입점은 아이콘 하나(V63)라 꺾쇠가 없고,
      // sentence-block 잠김의 열기는 꺾쇠 대신 자물쇠입니다(V73).
      expect(chevrons, hasLength(3), reason: '${chevrons.keys}');
      for (final MapEntry(key: path, value: chevron) in chevrons.entries) {
        final map = _map(chevron);
        expect(map['weight'], 'regular', reason: path);
        expect(_regularIcons[map['icon']], LinkLabel.caret, reason: path);
        // 크기·색은 링크 글자에서 이어받습니다(LinkLabel이 글리프 조각에 크기·색을 두지 않음).
        expect(map['size'], 'adjacent-text', reason: path);
        expect(map['color'], 'link-color', reason: path);
        expect(map['gap'], '{space.2}', reason: path);
        expect(LinkLabel.gap, Space.s2);
        expect(map['decorative'], isTrue, reason: path);
      }
    });

    test('mark.caution 크기는 옆 글자에 맞춘 adjacent-text입니다', () {
      expect(_map(_elements()['mark.caution'])['size'], 'adjacent-text');
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
      expect(_map(row['divider'])['element'], 'list.divider');
      final divider = _map(_elements()['list.divider']);
      expect(divider['width'], '{border.width.hairline}');
      expect(EventRow.dividerWidth, BorderTokens.hairline);
      final chevron = _map(list['chevron']);
      expect(chevron['icon'], 'caret-right');
      expect(chevron['weight'], 'light');
      expect(_iconSize(chevron['size']), AppIconSize.s16);
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
      expect(numberBox['marginTop'], '{space.4}');
      expect(DayCell.numberBoxTop, Space.s4);
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
      expect(underline['gap'], '{space.2}');
      expect(DayCell.underlineGap, Space.s2);
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

    testWidgets('skeleton textLine 기본 글자, 높이, 마지막 줄 폭이 명세와 같습니다', (
      tester,
    ) async {
      final textLine = _map(_map(specs['skeleton']!['parts'])['textLine']);
      expect(_map(textLine['type'])['default'], '{type.body.ui}');
      expect(textLine['height'], '글자 줄 높이의 60%');
      expect(SkeletonTextLines.heightFactor, 0.6);
      expect(textLine['lastLineWidth'], '60%');
      expect(SkeletonTextLines.lastLineWidthFactor, 0.6);
      expect(textLine['radius'], '{radius.xs}');
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
        SkeletonTextLines.defaultStyleOf(inner),
        inner.tokens.typography.bodyUi,
      );
    });
  });

  group('컴포넌트 2.7.0 값 대조', () {
    final specs = loadSpecComponents();

    Map<String, Object?> variantParts(String id) => _map(
      _map(
        (specs['social-login-button']!['variants']! as List<Object?>)
            .map(_map)
            .firstWhere((v) => v['id'] == id),
      )['parts'],
    );

    test('social-login-button line 변형 색이 LINE 가이드 값과 같습니다', () {
      final parts = variantParts('line');
      expect(
        _hexColor(_map(parts['container'])['bg']),
        SocialLoginButton.lineBackground,
      );
      expect(
        _hexColor(_map(parts['label'])['fg']),
        SocialLoginButton.lineForeground,
      );
      final separator = _map(parts['separator']);
      expect(
        _hexColor(separator['color'], separator['opacity']),
        SocialLoginButton.lineSeparator,
      );
      final overlay = _map(_map(parts['pressed'])['overlay']);
      expect(
        _hexColor(overlay['color'], overlay['opacity']),
        SocialLoginButton.linePressedOverlay,
      );
      final disabled = _map(parts['disabled']);
      expect(
        _hexColor(disabled['bg']),
        SocialLoginButton.lineDisabledBackground,
      );
      final border = _map(disabled['border']);
      expect(
        _hexColor(border['color'], border['opacity']),
        SocialLoginButton.lineDisabledBorder,
      );
      final fg = _map(disabled['fg']);
      expect(
        _hexColor(fg['color'], fg['opacity']),
        SocialLoginButton.lineDisabledForeground,
      );
    });

    test('social-login-button google 변형 light·dark 값과 글자 크기가 가이드와 같습니다', () {
      final parts = variantParts('google');
      final container = _map(parts['container']);
      for (final (mode, theme) in [
        ('lightMode', SocialLoginButton.googleLight),
        ('darkMode', SocialLoginButton.googleDark),
      ]) {
        final json = _map(container[mode]);
        expect(_hexColor(json['bg']), theme.background, reason: mode);
        expect(_hexColor(json['border']), theme.border, reason: mode);
        expect(_hexColor(json['fg']), theme.foreground, reason: mode);
      }
      expect(
        _px(container['borderWidth']),
        SocialLoginButton.googleBorderWidth,
      );
      final label = _map(parts['label']);
      expect(_px(label['fontSize']), SocialLoginButton.googleFontSize);
      expect(_px(label['lineHeight']), SocialLoginButton.googleLineHeight);
    });

    test('social-login-button 로고 크기·안쪽 여백과 connected 배지가 명세와 같습니다', () {
      final component = specs['social-login-button']!;
      final logo = _map(_map(component['parts'])['logo']);
      expect(_px(logo['size']), SocialLoginButton.logoSize);
      expect(logo['inset'], '{space.16}');
      expect(SocialLoginButton.logoInset, Space.s16);
      expect(logo['position'], 'start');
      final connected = _map(_map(component['states'])['connected']);
      final badge = _map(_map(_map(connected['parts'])['logo'])['badge']);
      expect(_px(badge['size']), SocialLoginButton.badgeSize);
      expect(_px(badge['symbolSize']), SocialLoginButton.badgeSymbolSize);
      for (final provider in SocialProvider.values) {
        final json = _map(badge[provider.name]);
        expect(
          json['shape'],
          SocialLoginButton.badgeIsCircle(provider)
              ? '{radius.full}'
              : '{radius.xs}',
          reason: provider.name,
        );
        for (final (mode, dark) in [('lightMode', false), ('darkMode', true)]) {
          // Apple만 밝기마다 값이 있고, 나머지는 한 값입니다.
          final bg = json.containsKey(mode)
              ? _map(json[mode])['bg']
              : json['bg'];
          expect(
            _hexColor(bg),
            SocialLoginButton.badgeColor(provider, dark: dark),
            reason: '${provider.name} $mode',
          );
        }
      }
      final state = _map(_map(connected['parts'])['state']);
      expect(state['icon'], 'check');
      expect(state['weight'], 'regular');
      expect(_iconSize(state['size']), SocialLoginButton.connectedIconSize);
      expect(state['gap'], '{space.4}');
      expect(SocialLoginButton.connectedStateGap, Space.s4);
      expect(state['inset'], '{space.16}');
      expect(SocialLoginButton.connectedEndInset, Space.s16);
      expect(state['position'], 'end');
      final connectedDisabled = _map(
        _map(_map(connected['disabled'])['parts'])['container'],
      );
      expect(
        _num(connectedDisabled['opacity']),
        SocialLoginButton.disabledOpacity,
      );
    });

    test('account-choice 카드 테두리·고름 표시 크기가 명세와 같습니다', () {
      final component = specs['account-choice']!;
      final parts = _map(component['parts']);
      expect(_num(_map(parts['group'])['count']), AccountChoice.optionCount);
      expect(
        _px(_map(_map(parts['card'])['border'])['width']),
        AccountChoice.cardBorderWidth,
      );
      expect(_map(parts['card'])['padding'], '{space.16}');
      expect(AccountChoice.cardPadding, Space.s16);
      final mark = _map(parts['mark']);
      expect(_px(mark['size']), AccountChoice.markSize);
      expect(mark['position'], 'top-end');
      expect(mark['inset'], '{space.16}');
      expect(AccountChoice.markInset, Space.s16);
      expect(_px(_map(mark['border'])['width']), AccountChoice.markBorderWidth);
      final selected = _map(
        _map(_map(component['states'])['selected'])['parts'],
      );
      expect(
        _px(_map(_map(selected['mark'])['dot'])['size']),
        AccountChoice.dotSize,
      );
      final haptic = _map((component['haptic']! as List<Object?>).single);
      expect(haptic['strength'], 'selection');
    });
  });

  group('컴포넌트 2.8.0 값 대조', () {
    final specs = loadSpecComponents();

    Map<String, Object?> variantParts(String id) => _map(
      _map(
        (specs['diary-row']!['variants']! as List<Object?>)
            .map(_map)
            .firstWhere((v) => v['id'] == id),
      )['parts'],
    );

    Map<String, Object?> rowParts() => _map(specs['diary-row']!['parts']);

    test('diary-row 변형은 day·entries, 상태는 pressed·loading입니다', () {
      expect(variantIds(specs['diary-row']!), {'day', 'entries'});
      expect(stateKeys(specs['diary-row']!), {'pressed', 'loading'});
    });

    test('diary-row entry 시각 글자·미리보기 1줄·간격·꺾쇠가 명세와 같습니다', () {
      final entry = _map(rowParts()['entry']);
      final time = _map(entry['time']);
      expect(time['source'], 'createdAt');
      expect(time['type'], '{type.caption.md}');
      expect(time['fg'], '{color.text.secondary}');
      expect(time['fontFeatures'], ['tnum']);
      expect(time['wrap'], false);
      final preview = _map(entry['preview']);
      expect(preview['variant'], 'preview');
      expect(preview['maxLines'], DiaryEntryLine.previewMaxLines);
      expect(preview['marginStart'], '{space.12}');
      expect(DiaryEntryLine.timeGap, Space.s12);
      expect(preview['baseline'], 'time');
      expect(preview['emptyKeepsLineHeight'], true);
      final chevron = _map(entry['chevron']);
      expect(chevron['icon'], 'caret-right');
      expect(chevron['weight'], 'light');
      expect(_iconSize(chevron['size']).logical, DiaryEntryLine.chevronSize);
      expect(chevron['fg'], '{color.text.secondary}');
      expect(entry['paddingY'], '{space.12}');
      expect(DiaryEntryLine.paddingY, Space.s12);
      expect(_px(entry['minHeight']), DiaryEntryLine.minHeight);
    });

    test('diary-row entry 점선은 1px 대시 4 간격 3이고 줄 사이에만 있습니다', () {
      final divider = _map(_map(rowParts()['entry'])['divider']);
      expect(divider['style'], 'dashed');
      expect(_px(divider['width']), DiaryEntryLine.dividerWidth);
      // 4.0.0에서 키 dash, gap → dashLength, dashGap.
      expect(divider, isNot(contains('dash')));
      expect(_px(divider['dashLength']), DiaryEntryLine.dividerDashLength);
      expect(_px(divider['dashGap']), DiaryEntryLine.dividerDashGap);
      expect(divider['color'], '{color.timeline.entry}');
      expect(divider['between'], 'entries-only');
      expect(divider['span'], 'row');
      expect(divider['inMinHeight'], true);
    });

    testWidgets('diary-row day 묶음 카드 간격과 눌림 규칙이 명세와 같습니다', (tester) async {
      final group = _map(variantParts('day')['group']);
      expect(group['pressable'], false);
      expect(group['entriesMarginTop'], '{space.4}');
      expect(DiaryRow.entriesMarginTop, Space.s4);
      expect(_map(group['tag'])['marginTop'], '{space.8}');
      expect(DiaryRow.groupTagMarginTop, Space.s8);
      expect(_map(group['preview'])['visible'], false);
      // 5.0.0: 맨 위가 배지(badge) 대신 날의 성격(dayKind) hanja-tag이고 그 아래 space.4.
      expect(group['order'], ['dayKind', 'entries', 'tag']);
      expect(_map(group['dayKind'])['marginBottom'], '{space.4}');
      expect(DiaryRow.groupDayKindMarginBottom, Space.s4);
      await _contractCheckWidgets('diary-row day group', () async {
        await tester.pumpWidget(
          inputApp(
            SingleChildScrollView(
              child: DiaryDayGroup(
                date: CalendarDate(2026, 10, 12),
                entries: [
                  for (final hour in [8, 21])
                    DiaryEntryData(
                      createdAt: DateTime(2026, 10, 12, hour),
                      excerpt: '$hour시',
                      onTap: () {},
                    ),
                ],
                dayKind: const HanjaTag(
                  glyph: '用',
                  label: '좋은 날',
                  tone: HanjaTagTone.yongsin,
                ),
              ),
            ),
          ),
        );
        expect(
          find.byType(HanjaTag),
          findsOneWidget,
          reason: 'diary-row day group dayKind hanja-tag',
        );
      });
    });

    testWidgets('diary-row entries 오늘 바탕과 그날 시트 머리가 명세와 같습니다', (tester) async {
      final parts = variantParts('entries');
      final byScreen = _map(_map(parts['container'])['byScreen']);
      final today = _map(byScreen['today']);
      expect(today['bg'], '{color.bg.sheet}');
      expect(today['radius'], '{radius.lg}');
      expect(today['paddingX'], '{space.16}');
      expect(DiaryEntries.cardPaddingX, Space.s16);
      expect(today['paddingY'], '{space.4}');
      expect(DiaryEntries.cardPaddingY, Space.s4);
      expect(today['marginTop'], '{space.12}');
      expect(DiaryEntries.cardMarginTop, Space.s12);
      expect(byScreen['day-sheet'], 'none');
      expect(_map(parts['container'])['whenEmpty'], '그리지 않음');
      // 5.0.0: 그날 시트 일기 머리는 section-header가 맡고 entries head는 그리지 않습니다(V85).
      expect(_map(parts['head'])['visible'], false);
      // head 인자가 없어 그날 시트 바탕(plain)은 줄만 그립니다.
      await tester.pumpWidget(
        inputApp(
          DiaryEntries(
            entries: [
              DiaryEntryData(
                createdAt: DateTime(2026, 10, 12, 8),
                excerpt: '아침',
                onTap: () {},
              ),
            ],
            surface: DiaryEntriesSurface.plain,
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byType(DiaryEntryLine)).dy,
        tester.getTopLeft(find.byType(DiaryEntries)).dy,
      );
    });

    test(
      'guide-question-card full은 quiet disabled 버튼과 52 도장, 낭독은 after와 같습니다',
      () {
        final component = specs['guide-question-card']!;
        expect(stateKeys(component), {'loading', 'before', 'after', 'full'});
        final full = _map(_map(component['states'])['full']);
        expect(full['labelKey'], 'todayGuideCtaFull');
        final parts = _map(full['parts']);
        final action = _map(parts['action']);
        expect(action['variant'], 'quiet');
        expect(action['state'], 'disabled');
        expect(_px(_map(parts['seal'])['size']), SealSize.card.logical);
        expect(_map(parts['seal'])['layer'], 'behind-action-label');
        expect(component['haptic'], isEmpty);
        expect(GuideQuestionState.values.map((s) => s.name), [
          'before',
          'after',
          'full',
        ]);
      },
    );
  });

  group('컴포넌트 3.0.0 값 대조', () {
    final specs = loadSpecComponents();

    test(
      'account-choice 부품에 facts·diaryCount·providers가 없고 current·other 알약이 있다',
      () {
        final parts = _map(specs['account-choice']!['parts']);
        for (final removed in ['facts', 'diaryCount', 'providers']) {
          expect(parts, isNot(contains(removed)), reason: removed);
        }
        for (final (id, key) in [
          ('current', 'accountChoiceCurrent'),
          ('other', 'accountChoiceOther'),
        ]) {
          final pill = _map(parts[id]);
          expect(pill['key'], key, reason: id);
          expect(pill['type'], '{type.caption.sm}', reason: id);
          expect(pill['radius'], '{radius.full}', reason: id);
          expect(_map(pill['border'])['color'], '{color.line}', reason: id);
          expect(pill['paddingX'], '{space.8}', reason: id);
          expect(pill['gap'], '{space.8}', reason: id);
        }
      },
    );

    test('social-login-button 카카오 connected 배지는 #191919', () {
      final connected = _map(
        _map(specs['social-login-button']!['states'])['connected'],
      );
      final badge = _map(_map(_map(connected['parts'])['logo'])['badge']);
      final kakao = _map(badge['kakao']);
      expect(_hexColor(kakao['symbol']), SocialLoginButton.kakaoBadgeSymbol);
      expect(
        File('assets/brand/kakao/kakao_symbol.svg').readAsStringSync(),
        contains('fill="${kakao['symbol']}"'),
        reason: '배지 안 공식 심볼 자산의 색',
      );
    });

    test('social-login-button LINE 글자 자리 198, 다른 제공자 232', () {
      final variants = {
        for (final variant
            in specs['social-login-button']!['variants']! as List<Object?>)
          _map(variant)['id']! as String: _map(variant),
      };
      final line = _map(_map(variants['line']!['parts'])['label']);
      expect(
        _px(line['width']),
        SocialLoginButton.labelWidth(SocialProvider.line),
      );
      expect(_px(line['width']), 198);
      expect(_map(line)['widthSource'], contains('232px'));
      expect(SocialLoginButton.labelWidth(SocialProvider.kakao), 232);
      expect(SocialLoginButton.labelWidth(SocialProvider.google), 232);
      expect(SocialLoginButton.labelWidth(SocialProvider.apple), 232);
    });

    test('diary-row entry 꺾쇠 앞 간격은 space.8', () {
      final entry = _map(_map(_map(specs['diary-row']!['parts'])['entry']));
      final chevron = _map(entry['chevron']);
      expect(chevron['marginStart'], '{space.8}');
      expect(DiaryEntryLine.chevronGap, Space.s8);
    });

    test('offer-card 부품 값(바탕·radius·padding·아이콘 sparkle 28·간격 12/16/24/12)이 명세와 같다', () {
      final offer = specs['offer-card']!;
      final parts = _map(offer['parts']);
      final container = _map(parts['container']);
      expect(container['bg'], '{color.bg.sheet}');
      expect(container['radius'], '{radius.lg}');
      expect(container['padding'], '{space.20}');
      expect(OfferCard.padding, Space.s20);
      expect(Radii.lg, 20);

      final icon = _map(parts['icon']);
      expect(icon['name'], 'sparkle');
      expect(icon['weight'], 'light');
      expect(icon['size'], '{size.icon.28}');
      expect(OfferCard.iconSize, AppIconSize.s28.logical);
      expect(OfferCard.iconSize, 28);
      expect(icon['color'], '{color.action.primary}');

      expect(_map(parts['head'])['type'], '{type.subtitle}');
      expect(_map(parts['head'])['marginTop'], '{space.12}');
      expect(OfferCard.headGap, Space.s12);
      expect(_map(parts['price'])['type'], '{type.title}');
      expect(_map(parts['price'])['fontFeatures'], ['tnum']);
      expect(_map(parts['price'])['marginTop'], '{space.16}');
      expect(OfferCard.priceGap, Space.s16);
      // period(IA ad-free.offer.period): 글자 값은 명세, 가격과의 간격은 명세에 없어
      // purchase-row 보조 줄 간격(space.4)을 따릅니다.
      final period = _map(parts['period']);
      expect(period['type'], '{type.caption.lg}');
      expect(period['fg'], '{color.text.secondary}');
      expect(period, isNot(contains('marginTop')));
      expect(OfferCard.periodGap, PurchaseRowGroup.metaGap);
      expect(OfferCard.periodGap, Space.s4);
      expect(_map(parts['status'])['element'], 'tag.status');
      expect(_map(parts['remaining'])['type'], '{type.body.ui}');
      expect(_map(parts['remaining'])['fontFeatures'], ['tnum']);
      expect(_map(parts['buy'])['marginTop'], '{space.24}');
      expect(OfferCard.buyGap, Space.s24);
      expect(_map(parts['legal'])['type'], '{type.caption.md}');
      expect(_map(parts['legal'])['marginTop'], '{space.12}');
      expect(OfferCard.legalGap, Space.s12);

      expect(_map(parts['buy'])['variant'], 'filled');
      expect(_map(parts['history'])['variant'], 'quiet');
      expect(_map(_map(offer['states'])['active'])['pattern'], 'appear.seep');
    });

    test('purchase-row 부품 값(바탕, radius, 간격 16/16/4/2/12, 상태 폭 80)이 명세와 같다', () {
      final purchase = specs['purchase-row']!;
      final parts = _map(purchase['parts']);
      final group = _map(parts['group']);
      expect(group['bg'], '{color.bg.sheet}');
      expect(group['radius'], '{radius.lg}');
      expect(group['paddingX'], '{space.16}');
      expect(PurchaseRowGroup.paddingX, Space.s16);

      final row = _map(parts['row']);
      expect(row['paddingY'], '{space.16}');
      expect(PurchaseRowGroup.rowPaddingY, Space.s16);
      expect(row['pressable'], isFalse);
      // 4.0.0: 줄 사이 선은 요소 list.divider(0.5px, V58).
      final divider = _map(row['divider']);
      expect(divider['element'], 'list.divider');
      expect(divider['between'], 'rows-only');
      expect(PurchaseRowGroup.dividerKey, isNotNull);

      expect(_map(parts['product'])['type'], '{type.subtitle}');
      expect(_map(parts['product'])['overflow'], 'wrap');

      final status = _map(parts['status']);
      expect(status['gap'], '{space.12}');
      expect(PurchaseRowGroup.statusGap, Space.s12);
      expect(_px(status['maxWidth']), PurchaseRowGroup.statusMaxWidth);
      expect(_map(status['active'])['element'], 'tag.status');
      expect(_map(status['other'])['type'], '{type.label.md}');
      expect(_map(status['other'])['fg'], '{color.text.secondary}');

      final meta = _map(parts['meta']);
      expect(meta['type'], '{type.caption.lg}');
      expect(meta['fontFeatures'], ['tnum']);
      expect(meta['marginTop'], '{space.4}');
      expect(PurchaseRowGroup.metaGap, Space.s4);
      // 3.1.0(V47): 구매일 줄 아래 space.2에 사용 기간 줄, 구분자로 잇지 않음.
      expect(meta['layout'], 'lines');
      expect(meta, isNot(contains('join')));
      expect(_map(meta['period'])['marginTop'], '{space.2}');
      expect(PurchaseRowGroup.periodGap, Space.s2);

      expect(
        _map(_map(purchase['states'])['loading'])['component'],
        'skeleton',
      );
    });
  });

  test(
    'diary-editor tags: hanja-tag default, 사이 space.8, 위 space.16 (6.0.0, V96)',
    () {
      final tags = _map(
        _map(loadSpecComponents()['diary-editor']!['parts'])['tags'],
      );
      expect(tags['component'], 'hanja-tag');
      expect(tags['variant'], 'default');
      expect(tags['gap'], '{space.8}');
      expect(DiaryEditor.tagsGap, Space.s8);
      expect(tags['marginTop'], '{space.16}');
      expect(DiaryEditor.tagsMarginTop, Space.s16);
      expect(tags['appear'], 'appear.seep');
      expect(_map(tags['opens'])['diaryLink'], isTrue);
    },
  );

  group('hanja-tag 값 대조', () {
    final specs = loadSpecComponents();
    final tag = specs['hanja-tag']!;
    final parts = _map(tag['parts']);

    test('글자표의 값 집합이 계약 parts.glyphs 17자와 같습니다 (A112)', () {
      final glyphs = _map(parts['glyphs']);
      final contract = <String>{
        for (final group in glyphs.values) ..._map(group).keys,
      };
      expect(contract, hasLength(17));
      expect(HanjaGlyphs.allGlyphs, contract);
    });

    test('알약·한자 원 치수가 계약과 같습니다', () {
      final pill = _map(parts['pill']);
      final glyph = _map(parts['glyph']);
      expect(_px(pill['height']), HanjaTag.height);
      expect(pill['paddingStart'], '{space.4}');
      expect(HanjaTag.paddingStart, Space.s4);
      expect(pill['paddingEnd'], '{space.12}');
      expect(HanjaTag.paddingEnd, Space.s12);
      expect(pill['gap'], '{space.4}');
      expect(HanjaTag.gap, Space.s4);
      expect(_px(glyph['size']), HanjaTag.glyphSize);
      expect(_px(glyph['fontSize']), HanjaTag.glyphFontSize);
      expect(glyph['fontWeight'], 700);
      expect(glyph['bg'], '{color.bg.sheet}');
      expect(_map(parts['name'])['type'], '{type.label.md}');
      expect(_map(parts['name'])['maxLines'], 1);
    });

    test('selected 둘레 굵기와 skeleton 폭, 터치 영역이 계약과 같습니다', () {
      final selected = (tag['variants']! as List<Object?>)
          .map(_map)
          .firstWhere((v) => v['id'] == 'selected');
      final border = _map(_map(_map(selected['parts'])['pill'])['border']);
      expect(_px(border['width']), HanjaTag.selectedBorderWidth);
      expect(border['color'], '{color.action.primary}');
      final bone = _map(
        ((_map(_map(tag['states'])['loading'])['skeleton']!) as List<Object?>)
            .single,
      );
      expect('${HanjaTag.skeletonWidth.toInt()}px', bone['width']);
      expect(_num(_map(tag['a11y'])['minTarget']), 44);
    });

    testWidgets(
      '날의 성격 톤이 계약 tone.dayKind의 토큰과 같습니다 (default tag.*, emphasis badge.*)',
      (tester) async {
        final emphasis = _map(
          _map(
            (tag['variants']! as List<Object?>)
                .map(_map)
                .firstWhere((v) => v['id'] == 'emphasis')['parts'],
          )['tone'],
        );
        const toneOf = {
          'YONGSIN_DAY': HanjaTagTone.yongsin,
          'GWIIN_DAY': HanjaTagTone.gwiin,
          'GISIN_DAY': HanjaTagTone.gisin,
          'ORDINARY_DAY': HanjaTagTone.ordinary,
        };
        Color? colorOf(ColorTokens c, Object? ref) => switch (ref) {
          '{color.tag.good.bg}' => c.tagGoodBg,
          '{color.tag.good.fg}' => c.tagGoodFg,
          '{color.tag.bad.bg}' => c.tagBadBg,
          '{color.tag.bad.fg}' => c.tagBadFg,
          '{color.tag.neutral.border}' => c.tagNeutralBorder,
          '{color.tag.neutral.fg}' => c.tagNeutralFg,
          '{color.badge.good.bg}' => c.badgeGoodBg,
          '{color.badge.good.fg}' => c.badgeGoodFg,
          '{color.badge.gwiin.bg}' => c.badgeGwiinBg,
          '{color.badge.gwiin.fg}' => c.badgeGwiinFg,
          '{color.badge.gisin.bg}' => c.badgeGisinBg,
          '{color.badge.gisin.fg}' => c.badgeGisinFg,
          '{color.badge.ordinary.border}' => c.badgeOrdinaryBorder,
          '{color.badge.ordinary.fg}' => c.badgeOrdinaryFg,
          'transparent' => null,
          _ => fail('모르는 토큰 $ref'),
        };
        Future<void> check(
          Map<String, Object?> dayKinds,
          HanjaTagVariant variant,
        ) async {
          for (final MapEntry(key: kind, value: json) in dayKinds.entries) {
            final spec = _map(json);
            await tester.pumpWidget(
              inputApp(
                HanjaTag(
                  glyph: '用',
                  label: '이름',
                  tone: toneOf[kind]!,
                  variant: variant,
                ),
              ),
            );
            final c = tester
                .element(find.byKey(HanjaTag.surfaceKey))
                .tokens
                .colors;
            final box =
                tester
                        .widget<DecoratedBox>(find.byKey(HanjaTag.surfaceKey))
                        .decoration
                    as BoxDecoration;
            final reason = '$variant $kind';
            expect(box.color, colorOf(c, spec['bg']), reason: reason);
            expect(
              tester.widget<Text>(find.text('이름')).style!.color,
              colorOf(c, spec['fg']),
              reason: reason,
            );
            final border = spec['border'];
            expect(
              box.border,
              border == null
                  ? isNull
                  : Border.all(color: colorOf(c, _map(border)['color'])!),
              reason: reason,
            );
          }
        }

        await check(
          _map(_map(parts['tone'])['dayKind']),
          HanjaTagVariant.normal,
        );
        await check(_map(emphasis['dayKind']), HanjaTagVariant.emphasis);
      },
    );
  });

  group('오행 금과 수 테두리와 간지 한자색 (6.1.0, V98)', () {
    final elements = _elements();
    final cell = _map(elements['ohaeng.cell']);
    final cellBorder = _map(cell['border']);
    final cellBorderByElement = _map(cellBorder['byElement']);
    final specs = loadSpecComponents();

    /// 오행 칸, 간지 태그, 견본이 쓰는 토큰 참조 → [c]의 값.
    Color token(ColorTokens c, Object? ref) =>
        switch (ref) {
          '{color.ohaeng.wood.bg}' => c.ohaengWoodBg,
          '{color.ohaeng.wood.fg}' => c.ohaengWoodFg,
          '{color.ohaeng.wood.glyph}' => c.ohaengWoodGlyph,
          '{color.ohaeng.fire.bg}' => c.ohaengFireBg,
          '{color.ohaeng.fire.fg}' => c.ohaengFireFg,
          '{color.ohaeng.fire.glyph}' => c.ohaengFireGlyph,
          '{color.ohaeng.earth.bg}' => c.ohaengEarthBg,
          '{color.ohaeng.earth.fg}' => c.ohaengEarthFg,
          '{color.ohaeng.earth.glyph}' => c.ohaengEarthGlyph,
          '{color.ohaeng.metal.bg}' => c.ohaengMetalBg,
          '{color.ohaeng.metal.fg}' => c.ohaengMetalFg,
          '{color.ohaeng.metal.border}' => c.ohaengMetalBorder,
          '{color.ohaeng.metal.glyph}' => c.ohaengMetalGlyph,
          '{color.ohaeng.water.bg}' => c.ohaengWaterBg,
          '{color.ohaeng.water.fg}' => c.ohaengWaterFg,
          '{color.ohaeng.water.border}' => c.ohaengWaterBorder,
          '{color.ohaeng.water.glyph}' => c.ohaengWaterGlyph,
          '{color.swatch.border}' => c.swatchBorder,
          _ => null,
        } ??
        fail('모르는 토큰 $ref');

    /// 계약 [ref]가 있으면 그 색의 1px 테두리, 없으면 테두리 없음.
    Object expectedBorder(ColorTokens c, Object? ref) => ref == null
        ? isNull
        : Border.all(color: token(c, ref), width: _px(cellBorder['width']));

    BoxDecoration decorationIn(WidgetTester tester, Finder of) =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(of: of, matching: find.byType(DecoratedBox)),
                )
                .decoration
            as BoxDecoration;

    test('ohaeng.cell border: 금과 수만, 1px 안쪽, 라이트와 다크 토큰과 같습니다', () {
      expect(cellBorderByElement.keys, unorderedEquals(['metal', 'water']));
      expect(_px(cellBorder['width']), ohaengCellBorderWidth);
      expect(cellBorder['placement'], 'inside');
      for (final colors in [lightColors, darkColors]) {
        for (final element in FiveElement.values) {
          final ref = cellBorderByElement[element.value];
          expect(
            ohaengCellBorderOf(colors, element),
            ref == null ? isNull : token(colors, ref),
            reason: '${element.value} $ref',
          );
        }
      }
      // stem.chip은 ohaeng.cell 색을 테두리까지 따릅니다.
      expect(
        _map(elements['stem.chip'])['colorsRule'],
        contains('ohaeng.cell border'),
      );
    });

    testWidgets('ohaeng.cell 두 크기와 stem.chip이 계약 바탕색과 금, 수 테두리를 그립니다', (
      tester,
    ) async {
      final byElement = _map(cell['byElement']);
      for (final brightness in Brightness.values) {
        for (final element in FiveElement.values) {
          final widgets = <Widget>[
            OhaengCell(element: element, hanja: '甲', reading: '갑'),
            OhaengCell(
              element: element,
              hanja: '甲',
              size: OhaengCellSize.small,
            ),
            StemChip(element: element, hanja: '甲'),
          ];
          for (final widget in widgets) {
            await tester.pumpWidget(
              inputApp(Center(child: widget), brightness: brightness),
            );
            final of = find.byWidget(widget);
            final c = tester.element(of).tokens.colors;
            final box = decorationIn(tester, of);
            final reason = '$brightness ${element.value} ${widget.runtimeType}';
            expect(
              box.color,
              token(c, _map(byElement[element.value])['bg']),
              reason: reason,
            );
            expect(
              box.border,
              expectedBorder(c, cellBorderByElement[element.value]),
              reason: reason,
            );
          }
        }
      }
    });

    testWidgets(
      'hanja-tag ganji: 알약은 오행 bg, fg와 금, 수 테두리, 한자 원은 오행 glyph 색입니다',
      (tester) async {
        final ganji = _map(
          (specs['hanja-tag']!['variants']! as List<Object?>)
              .map(_map)
              .firstWhere((v) => v['id'] == 'ganji')['parts'],
        );
        final glyphFg = _map(_map(_map(ganji['glyph'])['fg'])['byElement']);
        final pillBorder = _map(_map(ganji['pill'])['border']);
        final pillBorderByElement = _map(pillBorder['byElement']);
        final tone = _map(_map(ganji['tone'])['byElement']);
        expect(_px(pillBorder['width']), ohaengCellBorderWidth);
        expect(pillBorder['placement'], 'inside');
        // 알약 테두리는 ohaeng.cell 테두리와 같은 토큰입니다.
        expect(pillBorderByElement, cellBorderByElement);
        final glyphs = _map(ganji['ganjiGlyphs']);
        for (final brightness in Brightness.values) {
          for (final group in glyphs.values) {
            for (final MapEntry(key: hanja, value: element) in _map(
              group,
            ).entries) {
              await tester.pumpWidget(
                inputApp(
                  HanjaTag(
                    glyph: hanja,
                    label: '이름',
                    variant: HanjaTagVariant.ganji,
                  ),
                  brightness: brightness,
                ),
              );
              final c = tester
                  .element(find.byKey(HanjaTag.surfaceKey))
                  .tokens
                  .colors;
              final box =
                  tester
                          .widget<DecoratedBox>(find.byKey(HanjaTag.surfaceKey))
                          .decoration
                      as BoxDecoration;
              final reason = '$brightness $hanja $element';
              final pill = _map(tone[element]);
              expect(box.color, token(c, pill['bg']), reason: reason);
              expect(
                tester.widget<Text>(find.text('이름')).style!.color,
                token(c, pill['fg']),
                reason: reason,
              );
              expect(
                tester.widget<Text>(find.text(hanja)).style!.color,
                token(c, glyphFg[element]),
                reason: reason,
              );
              expect(
                box.border,
                expectedBorder(c, pillBorderByElement[element]),
                reason: reason,
              );
            }
          }
        }
      },
    );

    testWidgets('ohaeng-bar: 막대 칸과 범례 견본에 1px 안쪽 swatch.border를 둡니다', (
      tester,
    ) async {
      final parts = _map(specs['ohaeng-bar']!['parts']);
      final segmentBorder = _map(_map(parts['bar'])['segmentBorder']);
      expect(segmentBorder['color'], '{color.swatch.border}');
      expect(_px(segmentBorder['width']), OhaengBar.segmentBorderWidth);
      expect(segmentBorder['placement'], 'inside');
      expect(_map(parts['swatch'])['element'], 'ohaeng.swatch');
      final swatchBorder = _map(_map(elements['ohaeng.swatch'])['border']);
      expect(swatchBorder['color'], '{color.swatch.border}');

      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          inputApp(
            OhaengBar(
              items: [
                for (final element in FiveElement.values)
                  OhaengBarItem(
                    element: element,
                    name: element.value,
                    value: 1,
                    count: '1',
                  ),
              ],
              semanticLabel: '오행',
            ),
            brightness: brightness,
          ),
        );
        final c = tester.element(find.byType(OhaengBar)).tokens.colors;
        final expected = Border.all(
          color: token(c, segmentBorder['color']),
          width: _px(segmentBorder['width']),
        );
        for (final element in FiveElement.values) {
          final box =
              tester
                      .widget<DecoratedBox>(
                        find.byKey(OhaengBar.segmentKey(element)),
                      )
                      .decoration
                  as BoxDecoration;
          expect(box.border, expected, reason: '$brightness ${element.value}');
        }
        final swatches = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(OhaengBar),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.shape == BoxShape.circle)
            .toList();
        expect(swatches, hasLength(FiveElement.values.length));
        for (final swatch in swatches) {
          expect(
            swatch.border,
            Border.all(
              color: token(c, swatchBorder['color']),
              width: _px(swatchBorder['width']),
            ),
            reason: '$brightness legend',
          );
        }
      }
    });
  });

  group('share-image 로고 애셋 (6.1.1, V99)', () {
    test(
      'logo.asset의 파일명이 ShareImage.logoAsset과 같고 앱 애셋이 design 원본과 같은 바이트입니다',
      () {
        final shareImage = loadSpecComponents()['share-image']!;
        final asset =
            _map(_map(shareImage['parts'])['logo'])['asset']! as String;
        expect(asset, endsWith('.png'));
        final contractName = asset.split('/').last;
        expect(ShareImage.logoAsset.split('/').last, contractName);
        expect(ShareImage.logoAsset, endsWith('myungli/$contractName'));
        // 계약 경로는 design 디렉터리 기준(`logo/lockup.png`)입니다.
        final original = File('$componentsDir/../$asset');
        expect(original.existsSync(), isTrue, reason: original.path);
        expect(
          File(ShareImage.logoAsset).readAsBytesSync(),
          original.readAsBytesSync(),
        );
      },
    );
  });

  group('일기 줄 태그 줄과 질문 떼기 (6.2.0, V102, V103, D115, D116)', () {
    final specs = loadSpecComponents();

    Map<String, Object?> editQuestion() => _map(
      _map(
        _map(
          (specs['diary-editor']!['variants']! as List<Object?>)
              .map(_map)
              .firstWhere((v) => v['id'] == 'edit'),
        )['parts'],
      )['question'],
    );

    test('diary-row tag: 그날 태그 모두, 순위 순, 사이 space.8, 한 줄 가로 밀기와 흐림만', () {
      final tag = _map(_map(specs['diary-row']!['parts'])['tag']);
      expect(tag['component'], 'hanja-tag');
      expect(tag['variant'], 'default');
      expect(tag['count'], 'all');
      expect(tag['order'], '대표 태그 순위');
      expect(tag['gap'], '{space.8}');
      expect(DiaryRow.tagsGap, Space.s8);
      expect(tag['whenMissing'], 'hide');
      final row = _map(tag['row']);
      expect(row['lines'], 1);
      expect(row['wrap'], false);
      final hint = _map(row['hint']);
      expect(hint['component'], 'scroll-hint');
      expect(_map(_map(hint['parts'])['arrows'])['visible'], false);
      expect(hint['fadeTo'], '{color.bg.sheet}');
      final scrollHint = specs['scroll-hint']!;
      final fade = _map(_map(scrollHint['parts'])['fade']);
      expect(_px(fade['width']), ScrollHint.fadeWidth);
      expect(fade['to'], hint['fadeTo']);
      // 모아보기 안에서는 모아 본 그 태그만 숨깁니다.
      expect(tag['hiddenIn'], ['tag-diary']);
      expect(tag['hiddenScope'], startsWith('모아 본 그 태그만'));
    });

    testWidgets('diary-row tag count all, order: 받은 태그 모두를 받은 순서대로 그립니다', (
      tester,
    ) async {
      final tag = _map(_map(specs['diary-row']!['parts'])['tag']);
      expect((tag['count'], tag['order']), ('all', '대표 태그 순위'));
      const labels = ['천을귀인', '합', '도화', '역마', '화개', '공망'];
      const glyphs = ['貴', '合', '桃', '驛', '華', '空'];
      await _contractCheckWidgets('diary-row tag count', () async {
        await tester.pumpWidget(
          inputApp(
            SizedBox(
              width: 360,
              child: DiaryRow(
                date: CalendarDate(2026, 10, 12),
                excerpt: '글',
                tags: [
                  for (var i = 0; i < labels.length; i++)
                    HanjaTag(glyph: glyphs[i], label: labels[i]),
                ],
                onTap: () {},
              ),
            ),
          ),
        );
        final drawn = tester.widgetList<HanjaTag>(
          find.descendant(
            of: find.byKey(DiaryRow.tagsKey),
            matching: find.byType(HanjaTag),
          ),
        );
        expect(drawn.map((t) => t.label), labels);
      });
    });

    testWidgets('diary-editor remove, detached 아이콘 이름과 굵기, 크기가 그린 글리프와 같습니다', (
      tester,
    ) async {
      final question = editQuestion();
      final remove = _map(question['remove']);
      final icon = _map(_map(question['detached'])['trailingIcon']);
      // 명세 이름과 굵기(light) → 그린 Phosphor Light 글리프.
      const lightGlyphs = {
        'x': PhosphorIconsLight.x,
        'chat-teardrop-dots': PhosphorIconsLight.chatTeardropDots,
      };
      expect((remove['weight'], icon['weight']), ('light', 'light'));
      await _contractCheckWidgets('diary-editor guide icons', () async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        Widget editor({required bool detached}) => inputApp(
          SingleChildScrollView(
            child: DiaryEditor.edit(
              date: CalendarDate(2026, 10, 13),
              controller: controller,
              question: RenderedText(segments: [Segment(text: '질문')]),
              questionDetached: detached,
              onDetachQuestion: () {},
              onAttachQuestion: () {},
            ),
          ),
        );
        await tester.pumpWidget(editor(detached: false));
        final x = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(DiaryEditor.removeKey),
            matching: find.byType(Icon),
          ),
        );
        expect(x.icon, lightGlyphs[remove['icon']]);
        expect(x.size, _iconSize(remove['size']).logical);

        await tester.pumpWidget(editor(detached: true));
        await tester.pumpAndSettle();
        final bubble = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(DiaryEditor.detachedIconKey),
            matching: find.byType(Icon),
          ),
        );
        expect(bubble.icon, lightGlyphs[icon['icon']]);
        expect(icon['size'], 'adjacent-text');
        expect(
          bubble.size,
          AppIconSize.adjacentText(_px(_map(question['detached'])['fontSize']))
              .logical,
        );
      });
    });

    test('diary-editor question: 인용 세로선은 action.primary(V102)', () {
      final question = _map(_map(specs['diary-editor']!['parts'])['question']);
      expect(_map(question['quoteLine'])['color'], '{color.action.primary}');
      expect(
        _px(_map(question['quoteLine'])['width']),
        DiaryEditor.quoteLineWidth,
      );
      expect(question['marginBottom'], '{space.16}');
    });

    test(
      'diary-editor edit remove: x Light 20 text.secondary, 터치 44, 바꾸기 바로 뒤',
      () {
        final question = editQuestion();
        final swap = _map(question['swap']);
        expect(swap['marginStart'], '{space.8}');
        expect(DiaryEditor.questionActionsGap, Space.s8);
        final remove = _map(question['remove']);
        expect(remove['slot'], SlotIds.diaryEditGuideRemove);
        expect(remove['icon'], 'x');
        expect(remove['weight'], 'light');
        expect(_iconSize(remove['size']), AppIconSize.s20);
        expect(remove['color'], '{color.text.secondary}');
        expect(remove['minTarget'], DiaryEditor.removeTarget);
        expect(remove['align'], 'first-line');
        expect(_map(remove['transition']), {
          'out': InteractionPattern.disappearSeep.id,
          'in': InteractionPattern.appearSeep.id,
        });
        expect(remove['keepsBody'], true);
      },
    );

    test('diary-editor edit detached: 글꼴 14 invite.fg, 선 없음, 말풍선 4, 터치 44', () {
      final detached = _map(editQuestion()['detached']);
      expect(detached['slot'], SlotIds.diaryEditGuideAttach);
      expect(detached['type'], '{type.sentence.body}');
      expect(_px(detached['fontSize']), DiaryEditor.questionFontSize);
      expect(detached['fg'], '{color.invite.fg}');
      expect(_map(detached['quoteLine'])['visible'], false);
      expect(detached['paddingStart'], 0);
      final icon = _map(detached['trailingIcon']);
      expect(icon['icon'], 'chat-teardrop-dots');
      expect(icon['weight'], 'light');
      expect(icon['size'], 'adjacent-text');
      expect(icon['color'], '{color.invite.fg}');
      expect(icon['gap'], '{space.4}');
      expect(DiaryEditor.detachedIconGap, Space.s4);
      expect(icon['decorative'], true);
      expect(detached['minTarget'], DiaryEditor.detachedMinHeight);
      expect(detached['pressable'], '줄 전체');
    });

    test(
      'diary-editor guideStates: 붙음과 뗌 두 상태, 전환 두 개, 앞 disappear 새 appear',
      () {
        final states = _map(editQuestion()['guideStates']);
        expect(states.keys, containsAll(['initial', 'attached', 'detached']));
        expect(_map(states['detached'])['shows'], ['detached']);
        expect(
          (states['transitions']! as List<Object?>).map(
            (t) => (_map(t)['from'], _map(t)['to']),
          ),
          [('attached', 'detached'), ('detached', 'attached')],
        );
        expect(
          specs['diary-editor']!['uses'],
          containsAll([
            InteractionPattern.appearSeep.id,
            InteractionPattern.disappearSeep.id,
          ]),
        );
        expect(InteractionPattern.disappearSeep.duration.inMilliseconds, 200);
        expect(InteractionPattern.appearSeep.duration.inMilliseconds, 320);
      },
    );
  });

  group('그날 시트와 피드백 아이콘 (6.2.0, V101, V105, V107~V109)', () {
    final specs = loadSpecComponents();

    /// [id]의 변형 [variant] parts.
    Map<String, Object?> variantParts(String id, String variant) => _map(
      (specs[id]!['variants']! as List<Object?>)
          .map(_map)
          .singleWhere((v) => v['id'] == variant)['parts'],
    );

    test(
      'event-row list: 시각 본문색 700, 줄 위아래 space.12, 메모 한 줄, 종일 꼬리표(V107)',
      () {
        final list = variantParts('event-row', 'list');
        final time = _map(list['timeColumn']);
        expect(time['fg'], '{color.text.primary}');
        expect(_num(time['fontWeight']).toInt(), EventRow.listTimeWeight.value);
        final row = _map(list['row']);
        expect(row['paddingY'], '{space.12}');
        expect(EventRow.rowPaddingY, Space.s12);
        expect(row['align'], 'first-line');
        final memo = _map(list['memo']);
        expect(memo['source'], 'Schedule.memo');
        expect(memo['type'], '{type.caption.lg}');
        expect(memo['fg'], '{color.text.secondary}');
        expect(memo['maxLines'], 1);
        expect(memo['overflow'], 'ellipsis');
        expect(memo['marginTop'], '{space.2}');
        expect(EventRow.memoGap, Space.s2);
        expect(memo['whenEmpty'], 'hide');
        final allDay = _map(list['allDay']);
        expect(allDay['element'], 'tag.status');
        expect(allDay['slot'], SlotIds.daySheetEventAllDay);
      },
    );

    test('fortune-verdict: 카드 누름, 안내 줄, 접힘과 펼침 상태 값(V108)', () {
      final verdict = specs['fortune-verdict']!;
      expect(
        verdict['uses'],
        containsAll(['press.ink', 'appear.seep', 'disappear.seep']),
      );
      final parts = _map(verdict['parts']);
      final pressable = _map(_map(parts['card'])['pressable']);
      expect(pressable['pattern'], 'press.ink');
      expect(_num(pressable['minTarget']), FortuneVerdict.toggleMinHeight);
      final rows = _map(parts['rows']);
      expect(rows['marginTop'], '{space.12}');
      expect(FortuneVerdict.rowsGap, Space.s12);
      expect(rows['visibleWhen'], 'expanded');
      final toggle = _map(parts['toggle']);
      final label = _map(toggle['label']);
      expect(label['collapsed'], contains(SlotIds.daySheetVerdictExpand));
      expect(label['expanded'], contains(SlotIds.daySheetVerdictCollapse));
      expect(toggle['type'], '{type.caption.lg}');
      expect(toggle['fg'], '{color.text.secondary}');
      expect(_num(toggle['minHeight']), FortuneVerdict.toggleMinHeight);
      expect(toggle['marginTop'], '{space.8}');
      expect(FortuneVerdict.toggleGap, Space.s8);
      expect(_map(toggle['dividerBefore'])['element'], 'list.divider');
      final icon = _map(toggle['icon']);
      expect(icon['collapsed'], 'caret-down');
      expect(icon['expanded'], 'caret-up');
      expect(icon['weight'], 'regular');
      expect(icon['size'], 'adjacent-text');
      expect(icon['color'], '{color.text.secondary}');
      expect(icon['gap'], '{space.4}');
      expect(FortuneVerdict.toggleIconGap, Space.s4);

      final states = _map(verdict['states']);
      expect(_map(states['collapsed'])['initial'], isTrue);
      for (final id in ['noBreakdown', 'noItems']) {
        final state = _map(states[id]);
        expect(state['pressable'], isFalse, reason: id);
        expect(
          _map(_map(state['parts'])['toggle'])['visible'],
          isFalse,
          reason: id,
        );
      }
      final loading = _map(states['loading']);
      final bones = [
        for (final bone in loading['skeleton']! as List<Object?>)
          _map(bone)['bone'],
      ];
      expect(bones, ['track']);
      expect(_map(_map(loading['parts'])['toggle'])['visible'], isFalse);
      final a11y = _map(_map(verdict['a11y'])['toggle']);
      expect(a11y['role'], 'button');
      expect(a11y['expandedState'], isTrue);
    });

    testWidgets('fortune-verdict: 안내 줄 꺾쇠 글리프와 크기가 계약과 같습니다', (tester) async {
      await tester.pumpWidget(
        inputApp(
          SizedBox(
            width: 360,
            child: FortuneVerdict(
              score: 1,
              items: [ScoreItem(id: 'hap', score: 1)],
              nameOf: (_) => '합',
              meaningOf: (_) => null,
            ),
          ),
        ),
      );
      Icon toggleIcon() => tester.widget<Icon>(
        find.descendant(
          of: find.byKey(FortuneVerdict.toggleKey),
          matching: find.byType(Icon),
        ),
      );
      final type = tester
          .element(find.byType(FortuneVerdict))
          .tokens
          .typography;
      expect(toggleIcon().icon, PhosphorIconsRegular.caretDown);
      expect(
        toggleIcon().size,
        AppIconSize.adjacentText(type.captionLg.fontSize!).logical,
      );
      await tester.tap(find.byKey(FortuneVerdict.toggleKey));
      await tester.pumpAndSettle();
      expect(toggleIcon().icon, PhosphorIconsRegular.caretUp);
    });

    test(
      'date-header day-sheet trailing: hanja-tag emphasis, space.12(V109)',
      () {
        final trailing = _map(
          variantParts('date-header', 'day-sheet')['trailing'],
        );
        expect(trailing['component'], 'hanja-tag');
        expect(trailing['variant'], 'emphasis');
        expect(trailing['slot'], SlotIds.daySheetCharacterLabel);
        expect(trailing['gapStart'], '{space.12}');
        expect(DateHeader.trailingGap, Space.s12);
      },
    );

    test('band-table 빈 칸 선 상자: 위 space.8, 지장간 22, 상자 가운데(V101)', () {
      final parts = _map(specs['band-table']!['parts']);
      final cell = _map(parts['cell']);
      expect(cell['paddingTop'], '{space.8}');
      expect(cell['paddingBottom'], '{space.12}');
      expect(BandTable.cellPaddingTop, Space.s8);
      expect(BandTable.cellPaddingBottom, Space.s12);
      final empty = _map(parts['empty']);
      expect(_px(empty['width']), BandTable.emptyLineWidth);
      expect(_px(empty['height']), BandTable.emptyLineHeight);
      expect(empty['verticalAlign'], 'box-center');
      final box = _map(empty['box']);
      expect(box['offsetTop'], '{space.8}');
      final heights = _map(box['heightByBand']);
      expect(_px(heights['hiddenStems']), BandTable.emptyBoxStemHeight);
      expect(
        heights.keys,
        unorderedEquals([for (final kind in BandKind.values) kind.name]),
      );
    });

    test('error-state, notice-banner 변형 아이콘이 계약 이름과 같습니다(V105)', () {
      const lightIcons = <String, IconData>{
        'warning-circle': PhosphorIconsLight.warningCircle,
        'wifi-slash': PhosphorIconsLight.wifiSlash,
        'clock': PhosphorIconsLight.clock,
        'note-pencil': PhosphorIconsLight.notePencil,
      };
      Map<String, String> iconNames(String id) => {
        for (final variant in (specs[id]!['variants']! as List<Object?>).map(
          _map,
        ))
          variant['id']! as String:
              _map(_map(variant['parts'])['icon'])['name']! as String,
      };
      final errorState = iconNames('error-state');
      expect(errorState['generic'], 'warning-circle');
      for (final variant in ErrorStateVariant.values) {
        expect(
          variant.glyph.light,
          lightIcons[errorState[variant.name]],
          reason: 'error-state ${variant.name}',
        );
      }
      final banner = iconNames('notice-banner');
      expect(banner['error'], 'warning-circle');
      for (final variant in NoticeBannerVariant.values) {
        final contractId = switch (variant) {
          NoticeBannerVariant.timeUnknown => 'time-unknown',
          _ => variant.name,
        };
        expect(
          variant.glyph.light,
          lightIcons[banner[contractId]],
          reason: 'notice-banner $contractId',
        );
      }
    });
  });

  group('loading skeleton 뼈 대조 (6.0.0, V66)', () {
    final specs = loadSpecComponents();

    /// 컴포넌트 [id]의 `states.loading.skeleton` 뼈를 bone 이름별로 읽습니다.
    Map<String, Map<String, Object?>> bones(String id) => {
      for (final bone
          in _map(_map(specs[id]!['states'])['loading'])['skeleton']!
              as List<Object?>)
        _map(bone)['bone']! as String: _map(bone),
    };

    /// `"72px"` → 72.
    double px(Object? text) =>
        double.parse((text! as String).replaceFirst('px', ''));

    /// `"60%"` → 0.6.
    double percent(Object? text) =>
        double.parse((text! as String).replaceFirst('%', '')) / 100;

    test('뼈가 있는 계약 컴포넌트는 모두 등록됐거나 대기 목록에 있고 loading 상태를 냅니다', () {
      final withBones = {
        for (final MapEntry(:key, :value) in specs.entries)
          if (_map(value['states'] ?? <String, Object?>{})['loading']
              case final Map<String, Object?> loading
              when loading.containsKey('skeleton'))
            key,
      };
      for (final spec in implementedComponents) {
        if (!withBones.contains(spec.id)) continue;
        if (knownPendingChecks.containsKey('${spec.id} spec')) continue;
        expect(spec.states, contains('loading'), reason: spec.id);
      }
    });

    test('day-character: 배지 칩 72px, 이유 글줄 80%', () {
      final b = bones('day-character');
      expect(b['badge']!['shape'], 'chip');
      expect(px(b['badge']!['width']), DayCharacter.skeletonBadgeWidth);
      expect(b['reason']!['shape'], 'textLine');
      expect(b['reason']!['lines'], 1);
      expect(
        percent(b['reason']!['width']),
        DayCharacter.skeletonReasonWidthFactor,
      );
    });

    test('lucky-card: 칩 셋 72, 56, 64px, 사이 space.8', () {
      final chip = bones('lucky-card')['chip']!;
      expect(chip['shape'], 'chip');
      expect(chip['count'], LuckyCardRow.skeletonChipWidths.length);
      expect([
        for (final width in chip['widths']! as List<Object?>) px(width),
      ], LuckyCardRow.skeletonChipWidths);
      expect(chip['gap'], '{space.8}');
    });

    test('lucky-card: 칩 안 간격 space.4, 테두리 1px와 열림 1.5px', () {
      final spec = loadSpecComponents()['lucky-card']!;
      final chip = _map(_map(spec['parts'])['chip']);
      expect(chip['gap'], '{space.4}');
      expect(Space.s4, 4);
      expect(_px(_map(_map(chip['border'])['width'])), 1);
      expect(chip['bg'], '{color.bg.sheet}');
    });

    test('tag-sentence-list: diaryLink 간격과 꺾쇠 gap이 구현 상수와 같습니다', () {
      final spec = loadSpecComponents()['tag-sentence-list']!;
      final link = _map(_map(spec['parts'])['diaryLink']);
      expect(link['marginTop'], '{space.16}');
      expect(TagSentenceList.diaryLinkGap, Space.s16);
      expect(_map(link['chevron'])['gap'], '{space.2}');
      expect(TagSentenceList.chevronGap, Space.s2);
      expect(_map(link['label'])['type'], '{type.label.lg}');
      expect(_map(link['label'])['fg'], '{color.action.primary}');
      expect(link['minTarget'], 44);
    });

    test('offer-card: 카드, 아이콘 원 28, 머리 60%, 가격 40%', () {
      final b = bones('offer-card');
      expect(b['container']!['shape'], 'card');
      expect(b['icon']!['shape'], 'circle');
      expect(_iconSize(b['icon']!['size']).logical, OfferCard.iconSize);
      expect(percent(b['head']!['width']), OfferCard.skeletonHeadWidthFactor);
      expect(percent(b['price']!['width']), OfferCard.skeletonPriceWidthFactor);
    });

    test('guide-question-card: 카드, 머리 40%, 질문 두 줄, 버튼 52px', () {
      final b = bones('guide-question-card');
      expect(b['container']!['shape'], 'card');
      expect(
        percent(b['header']!['width']),
        GuideQuestionCard.skeletonHeaderWidthFactor,
      );
      expect(
        b['question']!['lines'],
        SentenceBlock.skeletonLines(SentenceBlockVariant.card),
      );
      expect(b['action']!['shape'], 'button');
      expect(px(b['action']!['height']), PrimaryButtonVariant.filled.height);
    });

    test('purchase-row: 상품 글줄, 구매일과 사용 기간 60%', () {
      final b = bones('purchase-row');
      expect(b.keys, ['product', 'purchased', 'period']);
      expect(b['product']!['shape'], 'textLine');
      for (final id in ['purchased', 'period']) {
        expect(
          percent(b[id]!['width']),
          PurchaseRowGroup.skeletonMetaWidthFactor,
          reason: id,
        );
      }
    });

    test('diary-row: 날의 성격 칩 88px, 미리보기 두 줄, 태그 칩 72px, entry 두 줄', () {
      final b = bones('diary-row');
      expect(b, isNot(contains('badge')));
      expect(px(b['dayKind']!['width']), DiaryRowSkeleton.dayKindBoneWidth);
      expect(px(b['tag']!['width']), DiaryRowSkeleton.tagBoneWidth);
      expect(
        b['preview']!['lines'],
        SentenceBlock.skeletonLines(SentenceBlockVariant.preview),
      );
      expect(b['entry']!['rows'], 2);
    });

    test('diary-editor: edit 질문 두 줄, 종이 카드, 본문 다섯 줄', () {
      final b = bones('diary-editor');
      expect(b['question']!['variant'], 'edit');
      expect(b['question']!['lines'], DiaryEditor.skeletonQuestionLines);
      expect(b['paper']!['shape'], 'card');
      expect(b['body']!['lines'], DiaryEditor.skeletonBodyLines);
    });

    test('event-row: summary 글줄 한 줄, list 줄 둘', () {
      final b = bones('event-row');
      expect(b['summary']!['variant'], 'summary');
      expect(b['summary']!['lines'], 1);
      expect(b['row']!['variant'], 'list');
      expect(b['row']!['rows'], EventRow.skeletonListRows);
    });

    test('sentence-block: 변형별 줄 수 card 2, body 3, preview 2', () {
      final lines = bones('sentence-block')['text']!['lines']! as String;
      for (final variant in SentenceBlockVariant.values) {
        final match = RegExp('${variant.name} (\\d+)').firstMatch(lines);
        expect(
          int.parse(match!.group(1)!),
          SentenceBlock.skeletonLines(variant),
          reason: variant.name,
        );
      }
    });

    test('saju-pillars: 뼈는 칸(cells)뿐이고 머리 글자는 바로 그립니다', () {
      final b = bones('saju-pillars');
      expect(b.keys, ['cells']);
      expect(b['cells']!['note'], '머리 글자는 바로');
    });

    testWidgets('saju-pillars: 머리 네 글자는 실제 글자, 뼈는 기둥마다 칸 둘', (tester) async {
      await tester.pumpWidget(inputApp(const SajuPillarsSkeleton()));
      final l10n = lookupAppLocalizations(const Locale('ko'));
      for (final header in [
        l10n.sajuPillarHour,
        l10n.sajuPillarDay,
        l10n.sajuPillarMonth,
        l10n.sajuPillarYear,
      ]) {
        expect(find.text(header), findsOneWidget, reason: header);
      }
      final bones = tester.widgetList<SkeletonBone>(find.byType(SkeletonBone));
      expect(bones, hasLength(4 * 2));
      for (final bone in bones) {
        expect(bone.height, OhaengCell.pillarHeight);
      }
    });

    test('diary-row: 한 편 카드 태그 위 space.12, 묶음 카드 space.8', () {
      final parts = _map(specs['diary-row']!['parts']);
      expect(_map(parts['tag'])['marginTop'], '{space.12}');
      expect(DiaryRow.tagMarginTop, Space.s12);
    });

    test('ohaeng-bar: 막대 전체 폭과 범례 글줄 한 줄', () {
      final b = bones('ohaeng-bar');
      expect(b.keys, ['bar', 'legend']);
      expect(b['legend']!['lines'], 1);
    });

    test('luck-pillar: 뼈는 칸 둘(ohaeng.cell 칸)과 십성 칩 36, 변형 column, compact', () {
      final b = bones('luck-pillar');
      expect(b.keys, ['cells', 'tenGods']);
      expect(b['cells']!['count'], 2);
      expect(b['tenGods']!['width'], '36px');
      expect(LuckPillar.spec.variants, {'column', 'compact'});
    });

    testWidgets('각 컴포넌트 뼈가 계약 뼈 수만큼 그립니다', (tester) async {
      Future<int> count(Widget skeleton) async {
        await tester.pumpWidget(
          inputApp(SingleChildScrollView(child: skeleton)),
        );
        return tester.widgetList(find.byType(SkeletonBone)).length;
      }

      // 칩, 글줄 한 줄.
      expect(await count(DayCharacter.skeleton()), 2);
      expect(await count(LuckyCardRow.skeleton()), 3);
      // 아이콘 원, 머리, 가격(카드 바탕은 뼈가 아님).
      expect(await count(OfferCard.skeleton()), 3);
      // 머리, 질문 두 줄, 버튼.
      expect(await count(GuideQuestionCard.skeleton()), 4);
      expect(await count(const PurchaseRowGroup.loading()), 3 * 3);
      expect(
        await count(DiaryEditor.skeleton(variant: DiaryEditorVariant.edit)),
        2 + 5,
      );
      expect(
        await count(DiaryEditor.skeleton(variant: DiaryEditorVariant.view)),
        5,
      );
      expect(
        await count(EventRow.skeleton(variant: EventRowVariant.summary)),
        1,
      );
      expect(
        await count(EventRow.skeleton(variant: EventRowVariant.list)),
        2 * 2,
      );
      expect(await count(OhaengBar.skeleton()), 2);
      // 칸 둘, 십성 칩.
      expect(await count(LuckPillar.skeleton()), 3);
      for (final variant in SentenceBlockVariant.values) {
        expect(
          await count(SentenceBlock.skeleton(variant: variant)),
          SentenceBlock.skeletonLines(variant),
          reason: variant.name,
        );
      }
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
      // 6.3.0: 아래 시트 이동은 수치가 아니라 peek 규칙(머리 14px)입니다.
      expect(sheet['translateY'], 'peek');
      expect(_px(_map(stack['peek'])['height']), PatternValues.stackPeekHeight);
      expect(_num(sheet['scale']), PatternValues.stackSheetScale);
      expect(_num(sheet['brightness']), PatternValues.stackSheetBrightness);
      expect(stack['properties'], ['translateY', 'brightness-overlay']);

      // tab.switch: 겹쳐 투명도만(이동 없음), 앞 1→0, 새 0→1(V104).
      final tab = p('tab.switch');
      expect(_map(tab['outgoing'])['opacity'], [1, 0]);
      expect(_map(tab['incoming'])['opacity'], [0, 1]);
      expect(tab['together'], isTrue);
      expect(tab['movement'], 'none');

      final push = p('page.push');
      final enter = _map(push['enter']);
      // 오른쪽 motion.offset.page(24)에서 0으로, 투명도 0에서 1로.
      final translateX = enter['translateX']! as List<Object?>;
      expect(translateX.first, '{motion.offset.page}');
      expect(_num(translateX.last), 0);
      expect(enter['opacity'], [0, 1]);
      expect(push['below'], 'still');
      expect(push['back'], 'reverse');

      final focus = p('focus.ring');
      expect(
        _px(_map(focus['from'])['borderWidth']),
        PatternValues.focusFromWidth,
      );
      expect(_px(_map(focus['to'])['borderWidth']), PatternValues.focusToWidth);
    });
  });
}
