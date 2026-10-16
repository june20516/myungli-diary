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
  /// [longitude]는 기준 경도(동경 양수, 서경 음수), [correctionMinutes]는 부호 있는 보정 분,
  /// [daylightSavingMinutes]는 그 시점의 서머타임 양(분)입니다.
  const new({
    required this.longitude,
    required this.correctionMinutes,
    this.daylightSavingMinutes = 0,
  });

  /// 기준 경도(도). 도시 경도, 없으면 대표 경도입니다.
  final double longitude;

  /// 보정 분. 양수면 더하고 음수면 빼며 0이면 보정이 없습니다.
  ///
  /// 표준 자오선 기준입니다. 서머타임 중이면 실제 벽시계와의 차이는 여기에
  /// [daylightSavingMinutes]를 더 뺀 값입니다(A31).
  final int correctionMinutes;

  /// 출생 시점의 서머타임 양(분, 0 이상). 서머타임이 아니면 0입니다.
  ///
  /// [standardOffsetHoursAt]이 빼는 서머타임과 같은 값(엔진 zoneinfo `dst()`)입니다.
  final int daylightSavingMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeBasis &&
          other.longitude == longitude &&
          other.correctionMinutes == correctionMinutes &&
          other.daylightSavingMinutes == daylightSavingMinutes;

  @override
  int get hashCode =>
      Object.hash(longitude, correctionMinutes, daylightSavingMinutes);

  @override
  String toString() =>
      'TimeBasis(longitude: $longitude, correctionMinutes: $correctionMinutes, '
      'daylightSavingMinutes: $daylightSavingMinutes)';
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
/// 엔진(Python zoneinfo `utcoffset() - dst()`)과 같은 값입니다. 시간대 데이터에는 서머타임
/// 여부만 있고 양이 없으므로, zoneinfo처럼 앞뒤 전환의 비서머타임 오프셋에서 양을 추정합니다
/// ([_dstSecondsOf]). 그래서 이중 서머타임(London 1941, Berlin 1945)도 엔진과 같습니다.
///
/// 한계: `timezone` 패키지 데이터에는 1920년 이전 일부 시간대(서울 1908, 상파울루 1914,
/// 카트만두 ~1920, 카사블랑카 ~1913 등)의 LMT 구간이 없어 그 전 시각은 엔진과 다를 수
/// 있습니다. 예: 서울은 LMT → KST 전환(1908-04-01)이 없어 1908-03-31 이전이 엔진
/// (LMT +8:27:52)과 달리 +8:30입니다.
double standardOffsetHoursAt(tz.Location location, DateTime utc) {
  final zone = location.lookupTimeZone(utc.millisecondsSinceEpoch).timeZone;
  return (zone.offset.inSeconds - _dstSecondsAt(location, utc)) /
      Duration.secondsPerHour;
}

/// [utc] 시점의 [location] 서머타임 양(초)입니다. 엔진 zoneinfo `dst()`와 같은 추정입니다.
int _dstSecondsAt(tz.Location location, DateTime utc) {
  final instant = location.lookupTimeZone(utc.millisecondsSinceEpoch);
  final transitionIndex = location.transitionAt.indexOf(instant.start);
  if (transitionIndex < 0) {
    // 첫 전환 전입니다. zoneinfo는 첫 비서머타임 유형을 쓰므로 대개 서머타임이 없습니다.
    return instant.timeZone.isDst ? _fallbackDstSeconds : 0;
  }
  return _dstSecondsOf(location)[location.transitionZone[transitionIndex]];
}

/// 서머타임 양을 추정하지 못했을 때 쓰는 값(초, zoneinfo와 같음).
const int _fallbackDstSeconds = Duration.secondsPerHour;

/// 시간대마다 한 번만 추정한 zone별 서머타임 양.
final Expando<List<int>> _dstSecondsCache = Expando('dstSeconds');

/// [location]의 zone(전환 유형)별 서머타임 양(초)입니다. 서머타임이 아닌 zone은 0입니다.
///
/// CPython `zoneinfo._zoneinfo.ZoneInfo._utcoff_to_dstoff`를 그대로 옮겼습니다. 서머타임
/// zone마다 처음 나오는 전환에서, 직전 zone이 비서머타임이면 그 오프셋과의 차, 아니면 직후
/// zone이 비서머타임일 때 그 차를 씁니다. 끝내 못 정하면 한 시간입니다.
List<int> _dstSecondsOf(tz.Location location) => _dstSecondsCache[location] ??=
    _inferDstSeconds(location.transitionZone, location.zones);

List<int> _inferDstSeconds(List<int> transitionZone, List<tz.TimeZone> zones) {
  final dstSeconds = List<int>.filled(zones.length, 0);
  final dstZoneCount = zones.where((zone) => zone.isDst).length;
  var assigned = 0;
  for (var i = 1; i < transitionZone.length && assigned < dstZoneCount; i++) {
    final index = transitionZone[i];
    final zone = zones[index];
    if (!zone.isDst || dstSeconds[index] != 0) {
      continue;
    }
    var dst = 0;
    final previous = zones[transitionZone[i - 1]];
    if (!previous.isDst) {
      dst = zone.offset.inSeconds - previous.offset.inSeconds;
    }
    // zoneinfo는 전환 순번이 아니라 zone 번호로 "마지막이 아닌지"를 봅니다. 그대로 따르되,
    // zoneinfo라면 색인 오류가 날 마지막 전환에는 범위 검사를 더했습니다.
    if (dst == 0 && index < zones.length - 1 && i + 1 < transitionZone.length) {
      final next = zones[transitionZone[i + 1]];
      if (next.isDst) {
        // 앞뒤 모두 서머타임이면 이 zone이 뒤에 다시 나올 때 정합니다.
        continue;
      }
      dst = zone.offset.inSeconds - next.offset.inSeconds;
    }
    if (dst != 0) {
      assigned++;
      dstSeconds[index] = dst;
    }
  }
  for (var index = 0; index < zones.length; index++) {
    if (zones[index].isDst && dstSeconds[index] == 0) {
      dstSeconds[index] = _fallbackDstSeconds;
    }
  }
  return dstSeconds;
}

/// 출생 입력의 경도 보정 기준을 구합니다(A28, 엔진 `resolve_birth_moment`와 같은 규칙).
///
/// [solarDate]는 연·월·일만 씁니다. [time]이 모름이면 12:00으로 봅니다. [cityLongitude]가
/// 없으면 대표 경도를 씁니다. 모르는 [timezone]이거나 시각 형식이 틀리면 [ArgumentError]입니다.
///
/// 한계: `timezone` 패키지 데이터에 1920년 이전 일부 시간대(서울 1908, 상파울루 1914,
/// 카트만두 ~1920, 카사블랑카 ~1913 등)의 LMT 구간이 없어, 그 구간 입력은 엔진과 다를 수
/// 있습니다(예: 1908-03-31 이전 서울은 엔진 +2분, 여기서는 0분. [standardOffsetHoursAt]).
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
  final utc = _wallClockToUtc(location, wallClock);
  final standardOffset = standardOffsetHoursAt(location, utc);
  final longitude =
      cityLongitude ?? representativeLongitude(timezone, standardOffset);
  final correction =
      (longitude - standardOffset * _degreesPerHour) * _minutesPerDegree;
  return TimeBasis(
    longitude: longitude,
    correctionMinutes: correction.round(),
    daylightSavingMinutes:
        _dstSecondsAt(location, utc) ~/ Duration.secondsPerMinute,
  );
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
