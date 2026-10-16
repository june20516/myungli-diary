import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:timezone/timezone.dart' as tz;

/// 대표 경도를 127.5도로 고정하는 시간대입니다(엔진 `representative_longitude`).
const String _seoulTimezone = 'Asia/Seoul';

/// 서울 대표 경도(도).
const double _seoulRepresentativeLongitude = 127.5;

/// 표준 오프셋 한 시간이 차지하는 경도(도).
const int _degreesPerHour = 15;

/// 경도 1도가 차지하는 시간(분).
const int _minutesPerDegree = 4;

/// 시각 모름일 때 쓰는 지역 시각(엔진 `UNKNOWN_TIME_FALLBACK`).
const int _unknownTimeFallbackHour = 12;

/// `HH:MM`(24시간) 형식입니다.
final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

/// 출생 시각 경도 보정의 기준(A28).
@immutable
final class TimeBasis {
  /// [longitude]는 기준 경도(동경 양수, 서경 음수), [correctionMinutes]는 부호 있는 보정 분입니다.
  const new({required this.longitude, required this.correctionMinutes});

  /// 기준 경도(도). 도시 경도, 없으면 대표 경도입니다.
  final double longitude;

  /// 보정 분. 양수면 더하고 음수면 빼며 0이면 보정이 없습니다.
  final int correctionMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeBasis &&
          other.longitude == longitude &&
          other.correctionMinutes == correctionMinutes;

  @override
  int get hashCode => Object.hash(longitude, correctionMinutes);

  @override
  String toString() =>
      'TimeBasis(longitude: $longitude, correctionMinutes: $correctionMinutes)';
}

/// [timezone]의 대표 경도입니다. Asia/Seoul은 127.5도, 그 밖은 표준 오프셋×15도입니다.
double representativeLongitude(String timezone, double standardOffsetHours) {
  if (timezone == _seoulTimezone) {
    return _seoulRepresentativeLongitude;
  }
  return standardOffsetHours * _degreesPerHour;
}

/// [utc] 시점의 [location] 오프셋에서 서머타임을 뺀 표준 오프셋(시간)입니다.
///
/// 시간대 데이터에는 서머타임 여부만 있고 양이 없으므로, 서머타임 구간이면 전환을 거슬러
/// 서머타임이 아닌 구간의 오프셋을 씁니다. 앞에 없으면 뒤에서 찾습니다.
double standardOffsetHoursAt(tz.Location location, DateTime utc) {
  final at = location.lookupTimeZone(utc.millisecondsSinceEpoch);
  var standard = at;
  while (standard.timeZone.isDst && standard.start > tz.minTime) {
    standard = location.lookupTimeZone(standard.start - 1);
  }
  if (standard.timeZone.isDst) {
    standard = at;
    while (standard.timeZone.isDst && standard.end < tz.maxTime) {
      standard = location.lookupTimeZone(standard.end);
    }
  }
  return standard.timeZone.offset.inSeconds / Duration.secondsPerHour;
}

/// 출생 입력의 경도 보정 기준을 구합니다(A28, 엔진 `resolve_birth_moment`와 같은 규칙).
///
/// [solarDate]는 연·월·일만 씁니다. [time]이 모름이면 12:00으로 봅니다. [cityLongitude]가
/// 없으면 대표 경도를 씁니다. 모르는 [timezone]이거나 시각 형식이 틀리면 [ArgumentError]입니다.
TimeBasis timeBasisOf({
  required String timezone,
  required DateTime solarDate,
  required BirthTime time,
  double? cityLongitude,
}) {
  final location = _locationOf(timezone);
  final (hour, minute) = _wallClockOf(time);
  final wallClock = DateTime.utc(
    solarDate.year,
    solarDate.month,
    solarDate.day,
    hour,
    minute,
  );
  final standardOffset = standardOffsetHoursAt(
    location,
    _wallClockToUtc(location, wallClock),
  );
  final longitude =
      cityLongitude ?? representativeLongitude(timezone, standardOffset);
  final correction =
      (longitude - standardOffset * _degreesPerHour) * _minutesPerDegree;
  return TimeBasis(longitude: longitude, correctionMinutes: correction.round());
}

/// 경도 표기용 숫자입니다. 절댓값을 소수 둘째 자리까지 쓰고 뒤 0을 지웁니다(`127.5`, `135`).
///
/// 동경·서경은 부호로 화면이 정합니다.
String longitudeDegreesText(double longitude) =>
    longitude.abs().toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

tz.Location _locationOf(String timezone) {
  ensureTimeZonesInitialized();
  try {
    return tz.getLocation(timezone);
  } on tz.LocationNotFoundException {
    throw ArgumentError.value(timezone, 'timezone', '모르는 시간대입니다.');
  }
}

(int, int) _wallClockOf(BirthTime time) {
  if (time.status == BirthTimeStatusEnum.unknown) {
    return (_unknownTimeFallbackHour, 0);
  }
  final match = _timePattern.firstMatch(time.value ?? '');
  if (match == null) {
    throw ArgumentError.value(time.value, 'time', 'HH:MM 형식이 아닙니다.');
  }
  return (int.parse(match[1]!), int.parse(match[2]!));
}

/// 지역 벽시계 [wallClock](UTC 필드에 담은 값)을 UTC 시점으로 바꿉니다.
///
/// 엔진(Python zoneinfo `fold=0`)과 같게, 전환마다 벽시계 경계를 "전환 시점 + 앞뒤 오프셋 중
/// 큰 값"으로 두고 그 경계를 지나지 않았으면 전환 전 오프셋을 씁니다. 그래서 겹친 시각은 앞
/// 시점, 없는 시각은 전환 전 오프셋으로 뒤로 밀린 시점입니다. `tz.TZDateTime` 생성자는 겹친
/// 시각에서 뒤 시점을 고를 때가 있어(예: 서울 1954-03-20 23:45) 쓰지 않습니다.
DateTime _wallClockToUtc(tz.Location location, DateTime wallClock) {
  final wallMilliseconds = wallClock.millisecondsSinceEpoch;
  var offset = location.lookupTimeZone(tz.minTime).timeZone.offset;
  for (var i = 0; i < location.transitionAt.length; i++) {
    final after = location.zones[location.transitionZone[i]].offset;
    final before = i == 0
        ? after
        : location.zones[location.transitionZone[i - 1]].offset;
    final wallBoundary =
        location.transitionAt[i] +
        math.max(before.inMilliseconds, after.inMilliseconds);
    if (wallMilliseconds < wallBoundary) {
      break;
    }
    offset = after;
  }
  return DateTime.fromMillisecondsSinceEpoch(
    wallMilliseconds - offset.inMilliseconds,
    isUtc: true,
  );
}
