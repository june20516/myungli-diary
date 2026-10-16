// 엔진 대조 회귀 테스트: `timeBasisOf`가 core 엔진과 같은 기준 경도·보정 분·서머타임 분을
// 내는지 대표 사례로 확인합니다.
//
// 기준값 `engine_time_basis_cases.json`은 core 엔진(Python zoneinfo tzdata)으로
// 만듭니다. 엔진 함수: `_local_to_utc` → `standard_offset_hours` →
// `representative_longitude`, 서머타임 분은 zoneinfo `dst()`입니다
// (`app/tool/gen_time_basis_cases.py` 머리 주석 참고).
// 다시 만들기(core/에서):
//   uv run python ../app/tool/gen_time_basis_cases.py \
//     ../app/test/features/calc_basis/model/engine_time_basis_cases.json
// `timezone` 패키지 데이터에 LMT 구간이 없는 1920년 이전 일부 시간대는 엔진과 달라
// 사례에 넣지 않습니다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/features/calc_basis/model/time_basis.dart';

const String _casesPath =
    'test/features/calc_basis/model/engine_time_basis_cases.json';

/// 엔진이 계산한 사례 하나.
typedef _EngineCase = ({
  String note,
  String timezone,
  DateTime solarDate,
  String? time,
  TimeBasis expected,
});

List<_EngineCase> _loadCases() {
  final json = jsonDecode(File(_casesPath).readAsStringSync()) as List<Object?>;
  return [
    for (final item in json.cast<Map<String, Object?>>())
      (
        note: item['note']! as String,
        timezone: item['timezone']! as String,
        solarDate: DateTime.parse(item['date']! as String),
        time: item['time'] as String?,
        expected: TimeBasis(
          longitude: (item['longitude']! as num).toDouble(),
          correctionMinutes: item['correctionMinutes']! as int,
          daylightSavingMinutes: item['daylightSavingMinutes']! as int,
        ),
      ),
  ];
}

BirthTime _birthTimeOf(String? value) => value == null
    ? BirthTime(status: BirthTimeStatusEnum.unknown)
    : BirthTime(status: BirthTimeStatusEnum.known, value: value);

void main() {
  setUpAll(ensureTimeZonesInitialized);

  final cases = _loadCases();

  test('사례가 비어 있지 않습니다', () {
    expect(cases.length, greaterThanOrEqualTo(40));
  });

  for (final engineCase in cases) {
    final date = engineCase.solarDate.toIso8601String().substring(0, 10);
    final name =
        '${engineCase.timezone} $date ${engineCase.time ?? '모름'}'
        ' (${engineCase.note})';
    test(name, () {
      expect(
        timeBasisOf(
          timezone: engineCase.timezone,
          solarDate: engineCase.solarDate,
          time: _birthTimeOf(engineCase.time),
        ),
        engineCase.expected,
      );
    });
  }
}
