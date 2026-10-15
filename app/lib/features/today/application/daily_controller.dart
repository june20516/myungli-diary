import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';
import 'package:myungli_diary/features/today/data/daily_repository.dart';

/// 그날 응답 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final dailyRepositoryProvider = Provider<DailyRepository>(
  (ref) => DailyRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
  ),
);

/// 오늘 화면이 그리는 값.
final class DailyView {
  /// [date]의 [daily]입니다. [stale]이면 캐시를 보이는 중입니다.
  const new({required this.date, required this.daily, required this.stale});

  /// 프로필 시간대 기준 날짜(`todayProvider`).
  final CalendarDate date;

  /// 그날 응답.
  final Daily daily;

  /// server 응답을 받지 못해(연결 오류·시간 초과) 캐시를 보이는 중인지.
  ///
  /// 화면은 이 값으로 오프라인 배너를 그립니다. server 응답을 기다리며 캐시를 먼저
  /// 보이는 동안은 false입니다(매번 배너가 깜빡이지 않게).
  final bool stale;
}

/// 오늘 응답과 그날 캐시(결정 A24, spec §4.4·§4.5).
///
/// 1. 기기 시간대 동기화([TimezoneSync.idle])가 끝나길 기다립니다. 사본과 "오늘"이
///    동기화 결과를 따르게 하기 위해서입니다.
/// 2. 프로필 사본이 있으면 키 `dailyKey(지문, 사본 language, 날짜)`의 캐시를 먼저 내보내고
///    server 응답으로 바꿉니다. 연결이 안 되면 그 캐시를 `stale`로 남깁니다.
/// 3. 사본이 없으면 캐시를 읽지도 쓰지도 않고 server 응답만 씁니다.
/// 4. 오늘 날짜 키만 봅니다. 어제 캐시를 오늘로 보이지 않습니다.
///
/// `todayProvider`(자정)와 사본(사주·시간대·언어 변경)을 구독하므로 둘이 바뀌면 다시 받습니다.
class DailyController extends AsyncNotifier<DailyView> {
  var _skipCacheOnce = false;
  String? _cacheKey;

  /// 지금 보이는(또는 받는 중인) 날의 캐시 키. 사본이 없으면 null입니다.
  ///
  /// 반응이 성공한 뒤 캐시를 고칠 때(`DailyRepository.patchCachedReaction`) 씁니다.
  String? get cacheKey => _cacheKey;

  @override
  Future<DailyView> build() async {
    // rebuild(자정·사본 변경·reload) 뒤에는 이 ref가 unmounted가 되어 오래된 build의
    // 중간 상태가 새 상태를 덮지 않습니다.
    final buildRef = ref;
    final skipCache = _skipCacheOnce;
    _skipCacheOnce = false;
    final date = ref.watch(todayProvider);
    final repository = ref.watch(dailyRepositoryProvider);

    await ref.read(timezoneSyncProvider).idle;
    if (!buildRef.mounted) {
      // 기다리는 동안 다시 build되었습니다. 이 결과는 Riverpod이 버립니다.
      throw StateError('오래된 build');
    }
    final key = await _cacheKeyFor(date);
    if (buildRef.mounted) {
      _cacheKey = key;
    }

    final result = await loadCacheFirst<Daily>(
      fetch: () => repository.fetch(date),
      readCache: key == null || skipCache ? null : () => repository.cached(key),
      writeCache: key == null ? null : (daily) => repository.store(key, daily),
      onCached: (daily) {
        if (buildRef.mounted) {
          state = AsyncData(DailyView(date: date, daily: daily, stale: false));
        }
      },
    );
    return DailyView(date: date, daily: result.value, stale: result.stale);
  }

  /// 캐시를 건너뛰고 다시 받습니다. 잠금 해제 뒤나 오류 화면의 다시 시도에서 부릅니다.
  ///
  /// 받는 동안 이전 값이 남고, 끝나면 돌아옵니다. 실패는 던지지 않고 상태(`AsyncError`)로
  /// 남깁니다. 연결이 안 되면 캐시로 대체하지 않고 오류입니다.
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
