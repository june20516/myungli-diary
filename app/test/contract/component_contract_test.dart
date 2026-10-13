import 'dart:convert';
import 'dart:io';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/ia_model.dart';
import 'package:myungli_diary/design/components/component_spec.dart';
import 'package:myungli_diary/design/interaction/patterns.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

const _componentsDir = '../docs/identity/design/components';

/// 컴포넌트 명세 묶음 파일(상호작용·요소 제외)을 읽어 id별 JSON으로 모읍니다.
Map<String, Map<String, Object?>> _specComponents() {
  final result = <String, Map<String, Object?>>{};
  final files = Directory(_componentsDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .where(
        (f) =>
            !f.path.endsWith('interaction.json') &&
            !f.path.endsWith('elements.json'),
      );
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    for (final component in json['components']! as List<Object?>) {
      final map = component! as Map<String, Object?>;
      result[map['id']! as String] = map;
    }
  }
  return result;
}

Map<String, Object?> _interaction() =>
    jsonDecode(File('$_componentsDir/interaction.json').readAsStringSync())
        as Map<String, Object?>;

/// 토큰 참조 `{motion.duration.stamp}`를 생성 코드의 값으로 풉니다.
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

void main() {
  group('ComponentSpec 대조', () {
    final specs = _specComponents();

    test('명세 묶음에서 IA 컴포넌트 41개를 읽습니다', () {
      expect(specs, hasLength(41));
    });

    test('등록된 컴포넌트 id가 명세에 있습니다', () {
      for (final spec in implementedComponents) {
        expect(specs.keys, contains(spec.id), reason: spec.id);
      }
    });

    for (final spec in implementedComponents) {
      test('${spec.id}: 변형·상태가 명세와 같습니다', () {
        final json = specs[spec.id]!;
        final variants = {
          for (final v in (json['variants'] as List<Object?>?) ?? <Object?>[])
            (v! as Map<String, Object?>)['id']! as String,
        };
        final states = {
          ...((json['states'] as Map<String, Object?>?) ?? {}).keys,
        };
        expect(spec.variants, variants);
        expect(spec.states, states);
      });
    }
  });

  group('InteractionPattern 대조', () {
    final patterns = _interaction()['patterns']! as Map<String, Object?>;

    test('enum 이름 집합이 interaction.json id의 lowerCamelCase와 같습니다', () {
      expect(
        InteractionPattern.values.map((p) => p.name).toSet(),
        patterns.keys.map(iaKey).toSet(),
      );
    });

    test('패턴마다 id·시간·곡선·대체 규칙이 명세와 같습니다', () {
      for (final pattern in InteractionPattern.values) {
        final json = patterns[pattern.id]! as Map<String, Object?>;
        expect(iaKey(pattern.id), pattern.name);
        expect(
          pattern.duration,
          _durations[_tokenName(json['duration']! as String)],
          reason: pattern.id,
        );
        expect(
          pattern.curve,
          _easings[_tokenName(json['easing']! as String)],
          reason: pattern.id,
        );
        expect(
          pattern.reduceMotion.json,
          json['reduceMotion'],
          reason: pattern.id,
        );
        expect(pattern.lowEnd.json, json['lowEnd'], reason: pattern.id);
      }
    });
  });
}

/// `{motion.duration.stamp}` → `stamp`.
String _tokenName(String reference) =>
    reference.substring(1, reference.length - 1).split('.').skip(2).join('.');
