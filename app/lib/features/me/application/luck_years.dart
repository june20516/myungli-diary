import 'package:flutter/foundation.dart' show immutable;
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/daeun.dart';
import 'package:myungli_diary/core/api/gen/model/seun_year.dart';

/// 대운 기둥마다의 시작 연도와 지금 대운(core C22).
@immutable
final class LuckYears {
  /// [startYears]는 `Daeun.periods` 순서이고, [currentIndex]는 지금 대운의 자리입니다.
  const new({required this.startYears, required this.currentIndex});

  /// 기둥마다 시작 연도(양력). 출생 연도를 모르면 null입니다.
  final List<int?> startYears;

  /// 올해가 속한 대운의 자리. 첫 대운 전이거나 출생 연도를 모르면 null입니다.
  final int? currentIndex;
}

/// [daeun]의 시작 연도와 [thisYear](기기 오늘의 연도)가 속한 대운을 셉니다.
///
/// core C22: 대운 i의 시작 연도 = 출생 양력 연도 + 한국식 나이(`startAgeKorean`) - 1이고, 세운
/// 표([seun])는 server 기준일이 속한 대운의 시작 연도부터 10년입니다. 계약 `Chart`에는 출생 연도가
/// 없으므로 프로필 사본의 생일([birth])로 셉니다.
///
/// * 양력 생일은 그 연도가 출생 양력 연도입니다.
/// * 음력 생일은 양력으로 그 해이거나 다음 해(음력 11·12월 끝)입니다. 둘 중 세운 구간의 시작
///   연도와 맞는(시작 연도 - 출생 연도 + 1이 한국식 나이 중 하나인) 해를 고릅니다. 대운 나이는
///   10씩 늘어나므로 두 해 중 하나만 맞습니다. 세운이 없으면 그 해로 봅니다.
/// * 생일을 모르면(사본 없음) 시작 연도와 지금 대운을 비웁니다.
///
/// 지금 대운은 기기 오늘 기준이라 해가 바뀌면 화면이 새 [thisYear]로 다시 셉니다(Review Focus 4).
LuckYears luckYearsOf({
  required Daeun daeun,
  required List<SeunYear> seun,
  required Birth? birth,
  required int thisYear,
}) {
  final periods = daeun.periods;
  final birthYear = birth == null ? null : _birthSolarYear(birth, daeun, seun);
  if (birthYear == null) {
    return LuckYears(
      startYears: List<int?>.filled(periods.length, null),
      currentIndex: null,
    );
  }
  final startYears = [
    for (final period in periods) birthYear + period.startAgeKorean - 1,
  ];
  int? current;
  for (final (index, start) in startYears.indexed) {
    if (start <= thisYear) current = index;
  }
  return LuckYears(startYears: startYears, currentIndex: current);
}

/// [birth]의 출생 양력 연도.
int _birthSolarYear(Birth birth, Daeun daeun, List<SeunYear> seun) {
  final year = birth.date.year;
  if (birth.calendar == CalendarType.solar ||
      seun.isEmpty ||
      daeun.periods.isEmpty) {
    return year;
  }
  final seunStart = seun.first.year;
  final firstAge = daeun.periods.first.startAgeKorean;
  for (final candidate in [year, year + 1]) {
    // 세운 시작 연도의 한국식 나이가 대운 나이(첫 대운 나이 + 10의 배수)와 맞는지.
    if ((seunStart - candidate + 1 - firstAge) % 10 == 0) return candidate;
  }
  return year;
}
