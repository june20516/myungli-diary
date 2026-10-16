import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';

/// [loadCacheFirst]의 결과. `stale`이면 server 응답을 받지 못해 캐시를 보이는 중입니다.
typedef CacheFirstResult<T> = ({T value, bool stale});

/// 캐시로 대체할 오류인지. 연결이 안 되거나 시간이 초과됐을 때만입니다.
///
/// server가 오류로 답한 것(`ProblemError`)은 캐시로 가리지 않고 그대로 알립니다.
bool isConnectivityError(Object error) =>
    error is OfflineError || error is TimeoutError;

/// 캐시 쓰기를 비치명으로 실행합니다. 실패하면 [reporter]에 요약만 남기고 삼킵니다.
///
/// 캐시는 다음 표시를 빠르게 하려는 것이라, 쓰기가 실패해도 받은 응답은 그대로 보입니다.
/// 다음 응답이 다시 쓰므로 회복됩니다. 캐시를 쓰는 저장소가 모두 이 정책을 따릅니다.
Future<void> writeCacheOrReport(
  Future<void> Function() write,
  CrashReporter reporter,
) async {
  try {
    await write();
  } on Object catch (error, stack) {
    reporter.record(CrashSummary.from(error), stack);
  }
}

/// "캐시 먼저 → server 응답으로 교체 → 연결이 안 되면 캐시(stale)" 흐름입니다.
///
/// 데이터 종류와 무관합니다. 그날 캐시(오늘)와 사주 기반 캐시(달력·나의 사주)가 함께 씁니다.
///
/// 1. [readCache]가 값을 주면 [onCached]로 먼저 알립니다. [readCache]가 null이면 캐시를
///    보지 않습니다(캐시 키가 없을 때나 캐시를 건너뛰고 다시 받을 때).
/// 2. [fetch]가 성공하면 [writeCache]로 쓰고 `stale: false`로 돌려줍니다. 쓰기 실패는
///    [writeCacheOrReport] 정책대로 [reporter]에 남기고 받은 값을 그대로 돌려줍니다.
/// 3. [fetch]가 연결 오류([isConnectivityError])로 실패하고 캐시가 있으면 캐시를
///    `stale: true`로 돌려줍니다. 그 밖의 실패는 그대로 던집니다.
Future<CacheFirstResult<T>> loadCacheFirst<T extends Object>({
  required Future<T> Function() fetch,
  required CrashReporter reporter,
  Future<T?> Function()? readCache,
  Future<void> Function(T fresh)? writeCache,
  void Function(T cached)? onCached,
}) async {
  final cached = readCache == null ? null : await readCache();
  if (cached != null) {
    onCached?.call(cached);
  }
  final T fresh;
  try {
    fresh = await fetch();
  } on Object catch (error) {
    if (cached != null && isConnectivityError(error)) {
      return (value: cached, stale: true);
    }
    rethrow;
  }
  if (writeCache != null) {
    await writeCacheOrReport(() => writeCache(fresh), reporter);
  }
  return (value: fresh, stale: false);
}
