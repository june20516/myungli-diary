import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 사주 표와 오늘 문장에서 누를 수 있는 용어 범주. 대역 사전에서 이 범주는 이름이 있으면 뜻도
/// 있어야 합니다(#957: 이름만 있고 뜻이 빠진 범주가 빈 풀이 시트를 냄).
const _pressableCategories = [
  'element',
  'stem',
  'branch',
  'ten_god',
  'ten_god_group',
  'twelve_stage',
  'shinsal',
  'role',
  'relation',
  'day_kind',
];

void main() {
  test('member 사전 fixture는 누를 수 있는 범주의 이름마다 뜻이 있습니다(#957)', () {
    final body =
        (jsonDecode(File('fixtures/member/getGlossary.json').readAsStringSync())
                as Map<String, dynamic>)['body']
            as Map<String, dynamic>;
    final values = body['values'] as Map<String, dynamic>;
    final meanings = body['meanings'] as Map<String, dynamic>;
    final missing = [
      for (final category in _pressableCategories)
        for (final value in (values[category] as Map<String, dynamic>).keys)
          if (!meanings.containsKey('$category.$value')) '$category.$value',
    ];
    expect(missing, isEmpty);
  });
}
