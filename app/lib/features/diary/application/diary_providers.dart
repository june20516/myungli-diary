import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';

/// 일기 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(ref.watch(restClientProvider)),
);

/// 오늘(`todayProvider`) 일기를 썼는지. 가이드 질문 카드의 쓰기 전·후를 정합니다.
///
/// 404면 false입니다. 실패해도 false(쓰기 전)로 그려 화면을 막지 않습니다. 연결 없음·시간
/// 초과·server problem은 예상한 실패라 조용히 넘기고, 그 밖의 오류(응답을 읽지 못함,
/// 프로그래밍 오류)는 비정상 종료 보고에 [CrashSummary]로 남깁니다(D64: 값은 싣지 않음).
/// 일기를 쓰고 돌아온 화면은 이 provider를 invalidate해 다시 묻고, 자정이 지나면 새
/// 날짜로 다시 묻습니다.
final todayDiaryExistsProvider = FutureProvider<bool>((ref) async {
  final date = ref.watch(todayProvider);
  final repository = ref.watch(diaryRepositoryProvider);
  try {
    return await repository.existsOn(date);
  } on Object catch (error, stackTrace) {
    if (!_expectedFailure(error)) {
      ref
          .read(crashReporterProvider)
          .record(CrashSummary.from(error), stackTrace);
    }
    return false;
  }
});

/// 보이는 달 [CalendarMonth] 격자(gridStart~gridEnd)에서 일기를 쓴 날짜. 달력 도장(V19)을
/// 찍습니다(A33).
///
/// 저장하지 않습니다(구독이 끝나면 버림, 다음 진입에서 다시 물음). 실패하면 빈 집합이라
/// 도장 없이 그리고, 오류는 연결 없음까지 모두 crash 요약으로만 남깁니다(A33). 자동 재시도는
/// 끕니다. 일기를 쓰고 돌아온 화면은 그 달을 invalidate해 다시 묻습니다.
final FutureProviderFamily<Set<CalendarDate>, CalendarMonth>
diaryDatesProvider = FutureProvider.autoDispose
    .family<Set<CalendarDate>, CalendarMonth>((ref, month) async {
      final repository = ref.watch(diaryRepositoryProvider);
      try {
        return await repository.datesIn(month.gridStart, month.gridEnd);
      } on Object catch (error, stackTrace) {
        ref
            .read(crashReporterProvider)
            .record(CrashSummary.from(error), stackTrace);
        return const <CalendarDate>{};
      }
    }, retry: (_, _) => null);

/// 통신 환경이나 server가 알린 실패인지(보고하지 않음).
bool _expectedFailure(Object error) =>
    error is OfflineError || error is TimeoutError || error is ProblemError;
