import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/diary_summary.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/cache_first.dart';
import 'package:myungli_diary/features/diary/data/diary_repository.dart';
import 'package:myungli_diary/features/diary/model/diary_write_entry.dart';

/// 일기 저장소. 로그인한 계정에서만 읽을 수 있습니다.
final diaryRepositoryProvider = Provider<DiaryRepository>(
  (ref) => DiaryRepository(ref.watch(restClientProvider)),
);

/// [CalendarDate] 날에 쓴 일기 요약. server 순서(같은 날은 작성 순) 그대로입니다.
///
/// `day-sheet`와 오늘 화면의 일기 입구(보기/쓰기, [DiaryWriteEntry])를 정합니다. 일기가
/// 없으면 server가 빈 목록을 줍니다. 받지 못해도 빈 목록(0편)으로 그려 쓰기를 막지 않고, 연결 없음·
/// 시간 초과·server problem은 예상한 실패라 조용히 넘기며, 그 밖의 오류(응답을 읽지 못함,
/// 프로그래밍 오류)만 비정상 종료 보고에 [CrashSummary]로 남깁니다(D64: 값은 싣지 않음).
/// 저장하지 않고(A45) 구독이 끝나면 버립니다(autoDispose). 일기를 쓰거나 지우고 돌아온 화면은
/// 이 날을 invalidate해 다시 묻습니다. 미래 날은 일기 입구가 없으므로(D49) 쓰는 쪽이 묻지
/// 않습니다. 자동 재시도는 끕니다.
final FutureProviderFamily<List<DiarySummary>, CalendarDate> diariesOnProvider =
    FutureProvider.autoDispose.family<List<DiarySummary>, CalendarDate>(
      _diariesOrEmpty,
      retry: (_, _) => null,
    );

/// [date] 일기 요약. 실패는 빈 목록이고 예상하지 못한 오류만 보고합니다.
Future<List<DiarySummary>> _diariesOrEmpty(Ref ref, CalendarDate date) async {
  final repository = ref.watch(diaryRepositoryProvider);
  try {
    return await repository.diariesOn(date);
  } on Object catch (error, stackTrace) {
    if (!_expectedFailure(error)) {
      ref
          .read(crashReporterProvider)
          .record(CrashSummary.from(error), stackTrace);
    }
    return const <DiarySummary>[];
  }
}

/// 보이는 달 [CalendarMonth] 격자에서 일기를 쓴 날짜. 범위는 지원 날짜로 자른 격자
/// (`supportedGridStart`~`supportedGridEnd`, D41)입니다. 달력 도장(V19)을
/// 찍습니다(A33).
///
/// 저장하지 않습니다(구독이 끝나면 버림, 다음 진입에서 다시 물음). 실패하면 빈 집합이라
/// 도장 없이 그리고, 오류는 crash 요약으로만 남깁니다(A33). 연결 없음·시간 초과는 통신
/// 환경 탓이라 남기지 않고([isConnectivityError]), server problem은 남깁니다. 자동 재시도는 끕니다.
/// 일기를 쓰고 돌아온 화면은 그 달을 invalidate해 다시 묻습니다.
final FutureProviderFamily<Set<CalendarDate>, CalendarMonth>
diaryDatesProvider = FutureProvider.autoDispose
    .family<Set<CalendarDate>, CalendarMonth>((ref, month) async {
      final repository = ref.watch(diaryRepositoryProvider);
      try {
        return await repository.datesIn(
          month.supportedGridStart,
          month.supportedGridEnd,
        );
      } on Object catch (error, stackTrace) {
        if (!isConnectivityError(error)) {
          ref
              .read(crashReporterProvider)
              .record(CrashSummary.from(error), stackTrace);
        }
        return const <CalendarDate>{};
      }
    }, retry: (_, _) => null);

/// 통신 환경이나 server가 알린 실패인지(보고하지 않음).
bool _expectedFailure(Object error) =>
    error is OfflineError || error is TimeoutError || error is ProblemError;
