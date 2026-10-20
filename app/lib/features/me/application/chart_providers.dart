import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/chart.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/notice_code.dart';
import 'package:myungli_diary/core/api/gen/model/personal_reading.dart';
import 'package:myungli_diary/core/api/gen/model/position.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/api/gen/model/shinsal_kind.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/features/me/data/chart_repository.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/application/timezone_sync.dart';

/// 나의 사주 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final chartRepositoryProvider = Provider<ChartRepository>(
  (ref) => ChartRepository(
    ref.watch(restClientProvider),
    ref.watch(cacheStoreProvider),
    ref.watch(crashReporterProvider),
  ),
);

/// 나의 사주(A56). `my-saju`·`saju-chart`·근거 시트가 함께 씁니다.
///
/// 1. 기기 시간대 동기화([TimezoneSync.syncIfChanged])를 먼저 기다립니다.
/// 2. 프로필 사본이 있으면 키 `chartKey(지문, 사본 language, 오늘의 연도)`로 캐시를 쓰고, 없으면
///    키 없이 받습니다. 오늘([todayProvider])이 해를 넘기면 새 연도로 다시 받습니다(세운 표).
///
/// 자동 재시도는 끕니다. 실패는 오류 상태로 남기고 화면의 다시 시도([ChartController.reload])로만
/// 다시 받습니다.
final AsyncNotifierProvider<ChartController, Chart> chartControllerProvider =
    AsyncNotifierProvider.autoDispose<ChartController, Chart>(
      ChartController.new,
      retry: (_, _) => null,
    );

/// [chartControllerProvider]의 notifier.
final class ChartController extends AsyncNotifier<Chart> {
  /// 다음 build 한 번은 캐시를 건너뜁니다([reload]).
  bool _skipCacheOnce = false;

  @override
  Future<Chart> build() async {
    final year = ref.watch(todayProvider).year;
    final skipCache = _skipCacheOnce;
    _skipCacheOnce = false;
    await ref.read(timezoneSyncProvider).syncIfChanged();
    final key = await _cacheKey(year);
    return await ref
        .watch(chartRepositoryProvider)
        .chart(cacheKey: key, skipCache: skipCache);
  }

  /// 캐시를 건너뛰고 다시 받습니다(오류 화면의 다시 시도). 실패는 상태로 남습니다.
  Future<void> reload() async {
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
  /// 성공하면 값을 바꾸고, 실패하면 이전 값을 두고 오류([AppError])를 호출자에게만 던집니다.
  /// 보이는 값이 없거나 받는 중이면 [reload]와 같고, 그 결과가 오류면 그 오류를 던집니다.
  Future<void> refreshQuietly() async {
    if (state.value == null || state.isLoading) {
      await reload();
      final error = ref.mounted ? state.error : null;
      if (error != null) {
        throw error is AppError ? error : UnexpectedError(error);
      }
      return;
    }
    final key = await _cacheKey(ref.read(todayProvider).year);
    final fresh = await ref
        .read(chartRepositoryProvider)
        .chart(cacheKey: key, skipCache: true);
    if (ref.mounted) {
      state = AsyncData(fresh);
    }
  }

  /// 사본으로 만든 [year]의 캐시 키. 사본이 없거나 읽지 못하면 null입니다.
  Future<String?> _cacheKey(int year) async {
    Profile? profile;
    try {
      profile = await ref.watch(cachedProfileProvider.future);
    } on Object {
      profile = null;
    }
    if (profile == null) {
      return null;
    }
    return chartKey(
      fingerprint: sajuFingerprint(profile),
      language: profile.language.value,
      year: year,
    );
  }
}

/// 근거 열람 권한이 생긴 뒤 잠긴 채 받아 둔 차트를 버리고, 들고 있는 차트가 잠겨 있으면 다시
/// 받게 합니다(A56). 실패는 비정상 종료 보고에 남기고 삼킵니다(달력 정리와 같음).
Future<void> forgetLockedCharts(Ref ref) async {
  try {
    await ref.read(chartRepositoryProvider).dropLocked();
  } on Object catch (error, stack) {
    ref.read(crashReporterProvider).record(CrashSummary.from(error), stack);
  }
  // 아무도 차트를 들고 있지 않으면 새로 만들지 않습니다(다음 진입이 캐시 없이 새로 받음).
  if (!ref.exists(chartControllerProvider)) {
    return;
  }
  final held = ref.read(chartControllerProvider).value;
  if (held != null && held.evidenceAccess == EvidenceAccess.locked) {
    ref.invalidate(chartControllerProvider);
  }
}

/// [chart]의 원국 개인 해석 중 누른 용어와 같은 항목(A58). 없으면(잠김·원고 없음) null입니다.
///
/// 항목은 (`kind`, `position`, `index`, `shinsal`)로 찾습니다. 항목에 없는 값은 비교하지 않습니다.
PersonalReading? personalReadingOf(
  Chart chart, {
  required PersonalReadingKindEnum kind,
  Position? position,
  int? index,
  ShinsalKind? shinsal,
}) {
  for (final reading in chart.personalReadings ?? const <PersonalReading>[]) {
    if (reading.kind != kind) continue;
    if (position != null && reading.position != position) continue;
    if (index != null && reading.index != index) continue;
    if (shinsal != null && reading.shinsal != shinsal) continue;
    return reading;
  }
  return null;
}

/// 나의 사주가 태어난 시간을 모른 채 계산됐는지(시주 없음). `my-saju`·`saju-chart`가 같은 판정을
/// 씁니다. server는 시주를 빼면 `time_unknown` 안내를 함께 보내므로 둘 중 하나면 참입니다.
///
/// 안내 문구의 출처는 IA 슬롯마다 다릅니다. `my-saju`는 그 상태의 ui 슬롯이 없어 server
/// 안내 문장(`Notice.text`)을, `saju-chart`는 ui 슬롯
/// `saju-chart.time-unknown.notice`(ARB)를 보입니다.
bool chartTimeUnknown(Chart chart) =>
    chart.pillars.hour == null ||
    chart.notices.any((notice) => notice.code == NoticeCode.timeUnknown);
