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
import 'package:myungli_diary/design/components/action/offer_card.dart';
import 'package:myungli_diary/design/components/action/purchase_row.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/calendar/calendar_month.dart';
import 'package:myungli_diary/design/components/calendar/day_cell.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/input/account_choice.dart';
import 'package:myungli_diary/design/components/input/city_search.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/sentence/link_label.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
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

    test('명세 묶음에서 IA 컴포넌트 43개를 읽습니다', () {
      expect(specs, hasLength(43));
    });

    test('43개 전체의 variants·states 형태가 기대와 같습니다', () {
      for (final component in specs.values) {
        // variantIds·stateKeys가 형태(list/null, 문자열 id, dict/null)를 assert합니다.
        variantIds(component);
        stateKeys(component);
      }
    });

    test('명세 JSON에서 만든 ComponentSpec은 대조를 통과합니다(43개)', () {
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
      expect(_px(state['size']), SocialLoginButton.connectedIconSize);
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
      expect(_px(chevron['size']), DiaryEntryLine.chevronSize);
      expect(chevron['fg'], '{color.text.secondary}');
      expect(entry['paddingY'], '{space.12}');
      expect(DiaryEntryLine.paddingY, Space.s12);
      expect(_px(entry['minHeight']), DiaryEntryLine.minHeight);
    });

    test('diary-row entry 점선은 1px 대시 4 간격 3이고 줄 사이에만 있습니다', () {
      final divider = _map(_map(rowParts()['entry'])['divider']);
      expect(divider['style'], 'dashed');
      expect(_px(divider['width']), DiaryEntryLine.dividerWidth);
      expect(_px(divider['dash']), DiaryEntryLine.dividerDash);
      expect(_px(divider['gap']), DiaryEntryLine.dividerGap);
      expect(divider['color'], '{color.timeline.entry}');
      expect(divider['between'], 'entries-only');
      expect(divider['span'], 'row');
      expect(divider['inMinHeight'], true);
    });

    test('diary-row day 묶음 카드 간격과 눌림 규칙이 명세와 같습니다', () {
      final group = _map(variantParts('day')['group']);
      expect(group['pressable'], false);
      expect(group['order'], ['badge', 'entries', 'tag']);
      expect(group['entriesMarginTop'], '{space.4}');
      expect(DiaryRow.entriesMarginTop, Space.s4);
      expect(_map(group['tag'])['marginTop'], '{space.8}');
      expect(DiaryRow.groupTagMarginTop, Space.s8);
      expect(_map(group['preview'])['visible'], false);
    });

    test('diary-row entries 오늘 바탕과 그날 시트 머리가 명세와 같습니다', () {
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
      final head = _map(parts['head']);
      expect(head['screens'], ['day-sheet']);
      expect(head['type'], '{type.label.md}');
      expect(head['fg'], '{color.text.secondary}');
      expect(head['marginTop'], '{space.16}');
      expect(DiaryEntries.headMarginTop, Space.s16);
      expect(head['marginBottom'], '{space.4}');
      expect(DiaryEntries.headMarginBottom, Space.s4);
    });

    test(
      'guide-question-card full은 quiet disabled 버튼과 52 도장, 낭독은 after와 같습니다',
      () {
        final component = specs['guide-question-card']!;
        expect(stateKeys(component), {'before', 'after', 'full'});
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

    test('offer-card 부품 값(바탕·radius·padding·아이콘 sparkle 28·간격 12/16/20/12)이 명세와 같다', () {
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
      expect(_px(icon['size']), OfferCard.iconSize);
      expect(OfferCard.iconSize, AppIconSize.state.logical);
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
      expect(_map(parts['buy'])['marginTop'], '{space.20}');
      expect(OfferCard.buyGap, Space.s20);
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
      final divider = _map(row['divider']);
      expect(divider['color'], '{color.line}');
      expect(_px(divider['width']), 1);
      expect(divider['between'], 'rows-only');

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
