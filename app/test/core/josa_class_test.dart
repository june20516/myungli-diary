@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/l10n/josa_class.dart';
import 'package:yaml/yaml.dart';

const String _josaRulesPath = '../docs/identity/writing/rules/josa.yaml';

/// `rules/josa.yaml`의 조사 표기 한 쌍입니다.
class _JosaPair {
  new(YamlMap yaml)
    : marker = yaml['marker'] as String,
      withBatchim = yaml['with_batchim'] as String,
      withoutBatchim = yaml['without_batchim'] as String,
      rieul = yaml['rieul'] as String?,
      fallback = yaml['fallback'] as String;

  final String marker;
  final String withBatchim;
  final String withoutBatchim;
  final String? rieul;
  final String fallback;

  /// writing이 ARB `select`로 펼치는 가지 표(가이드 "ui ARB의 조사")와 같게 고릅니다.
  String choose(String josaClassValue) => switch (josaClassValue) {
    'final' => withBatchim,
    'rieul' => rieul ?? withBatchim,
    'none' => withoutBatchim,
    'other' => fallback,
    _ => throw ArgumentError.value(josaClassValue, 'josaClassValue'),
  };
}

void main() {
  group('josa.yaml examples', () {
    final rules = loadYaml(File(_josaRulesPath).readAsStringSync()) as YamlMap;
    final pairs = (rules['pairs'] as YamlList)
        .cast<YamlMap>()
        .map(_JosaPair.new)
        .toList();
    final examples = (rules['examples'] as YamlList).cast<YamlMap>();

    test('예제가 비어 있지 않습니다', () {
      expect(examples, isNotEmpty);
    });

    for (final example in examples) {
      final text = example['text'] as String;
      final expected = example['expected'] as String;

      test(text, () {
        final pair = pairs.singleWhere((p) => text.endsWith(p.marker));
        final shown = text.substring(0, text.length - pair.marker.length);

        expect(shown + pair.choose(josaClass(shown)), expected);
      });
    }
  });

  group('josaClass', () {
    test('한글 받침 종류를 가립니다', () {
      expect(josaClass('남색'), 'final');
      expect(josaClass('물'), 'rieul');
      expect(josaClass('보라'), 'none');
    });

    test('자모가 나뉜(NFD) 입력도 NFC로 합쳐 판정합니다', () {
      expect(josaClass('남색'), 'final');
      expect(josaClass('물'), 'rieul');
    });

    test('NFC가 바꾸는 글자는 바뀐 글자로 읽습니다', () {
      // KELVIN SIGN → K(케이)
      expect(josaClass('K'), 'none');
      // CJK 호환 한자 U+F971 → 辰(진)
      expect(josaClass('辰'), 'final');
    });

    test('끝에서 이어진 0은 자릿수로 읽고 만에서 멈춥니다', () {
      expect(josaClass('1000000'), 'final');
      expect(josaClass('20'), 'final');
    });

    test('소문자 영문은 대문자 이름으로 읽습니다', () {
      expect(josaClass('b'), 'none');
      expect(josaClass('l'), 'rieul');
    });

    test('판정할 수 없으면 other입니다', () {
      expect(josaClass(''), 'other');
      expect(josaClass('さくら'), 'other');
      expect(josaClass('１'), 'other');
      expect(josaClass('木'), 'other');
    });

    test('ASCII 밖 영문자는 대문자로 바뀌어도 읽지 않습니다', () {
      // dotless i, long s는 toUpperCase()로 I, S가 되지만 server 판정표 밖입니다.
      expect(josaClass('ı'), 'other');
      expect(josaClass('ſ'), 'other');
    });
  });
}
