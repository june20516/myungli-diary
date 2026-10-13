import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
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

/// 현재 시계. fake 모드는 시나리오 `today`의 현지 정오에 고정하고, http 모드는 기기 시계입니다.
final clockProvider = Provider<Clock>((ref) {
  if (ref.watch(apiModeProvider) == ApiMode.http) {
    return const SystemClock();
  }
  final scenario = ref.watch(scenarioProvider);
  final today = scenario.today;
  final noon = tz.TZDateTime(
    _locationOf(scenario.timezone),
    today.year,
    today.month,
    today.day,
    12,
  );
  return FixedClock(noon);
});

/// 프로필 시간대(IANA). "오늘"의 기준입니다.
///
/// fake 모드는 시나리오 timezone입니다. http 모드는 임시로 `Asia/Seoul`이며
/// 계획 2에서 프로필 값으로 교체합니다.
final profileTimezoneProvider = Provider<String>((ref) {
  if (ref.watch(apiModeProvider) == ApiMode.fake) {
    return ref.watch(scenarioProvider).timezone;
  }
  return 'Asia/Seoul';
});

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
