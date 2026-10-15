import 'package:myungli_diary/core/api/app_error.dart';

/// [loadCacheFirst]의 결과. `stale`이면 server 응답을 받지 못해 캐시를 보이는 중입니다.
typedef CacheFirstResult<T> = ({T value, bool stale});

/// 캐시로 대체할 오류인지. 연결이 안 되거나 시간이 초과됐을 때만입니다.
///
/// server가 오류로 답한 것(`ProblemError`)은 캐시로 가리지 않고 그대로 알립니다.
bool isConnectivityError(Object error) =>
    error is OfflineError || error is TimeoutError;

/// "캐시 먼저 → server 응답으로 교체 → 연결이 안 되면 캐시(stale)" 흐름입니다.
///
/// 데이터 종류와 무관합니다. 그날 캐시(오늘)와 사주 기반 캐시(달력·나의 사주)가 함께 씁니다.
///
/// 1. [readCache]가 값을 주면 [onCached]로 먼저 알립니다. [readCache]가 null이면 캐시를
///    보지 않습니다(캐시 키가 없을 때나 캐시를 건너뛰고 다시 받을 때).
/// 2. [fetch]가 성공하면 [writeCache]로 쓰고 `stale: false`로 돌려줍니다.
/// 3. [fetch]가 연결 오류([isConnectivityError])로 실패하고 캐시가 있으면 캐시를
///    `stale: true`로 돌려줍니다. 그 밖의 실패는 그대로 던집니다.
Future<CacheFirstResult<T>> loadCacheFirst<T extends Object>({
  required Future<T> Function() fetch,
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
  await writeCache?.call(fresh);
  return (value: fresh, stale: false);
}
