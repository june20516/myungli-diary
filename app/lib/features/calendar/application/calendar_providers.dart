import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_day.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/calendar/data/calendar_repository.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';

/// 달 길흉 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
    ref.watch(crashReporterProvider),
  ),
);

/// 한 달의 길흉(A32). 달마다 따로 들고 있어, 늦게 온 응답이 다른 달 상태를 바꾸지 않습니다.
///
/// 1. 기기 시간대 동기화([TimezoneSync.syncIfChanged])를 먼저 기다립니다(사본이 동기화
///    결과를 따르게).
/// 2. 프로필 사본이 있으면 키 `calendarKey(지문, 사본 language, 연, 월)`로 캐시를 쓰고,
///    없으면 키 없이(캐시 없이) 받습니다([CalendarRepository.month]).
///
/// 캐시 근거(#219 ④): server 응답에 ETag가 없으므로 조건부 요청 없이, 출생 정보·언어·ruleset
/// 변경이 곧 무효화입니다. 출생 정보·시간대는 지문, 언어는 키의 language, ruleset은
/// `observeRulesetVersion`이 맡습니다.
///
/// 같은 달을 동시에 읽으면 요청은 하나입니다(family 하나를 함께 기다림). 사본(사주·시간대·언어)이
/// 바뀌면 다시 계산합니다. 구독이 모두 끝나면 버려지므로(autoDispose) 메모리에는 보이는 달과
/// 그 앞뒤 달만 남고, 다음 진입은 영구 캐시에서 다시 읽습니다. 그래서 그사이 규칙 변경·잠금
/// 해제로 지워진 달은 다음 진입에서 새로 받습니다.
///
/// 자동 재시도는 끕니다. 실패는 오류 상태로 남기고 화면의 다시 시도(`ref.invalidate`)로만
/// 다시 받습니다(`dailyControllerProvider`와 같은 방식).
final FutureProviderFamily<Calendar, CalendarMonth> calendarMonthProvider =
    FutureProvider.autoDispose.family<Calendar, CalendarMonth>((
      ref,
      month,
    ) async {
      final repository = ref.watch(calendarRepositoryProvider);
      // 요청을 시작할 때의 잠금 정리 세대. 그사이 정리됐으면 잠긴 응답은 저장하지 않습니다.
      final unlockSync = ref.read(calendarUnlockSyncProvider);
      final generation = unlockSync.generation;
      await ref.read(timezoneSyncProvider).syncIfChanged();
      final key = await _cacheKeyFor(ref, month);
      return await repository.month(
        month,
        cacheKey: key,
        mayStoreLocked: () => unlockSync.generation == generation,
      );
    }, retry: (_, _) => null);

/// 하루의 길흉(`day-sheet` 날의 성격). 그 날이 든 달의 [calendarMonthProvider]에서 고릅니다.
///
/// 달을 따로 받지 않으므로 달력이 이미 그 달을 들고 있으면 요청이 없고, 없으면 그 달 하나를
/// 받아(영구 캐시 포함) 함께 씁니다. 달이 실패하면 같은 오류이고, 다시 시도는 그 달을
/// invalidate합니다. 응답에 그 날이 없으면 [StateError]입니다.
final FutureProviderFamily<CalendarDay, CalendarDate> calendarDayProvider =
    FutureProvider.autoDispose.family<CalendarDay, CalendarDate>((
      ref,
      date,
    ) async {
      final calendar = await ref.watch(
        calendarMonthProvider(CalendarMonth.of(date)).future,
      );
      final iso = date.toIso();
      for (final day in calendar.days) {
        if (day.date == iso) {
          return day;
        }
      }
      throw StateError('달 길흉 응답에 그 날이 없습니다.');
    }, retry: (_, _) => null);

/// 보이는 달 `visible`의 앞뒤 한 달을 조용히 받아 둡니다(A32). 화면이 보이는 달마다 구독합니다.
///
/// 지원 범위(1900-01~2099-12) 밖의 달은 받지 않습니다. 받은 달은 이 provider가 구독하는 동안
/// 메모리에 남습니다. 실패는 무시합니다. 실패한 달은 구독을 닫아 오류 상태가 버려지게 하므로,
/// 화면이 그 달을 열 때 다시 받습니다(이미 화면이 그 달을 구독 중이면 그 오류는 화면 몫입니다).
/// 오류는 [calendarMonthProvider]의 오류이므로 따로 보고하지 않습니다.
final FutureProviderFamily<void, CalendarMonth> calendarPrefetchProvider =
    FutureProvider.autoDispose.family<void, CalendarMonth>((
      ref,
      visible,
    ) async {
      final neighbors = [
        visible.previous(),
        visible.next(),
      ].where((month) => month.isSupported);
      await Future.wait([for (final month in neighbors) _prefetch(ref, month)]);
    });

/// [month]를 구독해 받아 둡니다. 실패하면 구독을 닫고 조용히 끝납니다.
Future<void> _prefetch(Ref ref, CalendarMonth month) async {
  final provider = calendarMonthProvider(month);
  final subscription = ref.listen(provider, (_, _) {});
  try {
    await ref.read(provider.future);
  } on Object {
    subscription.close();
  }
}

/// 근거 열람 권한이 생긴 뒤 달 길흉을 맞춥니다(A32).
final calendarUnlockSyncProvider = Provider<CalendarUnlockSync>(
  CalendarUnlockSync.new,
);

/// 잠금 해제에 성공한 뒤 `locked`로 받아 둔 달을 버리는 일.
final class CalendarUnlockSync {
  /// [_ref]로 저장소와 달 상태에 닿습니다.
  new(this._ref);

  final Ref _ref;

  /// [forgetLocked]가 불린 횟수(잠금 정리 세대).
  ///
  /// 달 요청은 시작할 때 이 값을 기억하고, 응답을 쓰기 직전에 값이 바뀌었으면 `locked`
  /// 응답을 저장하지 않습니다(정리 전에 출발한 요청이 지운 달을 다시 쓰지 않게).
  int get generation => _generation;
  var _generation = 0;

  /// `locked`로 받아 둔 달 캐시를 지우고, 들고 있는 달을 모두 다시 계산하게 합니다.
  ///
  /// 잠금이 풀린 달은 캐시 그대로 읽으므로 다시 요청하지 않고, 지운 달만 다시 받습니다.
  /// 여러 번 불려도 됩니다(지울 것이 없으면 캐시를 다시 읽을 뿐입니다). 실패는 비치명입니다.
  /// 잠금 해제 흐름을 막지 않도록 요약만 보고하고 삼킵니다.
  Future<void> forgetLocked() async {
    // 지우기 전에 세대를 올려, 지우는 사이에 도착한 잠긴 응답도 쓰지 않게 합니다.
    _generation++;
    final reporter = _ref.read(crashReporterProvider);
    try {
      await _ref.read(calendarRepositoryProvider).dropLocked();
    } on Object catch (error, stack) {
      reporter.record(CrashSummary.from(error), stack);
      return;
    }
    _ref.invalidate(calendarMonthProvider);
  }
}

/// 사본으로 만든 [month]의 캐시 키. 사본이 없거나 읽지 못하면 null입니다.
///
/// 동기화가 끝난 뒤 구독해, 동기화로 바뀐 사본에 다시 계산되지 않게 합니다.
Future<String?> _cacheKeyFor(Ref ref, CalendarMonth month) async {
  Profile? profile;
  try {
    profile = await ref.watch(cachedProfileProvider.future);
  } on Object {
    // 사본을 읽지 못하면 사본이 없을 때처럼 캐시 없이 받습니다.
    profile = null;
  }
  if (profile == null) {
    return null;
  }
  return calendarKey(
    fingerprint: sajuFingerprint(profile),
    language: profile.language.value,
    year: month.year,
    month: month.month,
  );
}
