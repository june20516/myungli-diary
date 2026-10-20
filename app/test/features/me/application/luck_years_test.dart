import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/branch.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/daeun.dart';
import 'package:myungli_diary/core/api/gen/model/daeun_period.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/pillar.dart';
import 'package:myungli_diary/core/api/gen/model/seun_year.dart';
import 'package:myungli_diary/core/api/gen/model/stem.dart';
import 'package:myungli_diary/core/api/gen/model/ten_god.dart';
import 'package:myungli_diary/core/api/gen/model/twelve_stage.dart';
import 'package:myungli_diary/features/me/application/luck_years.dart';

final _pillar = Pillar(stem: Stem.gap, branch: Branch.ja);

/// 한국식 시작 나이가 [ages]인 대운.
Daeun _daeun(List<int> ages) => Daeun(
  forward: true,
  startYears: ages.first - 1,
  startMonths: 0,
  periods: [
    for (final age in ages)
      DaeunPeriod(
        pillar: _pillar,
        startAge: age - 1,
        startAgeKorean: age,
        stemTenGod: TenGod.bigyeon,
        branchTenGod: TenGod.bigyeon,
        twelveStage: TwelveStage.jangsaeng,
      ),
  ],
);

/// [start]부터 10년의 세운.
List<SeunYear> _seun(int start) => [
  for (var year = start; year < start + 10; year++)
    SeunYear(
      year: year,
      pillar: _pillar,
      tenGod: TenGod.bigyeon,
      relationsWithNatal: const [],
    ),
];

Birth _birth(int year, {CalendarType calendar = CalendarType.solar}) => Birth(
  calendar: calendar,
  date: LunarOrSolarDate(year: year, month: 12, day: 20),
  isLeapMonth: false,
  time: BirthTime(status: BirthTimeStatusEnum.unknown),
  gender: BirthGenderEnum.female,
  timezone: 'Asia/Seoul',
  place: BirthPlace(status: BirthPlaceStatusEnum.notAsked),
);

void main() {
  // member fixture: 1990년생, 한국식 4·14·24·34…세 대운, 세운 2023~2032(34세 대운).
  final daeun = _daeun([4, 14, 24, 34, 44, 54]);
  final seun = _seun(2023);

  group('luckYearsOf', () {
    test('양력 생일 연도로 대운 시작 연도를 셉니다(시작 연도 = 출생 연도 + 한국식 나이 - 1)', () {
      final years = luckYearsOf(
        daeun: daeun,
        seun: seun,
        birth: _birth(1990),
        thisYear: 2026,
      );
      expect(years.startYears, [1993, 2003, 2013, 2023, 2033, 2043]);
      expect(years.currentIndex, 3);
    });

    test('지금 대운은 올해가 속한 대운입니다(시작 해부터 그 대운)', () {
      int? current(int year) => luckYearsOf(
        daeun: daeun,
        seun: seun,
        birth: _birth(1990),
        thisYear: year,
      ).currentIndex;
      expect(current(2032), 3);
      expect(current(2033), 4);
      expect(current(1993), 0);
      // 첫 대운 전에는 지금 대운이 없습니다.
      expect(current(1992), isNull);
    });

    test('음력 생일은 그 해와 다음 해 중 세운 구간과 맞는 해가 출생 양력 연도입니다', () {
      // 음력 1989-12-20은 양력 1990년 1월입니다. 세운 구간(2023 시작)과 맞는 해는 1990입니다.
      final years = luckYearsOf(
        daeun: daeun,
        seun: seun,
        birth: _birth(1989, calendar: CalendarType.lunar),
        thisYear: 2026,
      );
      expect(years.startYears.first, 1993);
      expect(years.currentIndex, 3);
    });

    test('음력 생일이 그 해 양력이면 그 해입니다', () {
      final years = luckYearsOf(
        daeun: daeun,
        seun: seun,
        birth: _birth(1990, calendar: CalendarType.lunar),
        thisYear: 2026,
      );
      expect(years.startYears.first, 1993);
    });

    test('생일을 모르면(프로필 사본 없음) 시작 연도와 지금 대운을 비웁니다', () {
      final years = luckYearsOf(
        daeun: daeun,
        seun: seun,
        birth: null,
        thisYear: 2026,
      );
      expect(years.startYears, List<int?>.filled(6, null));
      expect(years.currentIndex, isNull);
    });
  });
}
