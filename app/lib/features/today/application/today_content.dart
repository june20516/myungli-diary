import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/platform/crash_reporter.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/today_presentation.dart';

/// 오늘 화면이 그리는 데 필요한 값 묶음.
final class TodayContent {
  /// 오늘 응답 [view], 이름 사전 [names], 오늘 일기 여부 [diaryWritten]입니다.
  const new({
    required this.view,
    required this.names,
    required this.diaryWritten,
  });

  /// 오늘 응답과 캐시 여부.
  final DailyView view;

  /// 값 이름 사전.
  final GlossaryNames names;

  /// 오늘 일기를 썼는지.
  final bool diaryWritten;
}

/// 값이 없고 다시 받는 중도 아닌 실패인지.
bool _failed(AsyncValue<Object?> value) =>
    !value.hasValue && value.hasError && !value.isLoading;

/// 세 비동기 값을 오늘 화면 한 값으로 묶습니다.
///
/// * 오늘 응답과 이름 사전이 모두 있어야 그립니다(결정 A27). 일기 여부도 기다려, 처음부터
///   쓴 날이면 도장이 찍히는 움직임 없이 `after`로 그립니다(실패하면 false라 늘 끝납니다).
/// * 응답 날짜가 [today]와 다르면(화면을 연 채 자정을 넘겨 다시 받는 중) 어제 풀이를 오늘로
///   보이지 않고 불러오는 중으로 둡니다(spec §4.5). 다시 받기가 실패했으면 오류입니다.
/// * 값이 생긴 뒤의 갱신·오류 표시(오프라인 배너 등)는 오늘 응답의 상태를 그대로 따릅니다.
AsyncValue<TodayContent> todayContentOf({
  required CalendarDate today,
  required AsyncValue<DailyView> daily,
  required AsyncValue<GlossaryNames> glossary,
  required AsyncValue<bool> diaryWritten,
}) {
  final view = daily.value;
  if (view != null && view.date != today) {
    if (daily.hasError && !daily.isLoading) {
      return AsyncError(daily.error!, daily.stackTrace ?? StackTrace.empty);
    }
    return const AsyncLoading();
  }
  if (_failed(daily)) {
    return AsyncError(daily.error!, daily.stackTrace ?? StackTrace.empty);
  }
  if (_failed(glossary)) {
    return AsyncError(glossary.error!, glossary.stackTrace ?? StackTrace.empty);
  }
  final names = glossary.value;
  final written = diaryWritten.value;
  if (names == null || written == null) {
    return const AsyncLoading();
  }
  return daily.whenData(
    (view) => TodayContent(view: view, names: names, diaryWritten: written),
  );
}

/// 오늘 화면 값. 오늘 응답·이름 사전·오늘 일기 여부·"오늘"을 한 곳에서 묶습니다.
///
/// 값이 생기면 사전에 이름이 없어 칩이 되지 않은 대표 태그를 보고합니다
/// ([unnamedFeaturedTagKeysOf], 같은 빈칸은 앱 실행 동안 한 번).
final todayContentProvider = Provider<AsyncValue<TodayContent>>((ref) {
  final content = todayContentOf(
    today: ref.watch(todayProvider),
    daily: ref.watch(dailyControllerProvider),
    glossary: ref.watch(glossaryProvider),
    diaryWritten: ref.watch(todayDiaryExistsProvider),
  );
  final value = content.value;
  if (value != null) {
    _reportUnnamedTags(ref, value);
  }
  return content;
});

/// 이미 보고한 사전 빈칸(용어 id). 다시 계산할 때마다 같은 빈칸을 거듭 보고하지 않게 합니다.
final _reportedDictionaryGapsProvider = Provider<Set<String>>(
  (ref) => <String>{},
);

/// [content]의 대표 태그 중 사전에 이름이 없는 것을 용어 id만 담아 보고합니다(D64).
void _reportUnnamedTags(Ref ref, TodayContent content) {
  final reported = ref.read(_reportedDictionaryGapsProvider);
  final keys = unnamedFeaturedTagKeysOf(content.view.daily, content.names);
  for (final key in keys) {
    final termId = 'tag.$key';
    if (reported.add(termId)) {
      ref
          .read(crashReporterProvider)
          .record(
            CrashSummary.from(MissingDictionaryEntry(termId)),
            StackTrace.current,
          );
    }
  }
}
