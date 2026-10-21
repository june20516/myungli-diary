@Tags(['contract'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../tool/common/open_enums.dart';
import '../../tool/common/openapi_spec.dart';

/// 열린 enum 절이 있는 작은 계약입니다.
Map<String, Object?> _smallSpec({String? description}) => {
  'info': {
    'description':
        description ??
        '호환과 버전\n'
            '* 열린 enum: 값이 늘어날 수 있는 응답 enum입니다. 모르는 값은 건너뜁니다.\n'
            '  `Code`, `Item.kind`, `Slot.reasons`의 항목, `Problem.code`입니다. '
            '그 밖의 enum은 닫힌 enum입니다. `Closed`는 예시입니다.\n',
  },
  'components': {
    'schemas': {
      'Code': {
        'type': 'string',
        'enum': ['a', 'b'],
      },
      'Closed': {
        'type': 'string',
        'enum': ['x'],
      },
      'Item': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['k1'],
          },
          'code': {r'$ref': '#/components/schemas/Code'},
        },
      },
      'Slot': {
        'type': 'object',
        'properties': {
          'reasons': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': ['r1'],
            },
          },
        },
      },
      'Problem': {
        'type': 'object',
        'properties': {
          'code': {'type': 'string'},
        },
      },
    },
  },
};

Map<String, Object?> _schema(Map<String, Object?> spec, String name) =>
    ((spec['components']! as Map<String, Object?>)['schemas']!
            as Map<String, Object?>)[name]!
        as Map<String, Object?>;

Map<String, Object?> _property(
  Map<String, Object?> spec,
  String schema,
  String property,
) =>
    (_schema(spec, schema)['properties']! as Map<String, Object?>)[property]!
        as Map<String, Object?>;

void main() {
  group('contractOpenEnumNames', () {
    test('"열린 enum:"부터 "그 밖의 enum" 앞까지의 `이름`을 순서대로 읽는다', () {
      expect(contractOpenEnumNames(_smallSpec()), [
        'Code',
        'Item.kind',
        'Slot.reasons',
        'Problem.code',
      ]);
    });

    test('절이 없으면 FormatException', () {
      expect(
        () => contractOpenEnumNames(_smallSpec(description: '호환과 버전\n')),
        throwsFormatException,
      );
    });

    test('절은 있는데 이름이 없으면 FormatException', () {
      expect(
        () => contractOpenEnumNames(
          _smallSpec(description: '열린 enum: 없음. 그 밖의 enum은 닫힘'),
        ),
        throwsFormatException,
      );
    });

    test('실제 계약에서 9개를 읽는다', () {
      expect(contractOpenEnumNames(loadOpenApi()), [
        'NoticeCode',
        'ShinsalKind',
        'RelationKind',
        'PersonalReading.kind',
        'FocusSlot.reasons',
        'SlotText.variant',
        'Insight.source',
        'ConsentDocument.document',
        'Problem.code',
      ]);
    });
  });

  group('resolveOpenEnums', () {
    test('스키마·속성·배열 항목은 enum, enum 없는 string은 열린 문자열', () {
      final targets = resolveOpenEnums(_smallSpec());
      expect(targets.map((t) => (t.name, t.isEnum)), [
        ('Code', true),
        ('Item.kind', true),
        ('Slot.reasons', true),
        ('Problem.code', false),
      ]);
    });

    test(r'속성이 $ref면 참조된 스키마 이름으로 적어야 해서 FormatException', () {
      final spec = _smallSpec(description: '열린 enum: `Item.code`. 그 밖의 enum');
      expect(() => resolveOpenEnums(spec), throwsFormatException);
    });

    test('없는 스키마·속성이면 FormatException', () {
      for (final name in ['Nope', 'Item.nope', 'A.b.c']) {
        final spec = _smallSpec(description: '열린 enum: `$name`. 그 밖의 enum');
        expect(() => resolveOpenEnums(spec), throwsFormatException);
      }
    });

    test('enum도 string도 아니면 FormatException', () {
      final spec = _smallSpec(description: '열린 enum: `Item`. 그 밖의 enum');
      expect(() => resolveOpenEnums(spec), throwsFormatException);
    });
  });

  group('markOpenEnums', () {
    test('열린 enum 노드에만 표시를 달고 원본은 바꾸지 않는다', () {
      final spec = _smallSpec();
      final marked = markOpenEnums(spec);

      expect(_schema(marked, 'Code')[openEnumExtension], isTrue);
      expect(_property(marked, 'Item', 'kind')[openEnumExtension], isTrue);
      final reasons = _property(marked, 'Slot', 'reasons');
      expect(reasons[openEnumExtension], isNull);
      expect(
        (reasons['items']! as Map<String, Object?>)[openEnumExtension],
        isTrue,
      );
      // 닫힌 enum과 열린 문자열에는 표시가 없습니다.
      expect(_schema(marked, 'Closed').containsKey(openEnumExtension), isFalse);
      expect(
        _property(marked, 'Problem', 'code').containsKey(openEnumExtension),
        isFalse,
      );
      // 원본은 그대로입니다.
      expect(_schema(spec, 'Code').containsKey(openEnumExtension), isFalse);
    });
  });
}
