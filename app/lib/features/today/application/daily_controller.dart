import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/today/application/reaction_epoch.dart';
import 'package:myungli_diary/features/today/data/daily_repository.dart';

/// 그날 응답 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final dailyRepositoryProvider = Provider<DailyRepository>(
  (ref) => DailyRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
    ref.watch(crashReporterProvider),
  ),
);

/// 오늘 화면이 그리는 값.
final class DailyView {
  /// [date]의 [daily]입니다. [stale]이면 캐시를 보이는 중입니다.
  const new({
    required this.date,
    required this.daily,
    required this.stale,
    required this.cacheKey,
    this.reactionEpoch = 0,
    this.fromCache = false,
  });

  /// 프로필 시간대 기준 날짜(`todayProvider`).
  final CalendarDate date;

  /// 그날 응답.
  final Daily daily;

  /// server 응답을 받지 못해(연결 오류·시간 초과) 캐시를 보이는 중인지.
  ///
  /// 화면은 이 값으로 오프라인 배너를 그립니다. server 응답을 기다리며 캐시를 먼저
  /// 보이는 동안은 false입니다(매번 배너가 깜빡이지 않게).
  final bool stale;

  /// 이 값을 둔 그날 캐시 키. 프로필 사본이 없어 캐시를 쓰지 않았으면 null입니다.
  final String? cacheKey;

  /// 이 값을 받기 시작한 때의 반응 확인 세대(`ReactionEpoch`).
  ///
  /// 이 세대보다 뒤에 server에서 확인된 반응은 이 응답에 반영되지 않았을 수 있습니다.
  final int reactionEpoch;

  /// 이 값이 server 응답이 아니라 캐시에서 온 것인지(캐시를 먼저 보이는 중이거나 연결이 안 되어
  /// 캐시를 남긴 때). server가 확인한 값이 아니므로 반응의 "확인된 값"으로 쓰지 않습니다.
  final bool fromCache;
}

/// 오래된 build가 남은 일을 멈출 때 돌려주는, 끝나지 않는 Future.
///
/// rebuild된 뒤 Riverpod은 이전 build의 결과를 쓰지 않으므로, 결과를 만들지 않고 멈춥니다.
Future<T> _abandoned<T>() => Completer<T>().future;

/// 오늘 응답과 그날 캐시(결정 A24, spec §4.4·§4.5).
///
/// 1. 기기 시간대 동기화([TimezoneSync.syncIfChanged])를 기다립니다. 화면이 셸보다 먼저
///    읽어도 동기화가 먼저입니다. 진행 중이면 그것을 기다리고, 바뀐 것이 없으면 요청하지
///    않습니다. 사본과 "오늘"이 동기화 결과를 따르게 하기 위해서입니다.
/// 2. 프로필 사본이 있으면 키 `dailyKey(지문, 사본 language, 날짜)`의 캐시를 먼저 내보내고
///    server 응답으로 바꿉니다. 연결이 안 되면 그 캐시를 `stale`로 남깁니다.
/// 3. 사본이 없으면 캐시를 읽지도 쓰지도 않고 server 응답만 씁니다. 규칙 버전 관찰은
///    키와 무관하게 응답마다 합니다(`DailyRepository.fetch`).
/// 4. 오늘 날짜 키만 봅니다. 어제 캐시를 오늘로 보이지 않습니다.
///
/// `todayProvider`(자정)와 사본(사주·시간대·언어 변경)을 구독하므로 둘이 바뀌면 다시 받습니다.
/// rebuild되면 이전 build는 다음 단계(fetch·store·중간 상태)로 가지 않고 멈춥니다.
class DailyController extends AsyncNotifier<DailyView> {
  var _skipCacheOnce = false;

  /// 지금 보이는 값의 캐시 키. 값이 없거나 사본이 없으면 null입니다.
  ///
  /// 다시 받는 중(자정 넘김 등)에는 아직 이전 날짜 값을 보이므로 그 날짜의 키입니다.
  /// 반응이 성공한 뒤 캐시를 고칠 때(`DailyRepository.patchCachedReaction`) 씁니다.
  String? get cacheKey => state.value?.cacheKey;

  /// 지금 build의 결과 Future. 캐시를 먼저 내보내면 [future]는 그 캐시 값으로 끝나므로,
  /// server 응답까지 기다릴 때([_settleCurrentBuild])는 이것을 기다립니다.
  Future<DailyView>? _currentBuild;

  /// 지금 build가 다음 build로 대체되면 끝나는 신호. 대체된 build는 끝나지 않으므로
  /// 기다리던 쪽이 새 build로 넘어가게 합니다.
  Completer<void>? _superseded;

  @override
  Future<DailyView> build() {
    _superseded?.complete();
    _superseded = Completer<void>();
    return _currentBuild = _load();
  }

  Future<DailyView> _load() async {
    // rebuild(자정·사본 변경·reload) 뒤에는 이 ref가 unmounted가 됩니다.
    final buildRef = ref;
    bool superseded() => !buildRef.mounted;
    final skipCache = _skipCacheOnce;
    _skipCacheOnce = false;
    final date = ref.watch(todayProvider);
    final repository = ref.watch(dailyRepositoryProvider);
    final reporter = ref.watch(crashReporterProvider);

    await ref.read(timezoneSyncProvider).syncIfChanged();
    if (superseded()) {
      return await _abandoned();
    }
    final key = await _cacheKeyFor(date);
    if (superseded()) {
      return await _abandoned();
    }

    // 캐시를 읽고 받기 시작하기 전의 세대. 그 뒤에 확인된 반응은 이 응답이 모를 수 있습니다.
    final epoch = ref.read(reactionEpochProvider).value;
    DailyView viewOf(
      Daily daily, {
      required bool stale,
      bool fromCache = false,
    }) => DailyView(
      date: date,
      daily: daily,
      stale: stale,
      cacheKey: key,
      reactionEpoch: epoch,
      fromCache: fromCache,
    );
    final result = await loadCacheFirst<Daily>(
      reporter: reporter,
      fetch: () => superseded() ? _abandoned() : repository.fetch(date),
      readCache: key == null || skipCache ? null : () => repository.cached(key),
      writeCache: key == null
          ? null
          : (daily) async {
              if (!superseded()) {
                await repository.store(key, daily);
              }
            },
      onCached: (daily) {
        if (!superseded()) {
          state = AsyncData(viewOf(daily, stale: false, fromCache: true));
        }
      },
    );
    return viewOf(result.value, stale: result.stale, fromCache: result.stale);
  }

  /// 캐시를 건너뛰고 다시 받습니다. 오류 화면의 다시 시도에서 부릅니다. 잠금 해제 뒤에는
  /// 화면 상태를 건드리지 않는 [refreshQuietly]를 씁니다.
  ///
  /// 받는 동안 이전 값이 남고, 끝나면 돌아옵니다. 실패는 던지지 않고 상태(`AsyncError`)로
  /// 남깁니다. 연결이 안 되면 캐시로 대체하지 않습니다. 이것은 의도한 동작입니다. 다시 받기를
  /// 요청한 것이므로 이전 값을 가진 `AsyncError`로 실패를 알리고, 화면은 이전 값을 둔 채
  /// 오류를 안내합니다.
  Future<void> reload() async {
    if (!ref.mounted) {
      return;
    }
    _skipCacheOnce = true;
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // 오류는 상태로 화면에 보입니다.
    }
  }

  /// 화면 상태를 진행 중·오류로 바꾸지 않고 캐시를 건너뛰어 다시 받습니다(잠금 해제 뒤).
  ///
  /// 성공하면 값과 그날 캐시를 바꿉니다. 실패하면 상태는 이전 값 그대로 두고 오류([AppError])를
  /// 호출자에게만 던집니다. 오류를 보일 곳은 호출자(근거 시트)이고, 오늘 화면이 같은 실패를
  /// 다시 알리지 않게 하기 위해서입니다. 보이는 값이 없거나, 받는 중이거나, 날짜가 바뀌었으면
  /// 지킬 이전 값이 없으므로 [reload]와 같고, 그 결과가 오류면 그 오류를 던집니다.
  Future<void> refreshQuietly() async {
    final callRef = ref;
    final current = state.value;
    final date = ref.read(todayProvider);
    if (current == null || state.isLoading || current.date != date) {
      await reload();
      // reload는 다시 build하므로 결과는 새 build의 상태(현재 ref·state)에서 읽습니다.
      _throwIfFailed();
      return;
    }
    final repository = ref.read(dailyRepositoryProvider);
    final reporter = ref.read(crashReporterProvider);
    final epoch = ref.read(reactionEpochProvider).value;
    final daily = await repository.fetch(date);
    // 그사이 다시 build됐으면(자정·사본 변경) 받은 값을 버리고 그 build의 결과를 기다려 따릅니다.
    if (!callRef.mounted) {
      await _settleCurrentBuild();
      return;
    }
    final key = current.cacheKey;
    if (key != null) {
      await writeCacheOrReport(() => repository.store(key, daily), reporter);
      if (!callRef.mounted) {
        await _settleCurrentBuild();
        return;
      }
    }
    state = AsyncData(
      DailyView(
        date: date,
        daily: daily,
        stale: false,
        cacheKey: key,
        reactionEpoch: epoch,
      ),
    );
  }

  /// 지금 build가 server 응답(또는 오류)까지 끝나길 기다리고, 실패했으면 그 오류를 던집니다
  /// ([refreshQuietly]가 대체됐을 때).
  ///
  /// [future]는 build가 캐시를 먼저 내보내면 그 값으로 끝나므로 build의 결과 Future를 기다립니다.
  /// 기다리는 사이 build가 다시 대체되면 새 build를 이어서 기다립니다.
  Future<void> _settleCurrentBuild() async {
    if (!ref.mounted) {
      return;
    }
    try {
      // 다시 build가 아직 시작되지 않았으면(invalidate 뒤 아무도 읽지 않음) 여기서 시작합니다.
      await future;
    } on Object {
      // 결과는 아래에서 상태로 읽습니다.
    }
    while (ref.mounted) {
      final build = _currentBuild;
      final superseded = _superseded;
      if (build == null || superseded == null) {
        break;
      }
      final finished = await Future.any<bool>([
        build.then((_) => true, onError: (Object _) => true),
        superseded.future.then((_) => false),
      ]);
      if (finished) {
        break;
      }
    }
    _throwIfFailed();
  }

  /// 지금 상태가 오류면 그 오류를 [AppError]로 던집니다. 이미 버려졌으면 아무것도 하지 않습니다.
  void _throwIfFailed() {
    if (!ref.mounted) {
      return;
    }
    final error = state.error;
    if (error != null) {
      throw error is AppError ? error : UnexpectedError(error);
    }
  }

  /// 사본으로 만든 [date]의 캐시 키. 사본이 없거나 읽지 못하면 null입니다.
  ///
  /// 동기화가 끝난 뒤 구독해, 동기화로 바뀐 사본에 다시 build되지 않게 합니다.
  Future<String?> _cacheKeyFor(CalendarDate date) async {
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
    return dailyKey(
      fingerprint: sajuFingerprint(profile),
      language: profile.language.value,
      date: date.toIso(),
    );
  }
}

/// 오늘 응답. 화면·반응·잠금 해제·공유가 이 controller 하나를 거칩니다.
///
/// 자동 재시도는 끕니다. 실패는 오류 상태로 남기고 화면의 다시 시도([DailyController.reload])로만
/// 다시 받습니다(진입 계산과 같은 방식).
final dailyControllerProvider =
    AsyncNotifierProvider<DailyController, DailyView>(
      DailyController.new,
      retry: (_, _) => null,
    );
