import 'dart:convert';
import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart' show IconData, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/social_login_button.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/components/frame/tab_bar.dart';
import 'package:myungli_diary/design/components/sentence/link_label.dart';
import 'package:myungli_diary/design/components/sentence/sentence_block.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';

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
