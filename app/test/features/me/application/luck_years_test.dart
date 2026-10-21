import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/daeun.dart';
import 'package:myungli_diary/core/api/gen/model/daeun_period.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:myungli_diary/features/me/application/luck_years.dart';

final _pillar = Pillar(stem: Stem.gap, branch: Branch.ja);

/// 시작 연도가 [years]인 대운. 한국식 나이는 1990년생 기준입니다.
Daeun _daeun(List<int> years) => Daeun(
  forward: true,
  startYears: 3,
  startMonths: 0,
  periods: [
    for (final year in years)
      DaeunPeriod(
        pillar: _pillar,
        startAge: year - 1991,
        startAgeKorean: year - 1989,
        startYear: year,
        stemTenGod: TenGod.bigyeon,
        branchTenGod: TenGod.bigyeon,
        twelveStage: TwelveStage.jangsaeng,
      ),
  ],
);

void main() {
  // member fixture: 1990년생, 대운이 1993·2003·2013·2023…년에 시작합니다.
  final daeun = _daeun([1993, 2003, 2013, 2023, 2033, 2043]);

  group('currentDaeunIndex', () {
    test('올해가 속한 대운입니다(시작 해부터 그 대운)', () {
      int? current(int year) => currentDaeunIndex(daeun, thisYear: year);
      expect(current(2026), 3);
      expect(current(2032), 3);
      expect(current(2033), 4);
      expect(current(1993), 0);
    });

    test('첫 대운 전이면 없습니다', () {
      expect(currentDaeunIndex(daeun, thisYear: 1992), isNull);
    });

    test('대운이 없으면 없습니다', () {
      expect(currentDaeunIndex(_daeun(const []), thisYear: 2026), isNull);
    });
  });
}
