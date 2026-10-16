import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 현재 시각의 출처. 테스트에서 고정하려고 주입합니다.
abstract interface class Clock {
  /// 지금 시각(UTC).
  DateTime nowUtc();

  /// 시간이 흐르는 시계인지. false면 날짜가 바뀌지 않으므로 자정 구독이 필요 없습니다.
  bool get advances;
}

/// 기기 시계.
final class SystemClock implements Clock {
  /// 기기 시계를 씁니다.
  const new();

  @override
  bool get advances => true;

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// 항상 같은 시각을 돌려주는 시계.
final class FixedClock implements Clock {
  /// [instant]에 고정합니다(UTC로 바꿔 보관).
  new(DateTime instant) : _instant = instant.toUtc();

  final DateTime _instant;

  @override
  bool get advances => false;

  @override
  DateTime nowUtc() => _instant;
}

var _timeZonesInitialized = false;

/// `timezone` 패키지의 시간대 데이터(`latest_all`)를 한 번만 읽습니다(멱등).
///
/// 테스트와 앱 시작 코드가 [todayIn] 전에 부릅니다.
void ensureTimeZonesInitialized() {
  if (_timeZonesInitialized) {
    return;
  }
  tz_data.initializeTimeZones();
  _timeZonesInitialized = true;
}

tz.Location _locationOf(String ianaTimezone) {
  ensureTimeZonesInitialized();
  try {
    return tz.getLocation(ianaTimezone);
  } on tz.LocationNotFoundException {
    throw ArgumentError.value(ianaTimezone, 'ianaTimezone', '모르는 시간대입니다.');
  }
}

/// 시간대 데이터에 없는 이름을 만나 다른 시간대로 물러났음을 알리는 보고용 오류.
///
/// 이름 자체는 싣지 않습니다(보고에는 타입 이름만 남습니다, D64 ②).
final class UnknownTimezone implements Exception {
  /// 보고용 오류를 만듭니다.
  const new();

  @override
  String toString() => 'UnknownTimezone';
}

/// [ianaTimezone]이 시간대 데이터에 있는 이름인지.
bool isKnownTimezone(String ianaTimezone) {
  ensureTimeZonesInitialized();
  return tz.timeZoneDatabase.locations.containsKey(ianaTimezone);
}

/// [candidates]를 앞에서부터 보고 처음 아는 시간대 이름을 고릅니다. 없으면 [fallbackTimezone]입니다.
///
/// null은 "값 없음"이라 조용히 건너뛰고, 모르는 이름을 건너뛸 때는 [onUnknown]을 부릅니다.
/// 프로필 시간대가 모르는 이름이어도 "오늘"과 시각 표시가 예외로 멈추지 않게 합니다.
String pickKnownTimezone(
  Iterable<String?> candidates, {
  required void Function() onUnknown,
}) {
  for (final candidate in candidates) {
    if (candidate == null) {
      continue;
    }
    if (isKnownTimezone(candidate)) {
      return candidate;
    }
    onUnknown();
  }
  return fallbackTimezone;
}

/// 모르는 시간대를 건너뛴 일을 crash 요약으로만 남깁니다.
void reportUnknownTimezone(Ref ref) => ref
    .read(crashReporterProvider)
    .record(CrashSummary.from(const UnknownTimezone()), StackTrace.current);

/// [instant]를 [ianaTimezone]의 현지 시각으로 바꿉니다. 오프셋이 붙은 값과 UTC 값이
/// 같은 순간이면 같은 현지 시각입니다.
///
/// 모르는 IANA 이름이면 [ArgumentError]입니다(UTC로 대체하지 않습니다).
tz.TZDateTime localTimeIn(DateTime instant, String ianaTimezone) =>
    tz.TZDateTime.from(instant, _locationOf(ianaTimezone));

/// [clock]의 지금이 [ianaTimezone]에서 속한 달력 날짜(자정 기준)입니다.
///
/// 모르는 IANA 이름이면 [ArgumentError]입니다(UTC로 대체하지 않습니다).
CalendarDate todayIn(Clock clock, String ianaTimezone) {
  final local = tz.TZDateTime.from(clock.nowUtc(), _locationOf(ianaTimezone));
  return CalendarDate(local.year, local.month, local.day);
}

/// [ianaTimezone]의 날짜가 바뀔 때만 새 날짜를 내보냅니다.
///
/// 구독 시점의 현재 날짜는 내보내지 않습니다(현재 값은 [todayIn]으로 읽습니다).
/// [tick] 간격으로 [clock]을 확인하므로 자정 뒤 최대 [tick]만큼 늦게 알립니다.
/// 구독을 취소하면 폴링도 멈춥니다. 단일 구독 스트림이며 pause 중에도 폴링합니다.
/// 날짜 계산이 실패하면 스트림 오류로 전달합니다.
Stream<CalendarDate> dayChanges(
  Clock clock,
  String ianaTimezone, {
  Duration tick = const Duration(seconds: 30),
}) {
  Timer? timer;
  late final StreamController<CalendarDate> controller;
  controller = StreamController<CalendarDate>(
    onListen: () {
      var last = todayIn(clock, ianaTimezone);
      timer = Timer.periodic(tick, (_) {
        try {
          final current = todayIn(clock, ianaTimezone);
          if (current != last) {
            last = current;
            controller.add(current);
          }
        } on Object catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      });
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
    },
  );
  return controller.stream;
}

/// [date]의 [ianaTimezone] 현지 정오에 고정된 시계. fake 모드 시작 코드가 시나리오
/// `today`로 [clockProvider]를 override할 때 씁니다.
///
/// 모르는 IANA 이름이면 [ArgumentError]입니다.
Clock noonClockOn(CalendarDate date, String ianaTimezone) => FixedClock(
  tz.TZDateTime(_locationOf(ianaTimezone), date.year, date.month, date.day, 12),
);

/// 현재 시계. 기본은 기기 시계이고, fake 모드는 시작 코드(bootstrap)가 [noonClockOn]으로
/// override합니다.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// 기기 시간대를 읽지 못했을 때 쓰는 시간대.
const fallbackTimezone = 'Asia/Seoul';

/// 프로필 시간대(IANA). "오늘"의 기준입니다.
///
/// core의 기본값은 기기 시간대 → [fallbackTimezone]입니다. 프로필 사본을 가장 먼저
/// 보는 연결은 app 계층(`profileTimezoneOverrides`)이 override로 더합니다(결정 A18).
/// 모르는 이름은 건너뛰고([pickKnownTimezone]) crash 요약만 남깁니다.
final profileTimezoneProvider = Provider<String>(
  (ref) => pickKnownTimezone([
    ref.watch(deviceTimezoneNameProvider).value,
  ], onUnknown: () => reportUnknownTimezone(ref)),
);

/// 프로필 시간대 기준 오늘 날짜.
///
/// 시간이 흐르는 시계([Clock.advances])면 자정에 스스로 다시 계산됩니다.
final todayProvider = Provider<CalendarDate>((ref) {
  final clock = ref.watch(clockProvider);
  final timezone = ref.watch(profileTimezoneProvider);
  if (clock.advances) {
    final subscription = dayChanges(clock, timezone).listen(
      (_) => ref.invalidateSelf(),
      onError: (Object _) => ref.invalidateSelf(),
    );
    ref.onDispose(subscription.cancel);
  }
  return todayIn(clock, timezone);
});

/// 프로필 시간대의 벽시계 시각(분 단위, 초 이하는 0)을 매 분 0초에 내보냅니다.
///
/// 구독하면 현재 분을 바로 내보내고, 시간이 흐르는 시계([Clock.advances])면 다음 분
/// 경계마다 새 값을 내보냅니다. 값은 UTC 표기이지만 실제 순간이 아니라 프로필
/// 시간대의 벽시계 숫자입니다(기기 시간대와 섞여 정규화되지 않게 UTC 그릇에 담습니다).
final nowMinuteProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  final timezone = ref.watch(profileTimezoneProvider);
  return minuteTicks(clock, timezone);
});

/// [ianaTimezone] 벽시계의 현재 분을 내보내고, 이후 분이 바뀔 때마다 내보냅니다.
///
/// 값은 `DateTime.utc(연, 월, 일, 시, 분)` 모양의 벽시계입니다([nowMinuteProvider] 참고).
/// [Clock.advances]가 false면 현재 분 하나만 내보냅니다. 구독을 취소하면 타이머도
/// 멈춥니다. 계산이 실패하면 스트림 오류로 전달하고, 다음 분에 다시 시도합니다.
Stream<DateTime> minuteTicks(Clock clock, String ianaTimezone) {
  Timer? timer;
  late final StreamController<DateTime> controller;

  DateTime currentMinute() {
    final local = localTimeIn(clock.nowUtc(), ianaTimezone);
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  // 다음 분 경계까지의 대기. UTC 기준 초·밀리초로 셉니다(시간대 오프셋은 분 단위).
  Duration untilNextMinute() {
    final now = clock.nowUtc();
    return Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
      microseconds: -now.microsecond,
    );
  }

  void schedule(DateTime? emitted) {
    var delay = const Duration(minutes: 1);
    try {
      delay = untilNextMinute();
    } on Object catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
    timer = Timer(delay, () {
      var last = emitted;
      try {
        final now = currentMinute();
        if (now != last) {
          last = now;
          controller.add(now);
        }
      } on Object catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
      schedule(last);
    });
  }

  controller = StreamController<DateTime>(
    onListen: () {
      DateTime? first;
      try {
        first = currentMinute();
        controller.add(first);
      } on Object catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
      if (clock.advances) {
        schedule(first);
      }
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
    },
  );
  return controller.stream;
}
